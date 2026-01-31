import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/api.dart';
import '../../core/ui.dart';
import '../../core/env.dart';

class ClosuresView extends StatefulWidget {
  const ClosuresView({super.key});
  @override
  State<ClosuresView> createState() => _ClosuresViewState();
}

class _ClosuresViewState extends State<ClosuresView> {
  List driver = [], restaurant = [];
  Map<String, dynamic> today = const {};
  bool loading = true;

  // ✅ تغيير ألوان فقط (نفس روح الصورة)
  static const _bg = Color(0xFFF6F3EF);
  static const _card = Color(0xFFFFFFFF);
  static const _text = Color(0xFF1B1B1F);
  static const _textMute = Color(0xFF8B8B92);
  static const _divider = Color(0xFFE9E2DC);
  static const _primary = Color(0xFF6A3F2A);
  static final _r = BorderRadius.circular(16);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final r = await Api.getJson('closures_list.php', {'driver_id': '${Env.driverId}'});
      driver = (r['driver'] ?? []) as List;
      restaurant = (r['restaurant'] ?? []) as List;
      today = Map<String, dynamic>.from((r['today'] ?? {}) as Map? ?? {});
    } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          iconTheme: const IconThemeData(color: _primary),
          title: const Text(
            'سجل الإغلاقات',
            style: TextStyle(color: _primary, fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
        ),
        backgroundColor: _bg,
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (today.isNotEmpty) _todayCard(today),
                  const SizedBox(height: 12),
                  _section('إغلاقات السائق اليومية', driver, isDriver: true),
                  const SizedBox(height: 12),
                  _section('إغلاقات المطعم اليومية', restaurant),
                ],
              ),
      ),
    );
  }

  Widget _todayCard(Map<String, dynamic> t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
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
          Row(children: const [
            Icon(Icons.today, color: _primary, size: 18),
            SizedBox(width: 6),
            Text(
              'ملخّص اليوم',
              style: TextStyle(
                color: _text,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text('المستحقّات اليوم: ${t['dues_today'] ?? 0}',
              style: const TextStyle(color: _text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('المديونية اليوم: ${t['debt_today'] ?? 0}',
              style: const TextStyle(color: _text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('الربح اليوم: ${t['profit_today'] ?? 0}',
              style: const TextStyle(color: _text, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _section(String title, List data, {bool isDriver = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
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
          Row(children: [
            const Icon(Icons.history_toggle_off, color: _primary, size: 18),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: _text,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ]),
          const SizedBox(height: 10),

          ...data.map((e) {
            final subtitle =
                'عدد الطلبات: ${e['deliveries_count'] ?? e['orders_count']} — رقم الطلبات: ${e['order_ids'] ?? ''}';
            final titleText =
                '${e['closing_date']} — ${isDriver ? e['delivery_earnings_total'] : e['orders_total']}';
            final orders = (e['orders'] ?? []) as List;

            return Card(
              color: _card,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: _r,
                side: const BorderSide(color: _divider),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                iconColor: _primary,
                collapsedIconColor: _primary,
                title: Text(
                  titleText,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: const TextStyle(
                    color: _textMute,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: orders.isEmpty
                    ? const [
                        Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'لا توجد تفاصيل طلبات لهذا الإغلاق',
                            style: TextStyle(color: _textMute, fontWeight: FontWeight.w600),
                          ),
                        )
                      ]
                    : orders
                        .map(
                          (o) => ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                            title: Text(
                              '#${o['id']} — ${o['username']} (${o['phone']})',
                              style: const TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'الإجمالي: ${o['total']} — عمولة التوصيل: ${o['delivery_fee']} — مديونية: ${o['restaurant_due']}',
                              style: const TextStyle(
                                color: _textMute,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
}
