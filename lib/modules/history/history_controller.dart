import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import '../../core/api.dart';
import '../../core/env.dart';
import 'history_types.dart';

class HistoryController extends GetxController {
  HistoryController({required this.kind});
  final HistoryKind kind;

  final range = 'today'.obs; // today|week|month|all
  final loading = false.obs;
  final orders = <Map<String, dynamic>>[].obs;
  final closures = <Map<String, dynamic>>[].obs; // لسجلات الإغلاق (dues/debt/profit)
  final summary = <String, dynamic>{}.obs;       // ← ملخّص من الـAPI

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    loading.value = true;
    try {
      await Future.wait([loadOrders(), loadClosures()]);
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadOrders() async {
    try {
      final m = await Api.getJson('orders_history.php', {
        'driver_id': '${Env.driverId}',
        'type': kind.apiType,
        'range': range.value,
      });
      final list = (m['data'] ?? []) as List;
      orders.assignAll(List<Map<String, dynamic>>.from(list));

      // يدعم API إرجاع summary (إن وُجد)
      summary.assignAll(Map<String, dynamic>.from(m['summary'] ?? const {}));
    } on SocketException {
      _toastError('لا يوجد اتصال بالإنترنت. تحقق من الشبكة ثم أعد المحاولة.');
    } on TimeoutException {
      _toastError('الخادم لم يستجب في الوقت المناسب. حاول مجددًا بعد قليل.');
    } on FormatException {
      _toastError('حدث خلل أثناء معالجة البيانات. أعد المحاولة لاحقًا.');
    } catch (_) {
      _toastError('حدث خطأ غير متوقع أثناء تحميل السجل.');
    }
  }

  Future<void> loadClosures() async {
    if (kind == HistoryKind.dues || kind == HistoryKind.debt || kind == HistoryKind.profit) {
      try {
        final m = await Api.getJson('closures_history.php', {
          'driver_id': '${Env.driverId}',
          'type': kind.apiType, // 'dues' | 'debt' | 'profit'
          'range': range.value,
        });
        final list = (m['data'] ?? []) as List;
        closures.assignAll(List<Map<String, dynamic>>.from(list));

        // هذا الـ API يُعيد today بدلاً من summary — ندمجه داخل summary الحالي
        final today = Map<String, dynamic>.from(m['today'] ?? const {});
        summary.assignAll({
          ...summary,
          'type': kind.apiType,
          'range': range.value,
          'today': today,
        });
      } on SocketException {
        _toastError('لا يوجد اتصال بالإنترنت. تحقق من الشبكة ثم أعد المحاولة.');
      } on TimeoutException {
        _toastError('الخادم لم يستجب في الوقت المناسب. حاول مجددًا بعد قليل.');
      } on FormatException {
        _toastError('حدث خلل أثناء معالجة البيانات. أعد المحاولة لاحقًا.');
      } catch (_) {
        _toastError('حدث خطأ غير متوقع أثناء تحميل سجلات الإغلاق.');
      }
    } else {
      closures.clear();
    }
  }

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

  void _toastError(String message) {
    Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
  }
}
