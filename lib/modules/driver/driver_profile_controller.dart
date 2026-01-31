import 'dart:io';
import 'dart:async';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/api.dart';
import '../../core/env.dart';

class DriverProfileController extends GetxController {
  final loading = false.obs;

  // بيانات السائق
  final name = ''.obs;
  final phone = ''.obs;
  final avatarUrl = ''.obs; // يبقى للعرض فقط (بدون رفع)
  final lastSeen = ''.obs;
  final createdAt = ''.obs;

  // ===== ✅ Cache =====
  final GetStorage _box = GetStorage();
  static const String _cacheKey = 'driver_profile_cache_v1';
  static const String _cacheAtKey = 'driver_profile_cache_at';
  static const Duration _cacheTtl = Duration(hours: 24); // مناسب للملف الشخصي

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool forceRefresh = false}) async {
    if (loading.value) return;
    loading.value = true;

    try {
      // ✅ 1) لو فيه كاش صالح وما فيش فورس: اعرضه فورًا (UX أسرع)
      if (!forceRefresh) {
        final cached = _readCacheIfValid();
        if (cached != null) {
          _applyData(cached, fromCache: true);
        }
      }

      // ✅ 2) اطلب من السيرفر (حتى لو عرضنا كاش) لتحديث البيانات
      final r = await Api.getJson('driver_profile.php', {
        'driver_id': '${Env.driverId}',
      });

      if (r['status'] == 'ok') {
        final d = (r['driver'] ?? {}) as Map;
        _applyData(d);

        // ✅ خزّن آخر بيانات ناجحة
        await _writeCache(d);
      } else {
        final msg = _msgOrDefault(r['message'], 'تعذّر تحميل البيانات، حاول لاحقًا.');

        // لو عندي كاش صالح: اكتفي بتنبيه خفيف بدون ما أكسر الشاشة
        if (_readCacheIfValid() != null) {
          _toastWarn(msg);
        } else {
          _toastWarn(msg);
        }
      }
    } on SocketException {
      // ✅ offline fallback
      final cached = _readCacheIfValid();
      if (cached != null) {
        _applyData(cached, fromCache: true);
        _toastWarn('لا يوجد اتصال. تم عرض آخر بيانات محفوظة.');
      } else {
        _toastError('لا يوجد اتصال بالإنترنت. تأكد من الشبكة ثم أعد المحاولة.');
      }
    } on TimeoutException {
      final cached = _readCacheIfValid();
      if (cached != null) {
        _applyData(cached, fromCache: true);
        _toastWarn('الخادم متأخر. تم عرض آخر بيانات محفوظة.');
      } else {
        _toastError('الخادم لم يستجب في الوقت المناسب. حاول مجددًا بعد قليل.');
      }
    } on FormatException {
      final cached = _readCacheIfValid();
      if (cached != null) {
        _applyData(cached, fromCache: true);
        _toastWarn('حدث خلل في الرد. تم عرض آخر بيانات محفوظة.');
      } else {
        _toastError('حدث خلل أثناء معالجة البيانات. أعد المحاولة لاحقًا.');
      }
    } catch (_) {
      final cached = _readCacheIfValid();
      if (cached != null) {
        _applyData(cached, fromCache: true);
        _toastWarn('حدث خطأ. تم عرض آخر بيانات محفوظة.');
      } else {
        _toastError('حدث خطأ غير متوقع أثناء تحميل الملف الشخصي.');
      }
    } finally {
      loading.value = false;
    }
  }

  Future<void> saveProfile() async {
    if (loading.value) return;
    loading.value = true;

    try {
      final r = await Api.postJson('driver_update_profile.php', {
        'driver_id': '${Env.driverId}',
        'name': name.value.trim(),
        'phone': phone.value.trim(),
      });

      if (r['status'] == 'ok') {
        // ✅ تحديث الكاش فورًا بالقيم الحالية (حتى قبل إعادة التحميل)
        final newCache = {
          'name': name.value.trim(),
          'phone': phone.value.trim(),
          'avatar_url': avatarUrl.value,
          'last_seen': lastSeen.value,
          'created_at': createdAt.value,
        };
        await _writeCache(newCache);

        Get.back();
        _toastOk('تم حفظ التغييرات بنجاح.');
      } else {
        _toastWarn(_msgOrDefault(r['message'], 'لم يتم حفظ التغييرات. حاول لاحقًا.'));
      }
    } on SocketException {
      _toastError('تعذّر الاتصال بالخادم. تحقق من الإنترنت.');
    } on TimeoutException {
      _toastError('انتهت مهلة الاتصال. الرجاء المحاولة مرة أخرى.');
    } on FormatException {
      _toastError('رد غير متوقع من الخادم. حاول لاحقًا.');
    } catch (_) {
      _toastError('حدث خلل غير متوقع أثناء حفظ البيانات.');
    } finally {
      loading.value = false;
    }
  }

  Future<void> changePassword(String oldPass, String newPass) async {
    if (oldPass.isEmpty || newPass.isEmpty) {
      _toastWarn('أدخل كلمة المرور القديمة والجديدة.');
      return;
    }

    try {
      final r = await Api.postJson('driver_change_password.php', {
        'driver_id': '${Env.driverId}',
        'old_password': oldPass,
        'new_password': newPass,
      });

      if (r['status'] == 'ok') {
        _toastOk('تم تغيير كلمة المرور بنجاح.');

        // ✅ لا حاجة لتحديث كاش البيانات هنا عادة، لكن نُبقيه جاهز
        // (في حال السيرفر يعيد last_seen أو غيره لاحقًا)
      } else {
        _toastWarn(_msgOrDefault(r['message'], 'تعذّر تغيير كلمة المرور.'));
      }
    } on SocketException {
      _toastError('لا يوجد اتصال بالإنترنت. حاول مرة أخرى.');
    } on TimeoutException {
      _toastError('انتهت مهلة الطلب. أعد المحاولة لاحقًا.');
    } on FormatException {
      _toastError('حدث خطأ في معالجة الرد. حاول لاحقًا.');
    } catch (_) {
      _toastError('حدث خلل غير متوقع أثناء تغيير كلمة المرور.');
    }
  }

  // ===================== Cache Core =====================

  Map<String, dynamic>? _readCacheIfValid() {
    final raw = _box.read(_cacheKey);
    if (raw is! Map) return null;

    final cachedAt = _asInt(_box.read(_cacheAtKey));
    if (cachedAt == null) return null;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final isValid = (now - cachedAt) <= _cacheTtl.inMilliseconds;
    if (!isValid) return null;

    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  Future<void> _writeCache(Map data) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _box.write(_cacheKey, Map<String, dynamic>.from(data));
    await _box.write(_cacheAtKey, now);
  }

  /// مفيد عند تسجيل الخروج
  Future<void> invalidateCache() async {
    await _box.remove(_cacheKey);
    await _box.remove(_cacheAtKey);
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  // ===================== Apply Data =====================

  void _applyData(Map d, {bool fromCache = false}) {
    name.value = '${d['name'] ?? ''}';
    phone.value = '${d['phone'] ?? ''}';
    avatarUrl.value = '${d['avatar_url'] ?? ''}';
    lastSeen.value = '${d['last_seen'] ?? ''}';
    createdAt.value = '${d['created_at'] ?? ''}';

    // لو حبيت تميّز للمستخدم أنها بيانات محفوظة
    // (ما أنفذ شيء هنا لتفادي أي تغيير في UI)
    // if (fromCache) { ... }
  }

  // ===== مساعدات رسائل ودّية =====

  String _msgOrDefault(dynamic m, String fallback) {
    final s = (m ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  void _toastOk(String message) {
    Get.snackbar('تم', message, snackPosition: SnackPosition.BOTTOM);
  }

  void _toastWarn(String message) {
    Get.snackbar('تنبيه', message, snackPosition: SnackPosition.BOTTOM);
  }

  void _toastError(String message) {
    Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
  }
}
