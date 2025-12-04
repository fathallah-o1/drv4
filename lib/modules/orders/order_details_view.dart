import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/ui.dart';
import '../home/home_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailsView extends StatelessWidget {
  const OrderDetailsView({super.key});

  static const _bg = Colors.white;
  static const _card = Color(0xFFF6F6F8);
  static const _text = Color(0xFF1B1B1F);
  static const _textMute = Color(0xFF6B7280);
  static final _r = BorderRadius.circular(16);

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> o = (Get.arguments ?? {}) as Map<String, dynamic>;
    final c = Get.find<HomeController>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: Text('طلب #${o['id']}',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
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
                backgroundColor: Ui.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await c.markDelivered(o['id'] as int); // ← تعمل
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('تم التسليم'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await c.markRejected(o['id'] as int, reason: 'رفض الزبون'); // ← تعمل
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('تم الرفض'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: _r,
          border: Border.all(color: const Color(0xFFE9E9EE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: const TextStyle(color: _textMute, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(v, style: const TextStyle(color: _text, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
