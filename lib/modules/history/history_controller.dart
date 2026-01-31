import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/api.dart';
import '../../core/env.dart';
import 'history_types.dart';

class HistoryController extends GetxController {
  HistoryController({required this.kind});
  final HistoryKind kind;

  final range = 'today'.obs; // today|week|month|all
  final loading = false.obs;

  final orders = <Map<String, dynamic>>[].obs;
  final closures = <Map<String, dynamic>>[].obs; // سجلات الإغلاق
  final summary = <String, dynamic>{}.obs;       // ملخص

  // ===== ✅ Cache =====
  final GetStorage _box = GetStorage();
  static const String _cachePrefix = 'history_cache_v1';

  // لتقليل إزعاج المستخدم بـ Snackbar عند وجود كاش معروض
  bool _servedFromCacheOnce = false;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  /// استخدمها بدل تغيير range.value مباشرة (اختياري لكنه أفضل)
  Future<void> setRange(String r) async {
    if (range.value == r) return;
    range.value = r;

    // SWR: عرض كاش جديد فورًا ثم تحديث
    await loadAll();
  }

  Future<void> loadAll() async {
    if (loading.value) return;
    loading.value = true;
    try {
      _servedFromCacheOnce = false;

      // ✅ 1) اعرض الكاش فورًا (SWR)
      _hydrateFromCache();

      // ✅ 2) ثم حدّث من السيرفر بالتوازي
      await Future.wait([
        loadOrders(networkOnly: true),
        loadClosures(networkOnly: true),
      ]);
    } finally {
      loading.value = false;
    }
  }

  // ===================== Orders =====================

  Future<void> loadOrders({bool networkOnly = false}) async {
    final cacheKey = _k('orders', kind.apiType, range.value);

    // (اختياري) عرض الكاش هنا أيضاً إذا استُدعي منفردًا
    if (!networkOnly) {
      final cached = _readCache(cacheKey, preferFresh: true);
      if (cached != null) {
        _applyOrdersCache(cached);
        _servedFromCacheOnce = true;
      }
    }

    try {
      final m = await Api.getJson('orders_history.php', {
        'driver_id': '${Env.driverId}',
        'type': kind.apiType,
        'range': range.value,
      });

      final list = (m['data'] ?? []) as List;
      orders.assignAll(List<Map<String, dynamic>>.from(list));

      // summary لو موجود
      final s = Map<String, dynamic>.from(m['summary'] ?? const {});
      summary.assignAll({
        ...summary,
        ...s,
        'type': kind.apiType,
        'range': range.value,
      });

      // ✅ اكتب كاش
      await _writeCache(cacheKey, {
        'data': orders.toList(),
        'summary': summary,
      });
    } on SocketException {
      _fallbackOrders(cacheKey, 'لا يوجد اتصال بالإنترنت. تحقق من الشبكة ثم أعد المحاولة.');
    } on TimeoutException {
      _fallbackOrders(cacheKey, 'الخادم لم يستجب في الوقت المناسب. حاول مجددًا بعد قليل.');
    } on FormatException {
      _fallbackOrders(cacheKey, 'حدث خلل أثناء معالجة البيانات. أعد المحاولة لاحقًا.');
    } catch (_) {
      _fallbackOrders(cacheKey, 'حدث خطأ غير متوقع أثناء تحميل السجل.');
    }
  }

  void _fallbackOrders(String cacheKey, String msg) {
    // ✅ fallback حتى لو الكاش منتهي (آخر نسخة محفوظة)
    final cached = _readCache(cacheKey, preferFresh: false);
    if (cached != null) {
      _applyOrdersCache(cached);

      // تنبيه خفيف مرة واحدة فقط
      if (!_servedFromCacheOnce) {
        _toastWarn('تم عرض بيانات محفوظة مؤقتًا بسبب مشكلة اتصال.');
        _servedFromCacheOnce = true;
      }
    } else {
      _toastError(msg);
    }
  }

  void _applyOrdersCache(Map<String, dynamic> cached) {
    final list = (cached['data'] ?? []) as List;
    orders.assignAll(List<Map<String, dynamic>>.from(list));

    final s = cached['summary'];
    if (s is Map) {
      summary.assignAll(Map<String, dynamic>.from(s));
    }
  }

  // ===================== Closures =====================

  Future<void> loadClosures({bool networkOnly = false}) async {
    if (!(kind == HistoryKind.dues ||
        kind == HistoryKind.debt ||
        kind == HistoryKind.profit)) {
      closures.clear();
      return;
    }

    final cacheKey = _k('closures', kind.apiType, range.value);

    if (!networkOnly) {
      final cached = _readCache(cacheKey, preferFresh: true);
      if (cached != null) {
        _applyClosuresCache(cached);
        _servedFromCacheOnce = true;
      }
    }

    try {
      final m = await Api.getJson('closures_history.php', {
        'driver_id': '${Env.driverId}',
        'type': kind.apiType, // dues|debt|profit
        'range': range.value,
      });

      final list = (m['data'] ?? []) as List;
      closures.assignAll(List<Map<String, dynamic>>.from(list));

      final today = Map<String, dynamic>.from(m['today'] ?? const {});
      summary.assignAll({
        ...summary,
        'type': kind.apiType,
        'range': range.value,
        'today': today,
      });

      await _writeCache(cacheKey, {
        'data': closures.toList(),
        'summary': summary,
      });
    } on SocketException {
      _fallbackClosures(cacheKey, 'لا يوجد اتصال بالإنترنت. تحقق من الشبكة ثم أعد المحاولة.');
    } on TimeoutException {
      _fallbackClosures(cacheKey, 'الخادم لم يستجب في الوقت المناسب. حاول مجددًا بعد قليل.');
    } on FormatException {
      _fallbackClosures(cacheKey, 'حدث خلل أثناء معالجة البيانات. أعد المحاولة لاحقًا.');
    } catch (_) {
      _fallbackClosures(cacheKey, 'حدث خطأ غير متوقع أثناء تحميل سجلات الإغلاق.');
    }
  }

  void _fallbackClosures(String cacheKey, String msg) {
    final cached = _readCache(cacheKey, preferFresh: false);
    if (cached != null) {
      _applyClosuresCache(cached);

      if (!_servedFromCacheOnce) {
        _toastWarn('تم عرض بيانات محفوظة مؤقتًا بسبب مشكلة اتصال.');
        _servedFromCacheOnce = true;
      }
    } else {
      _toastError(msg);
    }
  }

  void _applyClosuresCache(Map<String, dynamic> cached) {
    final list = (cached['data'] ?? []) as List;
    closures.assignAll(List<Map<String, dynamic>>.from(list));

    final s = cached['summary'];
    if (s is Map) {
      summary.assignAll(Map<String, dynamic>.from(s));
    }
  }

  // ===================== Cache Engine =====================

  /// يجلب كاش مناسب لنوع/مدى السجل ويطبّقه فورًا
  void _hydrateFromCache() {
    final ordersKey = _k('orders', kind.apiType, range.value);
    final closuresKey = _k('closures', kind.apiType, range.value);

    final o = _readCache(ordersKey, preferFresh: true);
    if (o != null) {
      _applyOrdersCache(o);
      _servedFromCacheOnce = true;
    }

    // closures فقط للأنواع الخاصة
    if (kind == HistoryKind.dues ||
        kind == HistoryKind.debt ||
        kind == HistoryKind.profit) {
      final c = _readCache(closuresKey, preferFresh: true);
      if (c != null) {
        _applyClosuresCache(c);
        _servedFromCacheOnce = true;
      }
    }
  }

  /// Key: history_cache_v1:<driverId>:<bucket>:<type>:<range>
  String _k(String bucket, String type, String range) {
    return '$_cachePrefix:${Env.driverId}:$bucket:$type:$range';
    // مثال: history_cache_v1:12:orders:delivered:today
  }

  Duration _ttlForRange(String r) {
    switch (r) {
      case 'today':
        return const Duration(minutes: 5);
      case 'week':
        return const Duration(minutes: 20);
      case 'month':
        return const Duration(hours: 2);
      case 'all':
        return const Duration(hours: 6);
      default:
        return const Duration(minutes: 10);
    }
  }

  Map<String, dynamic>? _readCache(
    String key, {
    required bool preferFresh,
  }) {
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

  Future<void> _writeCache(String key, Map<String, dynamic> payload) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final ttl = _ttlForRange(range.value).inMilliseconds;

    final data = <String, dynamic>{
      ...payload,
      'cached_at': now,
      'ttl_ms': ttl,
      'driver_id': Env.driverId,
      'type': kind.apiType,
      'range': range.value,
    };

    await _box.write(key, data);
  }

  /// مفيد لو تريد زر “تحديث قوي” أو عند تسجيل الخروج
  Future<void> invalidateAllCacheForThisController() async {
    final keys = [
      _k('orders', kind.apiType, range.value),
      _k('closures', kind.apiType, range.value),
    ];
    for (final k in keys) {
      await _box.remove(k);
    }
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  // ===================== Helpers =====================

  // القيمة المعروضة لكل طلب حسب النوع
  String valueOf(Map<String, dynamic> o) {
    switch (kind) {
      case HistoryKind.delivered:
      case HistoryKind.rejected:
        return (o['total'] ?? 0).toString();
      case HistoryKind.profit:
      case HistoryKind.dues:
        return (o['delivery_fee'] ?? 0).toString();
      case HistoryKind.debt:
        final t = (o['total'] ?? 0) * 1.0;
        final f = (o['delivery_fee'] ?? 0) * 1.0;
        return (t - f).toStringAsFixed(2);
    }
  }

  void _toastWarn(String message) {
    Get.snackbar('تنبيه', message, snackPosition: SnackPosition.BOTTOM);
  }

  void _toastError(String message) {
    Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
  }
}
