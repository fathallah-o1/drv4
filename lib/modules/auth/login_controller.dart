import 'dart:async';
import 'dart:io'; // ✅ لإدارة أخطاء الشبكة
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../core/api.dart';
import '../../core/env.dart';

class LoginController extends GetxController {
  final phone = ''.obs;
  final pass  = ''.obs;
  final loading = false.obs;
  final error = ''.obs;

  Future<void> submit() async {
    if (phone.value.isEmpty || pass.value.isEmpty) {
      error.value = 'الرجاء إدخال رقم الهاتف وكلمة المرور.';
      Get.snackbar(
        'تنبيه',
        error.value,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    loading.value = true;
    error.value = '';
    try {
      final r = await Api.postJson('login.php', {
        'phone': phone.value,
        'password': pass.value,
      });

      // الرد المتوقع من السيرفر: {status: ok, data: {driver_id: ..}}
      final did = int.tryParse('${(r['data'] ?? {})['driver_id']}') ?? 0;
      if (did == 0) throw 'بيانات الدخول غير صحيحة';

      Env.driverId = did;
      final box = GetStorage();
      await box.write('driverId', did);

      Get.offAllNamed('/');
    } on SocketException {
      error.value = 'تعذّر الاتصال بالخادم، تحقق من الإنترنت وحاول مجددًا.';
      Get.snackbar(
        'لا يوجد اتصال',
        error.value,
        snackPosition: SnackPosition.BOTTOM,
      );
    } on TimeoutException {
      error.value = 'انتهت مهلة الاتصال بالخادم، حاول مرة أخرى لاحقًا.';
      Get.snackbar(
        'انتهاء المهلة',
        error.value,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      // ✅ رسالة ودّية بدل الخطأ التقني
      error.value = _friendlyError(e);
      Get.snackbar(
        'فشل تسجيل الدخول',
        error.value,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      loading.value = false;
    }
  }

  String _friendlyError(Object e) {
    final t = e.toString().toLowerCase();

    if (t.contains('بيانات الدخول')) return 'رقم الهاتف أو كلمة المرور غير صحيحة.';
    if (t.contains('socket') || t.contains('network')) return 'تحقق من اتصال الإنترنت.';
    if (t.contains('timeout')) return 'الخادم لم يستجب في الوقت المحدد.';
    if (t.contains('format') || t.contains('json')) return 'حدث خطأ أثناء معالجة البيانات.';
    return 'حدث خلل غير متوقع، حاول مجددًا بعد قليل.';
  }
}
