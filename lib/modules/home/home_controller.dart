import 'dart:async';
import 'dart:io'; // ← لالتقاط أخطاء الشبكة بشكل ودّي
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api.dart';
import '../../core/env.dart';

// خدمات إضافية
import '../../core/bg_location_service.dart';
import '../../core/power_optimizations.dart';

class HomeController extends GetxController {
  final loading = false.obs;

  // all | month | week | today
  final range = 'all'.obs;
  final isOnline = false.obs;

  // بيانات السائق
  final driverName = ''.obs;
  final driverPhone = ''.obs;
  final driverLastSeen = ''.obs;

  // إحصائيات
  final delivered = 0.obs;
  final rejected = 0.obs;
  final profitAll = 0.0.obs;
  final duesToday = 0.0.obs;
  final debtToday = 0.0.obs;

  // الطلبات
  final orders = <Map<String, dynamic>>[].obs;

  Timer? _poller;
  bool _isTicking = false;
  late final GetStorage _box;

  // ===== ✅ Cache Settings =====
  static const String _cachePrefix = 'home_cache_v1';
  bool _servedSomethingFromCache = false; // لتقليل Snackbar

  @override
  void onInit() {
    super.onInit();
    _box = GetStorage();

    if (Env.driverId == 0) {
      Get.offAllNamed('/login');
      return;
    }

    // استرجاع حالة الأونلاين
    final savedOnline = _box.read('driverOnline') == true;
    isOnline.value = savedOnline;

    // ✅ اعرض الكاش فورًا قبل أي شبكة (SWR)
    _hydrateFromCache();

    // تحميل بيانات السائق ثم تحديث الشبكة
    loadDriverInfo();

    _tick();
    _poller = Timer.periodic(Env.pollInterval, (_) => _tick());
  }

  @override
  void onClose() {
    _poller?.cancel();
    super.onClose();
  }

  // ===================== Cache Keys / TTL =====================

  String _k(String bucket) => '$_cachePrefix:${Env.driverId}:$bucket';

  Duration _ttlDashboardForRange(String r) {
    switch (r) {
      case 'today':
        return const Duration(minutes: 2);
      case 'week':
        return const Duration(minutes: 5);
      case 'month':
        return const Duration(minutes: 10);
      case 'all':
      default:
        return const Duration(minutes: 15);
    }
  }

  static const Duration _ttlOrders = Duration(seconds: 30);
  static const Duration _ttlDriverInfo = Duration(hours: 6);

  Map<String, dynamic>? _readCache(String key, {required bool preferFresh}) {
    final raw = _box.read(key);
    if (raw is! Map) return null;

    final cachedAt = _asInt(raw['cached_at']);
    final ttlMs = _asInt(raw['ttl_ms']);
    if (cachedAt == null || ttlMs == null) return null;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final isFresh = (now - cachedAt) <= ttlMs;

    if (preferFresh && !isFresh) return null;

    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  Future<void> _writeCache(String key, Map<String, dynamic> payload, Duration ttl) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _box.write(key, <String, dynamic>{
      ...payload,
      'cached_at': now,
      'ttl_ms': ttl.inMilliseconds,
    });
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  void _hydrateFromCache() {
    // Dashboard
    final dash = _readCache(_k('dashboard:${range.value}'), preferFresh: true);
    if (dash != null) {
      _applyDashboardFromCache(dash);
      _servedSomethingFromCache = true;
    }

    // Orders
    final ord = _readCache(_k('orders'), preferFresh: true);
    if (ord != null) {
      _applyOrdersFromCache(ord);
      _servedSomethingFromCache = true;
    }

    // Driver Info
    final drv = _readCache(_k('driver_info'), preferFresh: true);
    if (drv != null) {
      _applyDriverFromCache(drv);
      _servedSomethingFromCache = true;
    }
  }

  // ===================== Driver Info (with cache) =====================

  Future<void> loadDriverInfo() async {
    final cacheKey = _k('driver_info');

    // SWR: عرض الكاش (لو ما اتعرض سابقًا)
    final cached = _readCache(cacheKey, preferFresh: true);
    if (cached != null) {
      _applyDriverFromCache(cached);
      _servedSomethingFromCache = true;
    }

    try {
      Map<String, dynamic> r = await Api.getJson('driver_profile.php', {
        'driver_id': '${Env.driverId}',
      });

      if (r['status'] != 'ok' && r['driver'] == null) {
        r = await Api.getJson('driver_me.php', {
          'driver_id': '${Env.driverId}',
        });
      }

      final d = (r['driver'] ?? r['data'] ?? r) as Map<String, dynamic>?;
      final name = (d?['name'] ?? '').toString();
      final phone = (d?['phone'] ?? '').toString();
      final last = (d?['last_seen'] ?? '').toString();

      driverName.value = name;
      driverPhone.value = phone;
      driverLastSeen.value = last;

      await _writeCache(cacheKey, {
        'name': name,
        'phone': phone,
        'last_seen': last,
      }, _ttlDriverInfo);
    } on SocketException {
      // fallback حتى لو منتهي
      final any = _readCache(cacheKey, preferFresh: false);
      if (any != null) _applyDriverFromCache(any);
    } on TimeoutException {
      final any = _readCache(cacheKey, preferFresh: false);
      if (any != null) _applyDriverFromCache(any);
    } catch (_) {
      // بصمت
    }
  }

  void _applyDriverFromCache(Map<String, dynamic> c) {
    driverName.value = (c['name'] ?? '').toString();
    driverPhone.value = (c['phone'] ?? '').toString();
    driverLastSeen.value = (c['last_seen'] ?? '').toString();
  }

  // ===================== Tick =====================

  Future<void> _tick() async {
    if (_isTicking) return;
    _isTicking = true;

    try {
      await Future.wait([
        loadDashboard(),
        loadOrders(),
      ]);

      await _pushDriverStatus();

      if (isOnline.value) {
        await _sendDriverPing();
        await BackgroundLocationService.start(Env.driverId);
      }
    } finally {
      _isTicking = false;
    }
  }

  // ===================== Status / Ping =====================

  Future<void> _pushDriverStatus() async {
    try {
      await Api.postJson('driver_toggle_online.php', {
        'driver_id': '${Env.driverId}',
        'online': isOnline.value ? '1' : '0',
      });
    } on SocketException {
      // لا نزعج المستخدم دائمًا
      if (!_servedSomethingFromCache) {
        Get.snackbar('الاتصال غير متاح', 'تحقّق من الإنترنت ثم أعد المحاولة.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } on TimeoutException {
      if (!_servedSomethingFromCache) {
        Get.snackbar('انتهت المهلة', 'الخادم لم يستجب. حاول مجددًا بعد قليل.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      if (!_servedSomethingFromCache) {
        Get.snackbar('تنبيه', 'تعذّر تحديث حالة السائق حاليًا.',
            snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  Future<void> _sendDriverPing() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar('الموقع مُعطّل', 'فعّل خدمة الموقع لإرسال موقعك الحي.',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        Get.snackbar('إذن الموقع', 'من فضلك امنح إذن الموقع من الإعدادات.',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      await Api.postJson('driver_ping.php', {
        'driver_id': '${Env.driverId}',
        'lat': pos.latitude.toStringAsFixed(7),
        'lng': pos.longitude.toStringAsFixed(7),
      });
    } on TimeoutException {
      // بصمت
    } on SocketException {
      // بصمت
    } catch (_) {
      // بصمت
    }
  }

  // ===================== Dashboard (with cache) =====================

  Future<void> loadDashboard() async {
    final cacheKey = _k('dashboard:${range.value}');
    final ttl = _ttlDashboardForRange(range.value);

    // SWR: اعرض الكاش فورًا (fresh فقط)
    final cached = _readCache(cacheKey, preferFresh: true);
    if (cached != null) {
      _applyDashboardFromCache(cached);
      _servedSomethingFromCache = true;
    }

    try {
      final m = await Api.getJson('dashboard.php', {
        'driver_id': '${Env.driverId}',
        'range': range.value,
      });

      delivered.value = (m['delivered'] ?? 0) as int;
      rejected.value = (m['rejected'] ?? 0) as int;
      profitAll.value = double.tryParse('${m['profit_all'] ?? 0}') ?? 0;
      duesToday.value = double.tryParse('${m['dues_today'] ?? 0}') ?? 0;
      debtToday.value = double.tryParse('${m['debt_today'] ?? 0}') ?? 0;

      await _writeCache(cacheKey, {
        'delivered': delivered.value,
        'rejected': rejected.value,
        'profit_all': profitAll.value,
        'dues_today': duesToday.value,
        'debt_today': debtToday.value,
        'range': range.value,
      }, ttl);
    } on SocketException {
      final any = _readCache(cacheKey, preferFresh: false);
      if (any != null) {
        _applyDashboardFromCache(any);
        if (!_servedSomethingFromCache) {
          Get.snackbar('الاتصال غير متاح', 'تم عرض آخر بيانات محفوظة للوحة.',
              snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        Get.snackbar('الاتصال غير متاح', 'تعذّر تحميل اللوحة بسبب انقطاع الإنترنت.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } on TimeoutException {
      final any = _readCache(cacheKey, preferFresh: false);
      if (any != null) {
        _applyDashboardFromCache(any);
        if (!_servedSomethingFromCache) {
          Get.snackbar('انتهت المهلة', 'تم عرض آخر بيانات محفوظة للوحة.',
              snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        Get.snackbar('انتهت المهلة', 'الخادم لم يستجب لطلب اللوحة.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } on FormatException {
      final any = _readCache(cacheKey, preferFresh: false);
      if (any != null) {
        _applyDashboardFromCache(any);
        if (!_servedSomethingFromCache) {
          Get.snackbar('خلل بالبيانات', 'تم عرض آخر بيانات محفوظة للوحة.',
              snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        Get.snackbar('خلل بالبيانات', 'واجهنا مشكلة أثناء قراءة بيانات اللوحة.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      final any = _readCache(cacheKey, preferFresh: false);
      if (any != null) {
        _applyDashboardFromCache(any);
        if (!_servedSomethingFromCache) {
          Get.snackbar('تنبيه', 'تم عرض آخر بيانات محفوظة للوحة.',
              snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        Get.snackbar('خطأ', 'حدث خطأ غير متوقع أثناء تحميل اللوحة.',
            snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  void _applyDashboardFromCache(Map<String, dynamic> c) {
    delivered.value = (c['delivered'] ?? 0) is int
        ? (c['delivered'] ?? 0) as int
        : int.tryParse('${c['delivered'] ?? 0}') ?? 0;

    rejected.value = (c['rejected'] ?? 0) is int
        ? (c['rejected'] ?? 0) as int
        : int.tryParse('${c['rejected'] ?? 0}') ?? 0;

    profitAll.value = double.tryParse('${c['profit_all'] ?? 0}') ?? 0;
    duesToday.value = double.tryParse('${c['dues_today'] ?? 0}') ?? 0;
    debtToday.value = double.tryParse('${c['debt_today'] ?? 0}') ?? 0;
  }

  // ===================== Orders (with cache) =====================

  Future<void> loadOrders() async {
    final cacheKey = _k('orders');

    // SWR: اعرض كاش سريع (fresh)
    final cached = _readCache(cacheKey, preferFresh: true);
    if (cached != null) {
      _applyOrdersFromCache(cached);
      _servedSomethingFromCache = true;
    }

    try {
      final m = await Api.getJson('orders_assigned.php', {
        'driver_id': '${Env.driverId}',
      });
      final list = (m['orders'] ?? m['data'] ?? []) as List;
      orders.assignAll(List<Map<String, dynamic>>.from(list));

      await _writeCache(cacheKey, {
        'orders': orders.toList(),
      }, _ttlOrders);
    } on SocketException {
      final any = _readCache(cacheKey, preferFresh: false);
      if (any != null) {
        _applyOrdersFromCache(any);
        if (!_servedSomethingFromCache) {
          Get.snackbar('الاتصال غير متاح', 'تم عرض آخر طلبات محفوظة مؤقتًا.',
              snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        Get.snackbar('الاتصال غير متاح', 'لا يمكن تحميل الطلبات بدون إنترنت.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } on TimeoutException {
      final any = _readCache(cacheKey, preferFresh: false);
      if (any != null) {
        _applyOrdersFromCache(any);
        if (!_servedSomethingFromCache) {
          Get.snackbar('انتهت المهلة', 'تم عرض آخر طلبات محفوظة مؤقتًا.',
              snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        Get.snackbar('انتهت المهلة', 'تأخّر الخادم في الاستجابة لطلباتك.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } on FormatException {
      final any = _readCache(cacheKey, preferFresh: false);
      if (any != null) {
        _applyOrdersFromCache(any);
        if (!_servedSomethingFromCache) {
          Get.snackbar('خلل بالبيانات', 'تم عرض آخر طلبات محفوظة مؤقتًا.',
              snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        Get.snackbar('خلل بالبيانات', 'واجهنا مشكلة أثناء قراءة قائمة الطلبات.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      final any = _readCache(cacheKey, preferFresh: false);
      if (any != null) {
        _applyOrdersFromCache(any);
        if (!_servedSomethingFromCache) {
          Get.snackbar('تنبيه', 'تم عرض آخر طلبات محفوظة مؤقتًا.',
              snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        Get.snackbar('خطأ', 'حدث خطأ غير متوقع أثناء تحميل الطلبات.',
            snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  void _applyOrdersFromCache(Map<String, dynamic> c) {
    final list = (c['orders'] ?? const []) as List;
    orders.assignAll(List<Map<String, dynamic>>.from(list));
  }

  // ===================== Actions =====================

  Future<void> markDelivered(int orderId) async {
    if (loading.value) return;
    loading.value = true;
    try {
      final r = await Api.postJson('driver_update_order_status.php', {
        'order_id': '$orderId',
        'driver_id': '${Env.driverId}',
        'action': 'delivered',
      });

      if (r['status'] == 'ok') {
        Get.snackbar('تم', 'تم تعيين الطلب #$orderId كـ تم التسليم',
            snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar('تنبيه', '${r['message'] ?? 'لم يتم قبول العملية'}',
            snackPosition: SnackPosition.BOTTOM);
      }
    } on SocketException {
      Get.snackbar('الاتصال غير متاح', 'تعذّر تحديث الطلب بدون إنترنت.',
          snackPosition: SnackPosition.BOTTOM);
    } on TimeoutException {
      Get.snackbar('انتهت المهلة', 'الخادم لم يؤكّد التحديث في الوقت المطلوب.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث حالة الطلب.',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
      // بعد العمليات نحدّث (ويكتب كاش جديد)
      await _tick();
    }
  }

  Future<void> markRejected(int orderId, {String? reason}) async {
    if (loading.value) return;
    loading.value = true;
    try {
      final r = await Api.postJson('driver_update_order_status.php', {
        'order_id': '$orderId',
        'driver_id': '${Env.driverId}',
        'action': 'rejected',
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

      if (r['status'] == 'ok') {
        Get.snackbar('تم', 'تم تعيين الطلب #$orderId كـ تم الرفض',
            snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar('تنبيه', '${r['message'] ?? 'لم يتم قبول العملية'}',
            snackPosition: SnackPosition.BOTTOM);
      }
    } on SocketException {
      Get.snackbar('الاتصال غير متاح', 'تعذّر تحديث الطلب بدون إنترنت.',
          snackPosition: SnackPosition.BOTTOM);
    } on TimeoutException {
      Get.snackbar('انتهت المهلة', 'الخادم لم يؤكّد التحديث في الوقت المطلوب.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء تحديث حالة الطلب.',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
      await _tick();
    }
  }

  Future<void> closeDriverDaily() async {
    if (loading.value) return;
    loading.value = true;
    try {
      final r = await Api.postJson('close_driver_daily.php', {
        'driver_id': '${Env.driverId}',
        'period': 'day',
      });

      if (r['status'] == 'ok') {
        Get.snackbar('تم', 'تم إغلاق حساب السائق لليوم',
            snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar('تنبيه', '${r['message'] ?? 'لم يتم الإغلاق'}',
            snackPosition: SnackPosition.BOTTOM);
      }
    } on SocketException {
      Get.snackbar('الاتصال غير متاح', 'لا يمكن تنفيذ الإغلاق بدون إنترنت.',
          snackPosition: SnackPosition.BOTTOM);
    } on TimeoutException {
      Get.snackbar('انتهت المهلة', 'الخادم لم يُتم عملية الإغلاق في الوقت المحدد.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء إغلاق حساب السائق.',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
      await _tick();
    }
  }

  Future<void> closeRestaurantDaily() async {
    if (loading.value) return;
    loading.value = true;
    try {
      final r = await Api.postJson('close_restaurant_daily.php', {
        'driver_id': '${Env.driverId}',
        'period': 'day',
      });

      if (r['status'] == 'ok') {
        Get.snackbar('تم', 'تم إغلاق حساب المطعم لليوم',
            snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar('تنبيه', '${r['message'] ?? 'لم يتم الإغلاق'}',
            snackPosition: SnackPosition.BOTTOM);
      }
    } on SocketException {
      Get.snackbar('الاتصال غير متاح', 'لا يمكن تنفيذ الإغلاق بدون إنترنت.',
          snackPosition: SnackPosition.BOTTOM);
    } on TimeoutException {
      Get.snackbar('انتهت المهلة', 'الخادم لم يُتم عملية الإغلاق في الوقت المحدد.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء إغلاق حساب المطعم.',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
      await _tick();
    }
  }

  Future<void> setOnline(bool v) async {
    isOnline.value = v;

    if (v) {
      await PowerOptimizations.maybePromptOnce();
    }

    _box.write('driverOnline', v);

    await _pushDriverStatus();

    if (v) {
      await _sendDriverPing();
      try {
        await BackgroundLocationService.start(Env.driverId);
      } catch (_) {}
    } else {
      try {
        await BackgroundLocationService.stop();
      } catch (_) {}
    }

    Get.snackbar(
      'الحالة',
      v ? 'السائق متصل، سيتم مشاركة الموقع' : 'السائق غير متصل، تم إخفاء الموقع',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _invalidateHomeCache() async {
    // تنظيف كاش الهوم عند تسجيل الخروج
    final keys = [
      _k('orders'),
      _k('driver_info'),
      _k('dashboard:today'),
      _k('dashboard:week'),
      _k('dashboard:month'),
      _k('dashboard:all'),
    ];
    for (final k in keys) {
      await _box.remove(k);
    }
  }

  void logout() async {
    await _invalidateHomeCache();

    final box = GetStorage();
    box.remove('driverId');
    box.remove('driverOnline');

    Env.driverId = 0;
    Get.offAllNamed('/login');
    Get.snackbar('تم', 'تم تسجيل الخروج', snackPosition: SnackPosition.BOTTOM);
  }
}
