import 'dart:io';
import 'dart:async';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api.dart';
import '../../core/env.dart';

class DriverProfileController extends GetxController {
  final loading = false.obs;

  // بيانات السائق
  final name = ''.obs;
  final phone = ''.obs;
  final avatarUrl = ''.obs;
  final lastSeen = ''.obs;
  final createdAt = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final r = await Api.getJson('driver_profile.php', {
        'driver_id': '${Env.driverId}',
      });
      if (r['status'] == 'ok') {
        final d = r['driver'] ?? {};
        name.value = '${d['name'] ?? ''}';
        phone.value = '${d['phone'] ?? ''}';
        avatarUrl.value = '${d['avatar_url'] ?? ''}';
        lastSeen.value = '${d['last_seen'] ?? ''}';
        createdAt.value = '${d['created_at'] ?? ''}';
      } else {
        _toastWarn(_msgOrDefault(r['message'], 'تعذّر تحميل البيانات، حاول لاحقًا.'));
      }
    } on SocketException {
      _toastError('لا يوجد اتصال بالإنترنت. تأكد من الشبكة ثم أعد المحاولة.');
    } on TimeoutException {
      _toastError('الخادم لم يستجب في الوقت المناسب. حاول مجددًا بعد قليل.');
    } on FormatException {
      _toastError('حدث خلل أثناء معالجة البيانات. أعد المحاولة لاحقًا.');
    } catch (_) {
      _toastError('حدث خطأ غير متوقع أثناء تحميل الملف الشخصي.');
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
        Get.back(); // رجوع اختياري
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
      } else {
        // نحترم رسالة السيرفر إن وُجدت (مثلاً: القديمة غير صحيحة)
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

  Future<void> pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;

    try {
      final r = await Api.postMultipart(
        'driver_upload_avatar.php',
        fields: {'driver_id': '${Env.driverId}'},
        files: {'image': File(x.path)},
      );
      if (r['status'] == 'ok') {
        avatarUrl.value = '${r['avatar_url']}';
        _toastOk('تم تحديث الصورة الشخصية بنجاح.');
      } else {
        _toastWarn(_msgOrDefault(r['message'], 'فشل رفع الصورة. حاول مجددًا.'));
      }
    } on SocketException {
      _toastError('تعذّر رفع الصورة بسبب انقطاع الإنترنت.');
    } on TimeoutException {
      _toastError('انتهت مهلة الرفع. الرجاء المحاولة مرة أخرى.');
    } on FormatException {
      _toastError('رد غير صالح من الخادم أثناء الرفع.');
    } catch (_) {
      _toastError('حدث خلل غير متوقع أثناء رفع الصورة.');
    }
  }

  // ===== مساعدات رسائل ودّية (بدون تغيير المنطق) =====

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
