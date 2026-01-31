import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/ui.dart';
import '../home/home_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailsView extends StatelessWidget {
  const OrderDetailsView({super.key});

  // ✅ نفس روح ألوان الصورة (بيج/بني/كروت ناعمة) — بدون تغيير أي منطق
  static const _bg = Color(0xFFF6F3EF);       // خلفية بيج فاتح
  static const _card = Color(0xFFFFFFFF);     // كرت أبيض
  static const _text = Color(0xFF1B1B1F);
  static const _textMute = Color(0xFF8B8B92);
  static const _divider = Color(0xFFE9E2DC);
  static const _primary = Color(0xFF6A3F2A);  // بني أنيق مثل الصورة
  static final _r = BorderRadius.circular(16);

  Future<bool> _confirmAction({
    required BuildContext context,
    required String title,
    required String message,
    required String okText,
  }) async {
    final res = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: _card,
        title: Text(title, textDirection: TextDirection.rtl),
        content: Text(message, textDirection: TextDirection.rtl),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
            ),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              // ✅ لون OK فقط
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(okText),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    return res == true;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> o = (Get.arguments ?? {}) as Map<String, dynamic>;
    final c = Get.find<HomeController>();

    // ✅ loading محلي لمنع تكرار الضغط
    final busy = false.obs;

    Future<void> _afterSuccessBackToHome() async {
      // تحديث الهوم عشان تختفي الطلبية وتتحدث الأرقام
      try {
        await Future.wait([c.loadOrders(), c.loadDashboard()]);
      } catch (_) {}
      Get.back(); // يرجع للهوم
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          iconTheme: const IconThemeData(color: _primary),
          title: Text(
            'طلب #${o['id']}',
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
        ),
        backgroundColor: _bg,
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _row('العميل', '${o['username']} — ${o['phone']}'),
            _row('العنوان', '${o['address'] ?? ''}'),
            _row('سعر الطلبية', '${o['total'] ?? 0}'),
            _row('العناصر', '${o['items_text'] ?? ''}'),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () {
                final url = (o['maps_url'] ?? '') as String;
                if (url.isNotEmpty) {
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.map),
              label: const Text('إظهار الموقع على الخرائط'),
              style: ElevatedButton.styleFrom(
                // ✅ لون زر الخرائط فقط
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),

            const SizedBox(height: 16),

            Obx(() {
              final isBusy = busy.value;

              return Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isBusy
                          ? null
                          : () async {
                              final ok = await _confirmAction(
                                context: context,
                                title: 'تأكيد التسليم',
                                message: 'هل أنت متأكد أن الطلب #${o['id']} تم تسليمه؟',
                                okText: 'تأكيد',
                              );
                              if (!ok) return;

                              busy.value = true;
                              try {
                                await c.markDelivered(o['id'] as int);
                                await _afterSuccessBackToHome();
                              } finally {
                                busy.value = false;
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('تم التسليم'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isBusy
                          ? null
                          : () async {
                              final ok = await _confirmAction(
                                context: context,
                                title: 'تأكيد الرفض',
                                message: 'هل أنت متأكد أنك تريد رفض الطلب #${o['id']}؟',
                                okText: 'تأكيد',
                              );
                              if (!ok) return;

                              busy.value = true;
                              try {
                                await c.markRejected(
                                  o['id'] as int,
                                  reason: 'رفض الزبون',
                                );
                                await _afterSuccessBackToHome();
                              } finally {
                                busy.value = false;
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('تم الرفض'),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          // ✅ شكل الكرت مثل روح الصورة
          color: _card,
          borderRadius: _r,
          border: Border.all(color: _divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              k,
              style: const TextStyle(
                color: _textMute,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              v,
              style: const TextStyle(
                color: _text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}
