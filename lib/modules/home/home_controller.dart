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

  // ╔══════════════════════════════════════════════════════════╗
  // ║      بيانات السائق (مضافة)                               ║
  // ╚══════════════════════════════════════════════════════════╝
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
  bool _isTicking = false; // قفل لمنع تداخل _tick
  late final GetStorage _box;

  @override
  void onInit() {
    super.onInit();
    _box = GetStorage();

    if (Env.driverId == 0) {
      Get.offAllNamed('/login');
      return;
    }

    // استرجاع حالة الأونلاين (لكن لا نُشغّل الخدمة هنا)
    final savedOnline = _box.read('driverOnline') == true;
    isOnline.value = savedOnline;

    // تحميل بيانات السائق أولاً
    loadDriverInfo();

    _tick();
    _poller = Timer.periodic(Env.pollInterval, (_) => _tick());
  }

  @override
  void onClose() {
    _poller?.cancel();
    super.onClose();
  }

  // ╔══════════════════════════════════════════════════════════╗
  // ║      تحميل بيانات السائق (مضافة)                         ║
  // ╚══════════════════════════════════════════════════════════╝
  Future<void> loadDriverInfo() async {
    try {
      // نحاول endpoint أساسي ثم بديل لو اسم الملف مختلف عندك
      Map<String, dynamic> r = await Api.getJson('driver_profile.php', {
        'driver_id': '${Env.driverId}',
      });

      // fallback لو السيرفر يستعمل اسم آخر
      if (r['status'] != 'ok' && r['driver'] == null) {
        r = await Api.getJson('driver_me.php', {
          'driver_id': '${Env.driverId}',
        });
      }

      final d = (r['driver'] ?? r['data'] ?? r) as Map<String, dynamic>?;
      driverName.value = (d?['name'] ?? '').toString();
      driverPhone.value = (d?['phone'] ?? '').toString();
      driverLastSeen.value = (d?['last_seen'] ?? '').toString();
    } on SocketException {
      // بصمت
    } on TimeoutException {
      // بصمت
    } catch (_) {
      // بصمت
    }
  }

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
        // الخدمة تُشغَّل فقط لو أونلاين — هنا آمن
        await BackgroundLocationService.start(Env.driverId);
      }
    } finally {
      _isTicking = false;
    }
  }

  Future<void> _pushDriverStatus() async {
    try {
      await Api.postJson('driver_toggle_online.php', {
        'driver_id': '${Env.driverId}',
        'online': isOnline.value ? '1' : '0',
      });
    } on SocketException {
      Get.snackbar('الاتصال غير متاح', 'تحقّق من الإنترنت ثم أعد المحاولة.',
          snackPosition: SnackPosition.BOTTOM);
    } on TimeoutException {
      Get.snackbar('انتهت المهلة', 'الخادم لم يستجب. حاول مجددًا بعد قليل.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('تنبيه', 'تعذّر تحديث حالة السائق حاليًا.',
          snackPosition: SnackPosition.BOTTOM);
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

  Future<void> loadDashboard() async {
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
    } on SocketException {
      Get.snackbar('الاتصال غير متاح', 'تعذّر تحميل اللوحة بسبب انقطاع الإنترنت.',
          snackPosition: SnackPosition.BOTTOM);
    } on TimeoutException {
      Get.snackbar('انتهت المهلة', 'الخادم لم يستجب لطلب اللوحة.',
          snackPosition: SnackPosition.BOTTOM);
    } on FormatException {
      Get.snackbar('خلل بالبيانات', 'واجهنا مشكلة أثناء قراءة بيانات اللوحة.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('خطأ', 'حدث خطأ غير متوقع أثناء تحميل اللوحة.',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> loadOrders() async {
    try {
      final m = await Api.getJson('orders_assigned.php', {
        'driver_id': '${Env.driverId}',
      });
      final list = (m['orders'] ?? m['data'] ?? []) as List;
      orders.assignAll(List<Map<String, dynamic>>.from(list));
    } on SocketException {
      Get.snackbar('الاتصال غير متاح', 'لا يمكن تحميل الطلبات بدون إنترنت.',
          snackPosition: SnackPosition.BOTTOM);
    } on TimeoutException {
      Get.snackbar('انتهت المهلة', 'تأخّر الخادم في الاستجابة لطلباتك.',
          snackPosition: SnackPosition.BOTTOM);
    } on FormatException {
      Get.snackbar('خلل بالبيانات', 'واجهنا مشكلة أثناء قراءة قائمة الطلبات.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('خطأ', 'حدث خطأ غير متوقع أثناء تحميل الطلبات.',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // ✅ تعيين الطلب كتم التسليم
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
      await _tick();
    }
  }

  // ✅ تعيين الطلب كتم الرفض
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

  /// إغلاق حساب السائق "لليوم" فقط
  Future<void> closeDriverDaily() async {
    if (loading.value) return;
    loading.value = true;
    try {
      final r = await Api.postJson('close_driver_daily.php', {
        'driver_id': '${Env.driverId}',
        'period': 'day', // 👈 ثابت: إغلاق يومي فقط
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
      Get.snackbar(
          'انتهت المهلة', 'الخادم لم يُتم عملية الإغلاق في الوقت المحدد.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء إغلاق حساب السائق.',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
      await _tick();
    }
  }

  /// إغلاق حساب المطعم "لليوم" فقط
  Future<void> closeRestaurantDaily() async {
    if (loading.value) return;
    loading.value = true;
    try {
      final r = await Api.postJson('close_restaurant_daily.php', {
        'driver_id': '${Env.driverId}',
        'period': 'day', // 👈 ثابت: إغلاق يومي فقط
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
      Get.snackbar(
          'انتهت المهلة', 'الخادم لم يُتم عملية الإغلاق في الوقت المحدد.',
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
      // نعرض حوار نصائح البطارية (يدوي، لا يفتح شاشات تلقائيًا)
      await PowerOptimizations.maybePromptOnce();
    }
    _box.write('driverOnline', v); // احفظ الحالة محلياً

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

  void logout() {
    final box = GetStorage();
    box.remove('driverId');
    box.remove('driverOnline');
    Env.driverId = 0;
    Get.offAllNamed('/login');
    Get.snackbar('تم', 'تم تسجيل الخروج', snackPosition: SnackPosition.BOTTOM);
  }
}
