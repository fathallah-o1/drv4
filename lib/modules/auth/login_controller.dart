import 'dart:async';
import 'dart:io'; // ✅ لإدارة أخطاء الشبكة
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/api.dart';
import '../../core/env.dart';

class LoginController extends GetxController {
  final phone = ''.obs;
  final pass = ''.obs;

  final loading = false.obs;
  final error = ''.obs;

  // ====== ✅ Cache Keys / Settings ======
  static const String _kDriverId = 'driverId';
  static const String _kLoginCache = 'login_cache_v1';
  static const String _kLastLoginAt = 'login_last_at';

  // مدة صلاحية الكاش (غيّرها كما تريد)
  static const Duration _cacheTtl = Duration(days: 7);

  final GetStorage _box = GetStorage();

  /// تسجيل الدخول
  Future<void> submit() async {
    // منع تكرار الضغط
    if (loading.value) return;

    if (phone.value.trim().isEmpty || pass.value.trim().isEmpty) {
      error.value = 'الرجاء إدخال رقم الهاتف وكلمة المرور.';
      Get.snackbar('تنبيه', error.value, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    loading.value = true;
    error.value = '';

    try {
      final payload = {
        'phone': phone.value.trim(),
        'password': pass.value.trim(),
      };

      // ✅ طلب تسجيل الدخول
      final r = await Api.postJson('login.php', payload);

      // الرد المتوقع من السيرفر: {status: ok, data: {driver_id: ..}}
      final data = (r['data'] ?? {}) as Map;
      final did = int.tryParse('${data['driver_id']}') ?? 0;

      if (did == 0) {
        // بيانات دخول خطأ -> نظّف الكاش القديم (احترافي)
        await _clearLoginCache();
        throw 'بيانات الدخول غير صحيحة';
      }

      // ✅ حفظ في Env + Storage
      Env.driverId = did;
      await _box.write(_kDriverId, did);

      // ✅ كاش احترافي: خزّن نتيجة الدخول + وقت الدخول + (token لو موجود)
      await _writeLoginCache(
        driverId: did,
        phone: phone.value.trim(),
        // لو عندك token في الرد خذه (اختياري)
        token: (data['token'] ?? r['token'])?.toString(),
        rawData: data, // يخزن أي بيانات إضافية تفيدك لاحقًا
      );

      Get.offAllNamed('/');
    } on SocketException {
      // ✅ لو فيه كاش صالح ندخل المستخدم بدل ما نقفله
      final cachedId = _getCachedDriverIdIfValid();
      if (cachedId != null && cachedId > 0) {
        Env.driverId = cachedId;
        await _box.write(_kDriverId, cachedId);

        Get.snackbar(
          'تم استخدام الوضع المؤقت',
          'لا يوجد اتصال، تم الدخول باستخدام بيانات محفوظة مؤقتًا.',
          snackPosition: SnackPosition.BOTTOM,
        );
        Get.offAllNamed('/');
        return;
      }

      error.value = 'تعذّر الاتصال بالخادم، تحقق من الإنترنت وحاول مجددًا.';
      Get.snackbar('لا يوجد اتصال', error.value,
          snackPosition: SnackPosition.BOTTOM);
    } on TimeoutException {
      final cachedId = _getCachedDriverIdIfValid();
      if (cachedId != null && cachedId > 0) {
        Env.driverId = cachedId;
        await _box.write(_kDriverId, cachedId);

        Get.snackbar(
          'تم استخدام الوضع المؤقت',
          'الخادم متأخر، تم الدخول باستخدام بيانات محفوظة مؤقتًا.',
          snackPosition: SnackPosition.BOTTOM,
        );
        Get.offAllNamed('/');
        return;
      }

      error.value = 'انتهت مهلة الاتصال بالخادم، حاول مرة أخرى لاحقًا.';
      Get.snackbar('انتهاء المهلة', error.value,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      error.value = _friendlyError(e);
      Get.snackbar('فشل تسجيل الدخول', error.value,
          snackPosition: SnackPosition.BOTTOM);

      // لو الخطأ يدل على رفض بيانات الدخول -> نظّف الكاش
      final t = e.toString().toLowerCase();
      if (t.contains('بيانات الدخول') ||
          t.contains('unauthorized') ||
          t.contains('invalid')) {
        await _clearLoginCache();
      }
    } finally {
      loading.value = false;
    }
  }

  // ===================== Cache Helpers =====================

  Future<void> _writeLoginCache({
    required int driverId,
    required String phone,
    String? token,
    Map? rawData,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    final cache = <String, dynamic>{
      'driver_id': driverId,
      'phone': phone,
      'token': token,
      'raw': rawData ?? {},
      'cached_at': now,
      'ttl_ms': _cacheTtl.inMilliseconds,
    };

    await _box.write(_kLoginCache, cache);
    await _box.write(_kLastLoginAt, now);
  }

  int? _getCachedDriverIdIfValid() {
    final cache = _box.read(_kLoginCache);
    if (cache is! Map) return null;

    final cachedAt = _asInt(cache['cached_at']);
    final ttlMs = _asInt(cache['ttl_ms']) ?? _cacheTtl.inMilliseconds;
    final driverId = _asInt(cache['driver_id']);

    if (cachedAt == null || driverId == null) return null;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final isValid = (now - cachedAt) <= ttlMs;

    return isValid ? driverId : null;
  }

  Future<void> _clearLoginCache() async {
    await _box.remove(_kLoginCache);
    await _box.remove(_kLastLoginAt);
    // لا تحذف driverId تلقائيًا إلا إذا تحب
    // await _box.remove(_kDriverId);
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  // ===================== Friendly Errors =====================

  String _friendlyError(Object e) {
    final t = e.toString().toLowerCase();

    if (t.contains('بيانات الدخول')) return 'رقم الهاتف أو كلمة المرور غير صحيحة.';
    if (t.contains('socket') || t.contains('network')) return 'تحقق من اتصال الإنترنت.';
    if (t.contains('timeout')) return 'الخادم لم يستجب في الوقت المحدد.';
    if (t.contains('format') || t.contains('json')) return 'حدث خطأ أثناء معالجة البيانات.';
    if (t.contains('403') || t.contains('401') || t.contains('unauthorized')) {
      return 'غير مصرح، تحقق من بيانات الدخول.';
    }
    return 'حدث خلل غير متوقع، حاول مجددًا بعد قليل.';
  }
}
