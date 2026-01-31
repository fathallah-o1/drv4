import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/ui.dart';
import 'history_controller.dart';
import 'history_types.dart';

/// ✅ ثوابت تصميم عامة (تغيير ألوان فقط)
const Color _HBG = Color(0xFFF6F3EF);        // بيج فاتح للخلفية
const Color _HCARD = Color(0xFFFFFFFF);      // كروت بيضاء
const Color _HTEXT = Color(0xFF1B1B1F);
const Color _HTEXT_MUTE = Color(0xFF8B8B92); // رمادي أنعم
const Color _HDIVIDER = Color(0xFFE9E2DC);   // حدود ترابية خفيفة
const Color _HPRIMARY = Color(0xFF6A3F2A);   // بني أساسي مثل الصورة
final BorderRadius _HR = BorderRadius.circular(16);

class HistoryView extends StatelessWidget {
  const HistoryView({super.key, this.kind = HistoryKind.delivered});
  final HistoryKind kind;

  @override
  Widget build(BuildContext context) {
    final c = Get.put(HistoryController(kind: kind));

    const ranges = [
      ['today', 'اليوم'],
      ['week', 'هذا الأسبوع'],
      ['month', 'هذا الشهر'],
      ['all', 'كل الوقت'],
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _HBG,
          elevation: 0,
          iconTheme: const IconThemeData(color: _HPRIMARY),
          title: Text(
            kind.label,
            style: const TextStyle(color: _HPRIMARY, fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
        ),
        backgroundColor: _HBG,
        body: Column(
          children: [
            const SizedBox(height: 8),
            Obx(
              () => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: ranges.map((r) {
                    final String v = r[0];
                    final String label = r[1];
                    final selected = c.range.value == v;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) {
                          c.range.value = v;
                          c.loadAll();
                        },
                        backgroundColor: _HCARD,
                        selectedColor: _HPRIMARY.withOpacity(.14),
                        labelStyle: TextStyle(
                          color: selected ? _HTEXT : _HTEXT_MUTE,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                        shape: StadiumBorder(
                          side: BorderSide(color: selected ? _HPRIMARY : _HDIVIDER),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),

            if (kind == HistoryKind.dues ||
                kind == HistoryKind.debt ||
                kind == HistoryKind.profit)
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      _SummaryBar(kind: kind),
                      TabBar(
                        indicator: const UnderlineTabIndicator(
                          borderSide: BorderSide(color: _HPRIMARY, width: 3),
                        ),
                        labelColor: _HTEXT,
                        unselectedLabelColor: _HTEXT_MUTE,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                        tabs: const [
                          Tab(text: 'الطلبات'),
                          Tab(text: 'سجلات الإغلاق'),
                        ],
                      ),
                      const Expanded(child: _HistoryTabs()),
                    ],
                  ),
                ),
              )
            else
              const Expanded(child: _OrdersOnly()),
          ],
        ),
      ),
    );
  }
}

class _SummaryBar extends GetView<HistoryController> {
  const _SummaryBar({super.key, required this.kind});
  final HistoryKind kind;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = controller.summary;
      if (s.isEmpty) return const SizedBox.shrink();
      String line = 'عدد الطلبات: ${s['orders_count'] ?? s['count'] ?? '-'}'
          ' • إجمالي الطلبات: ${s['sum_total'] ?? s['sum_amount'] ?? '-'}'
          ' • عمولة التوصيل: ${s['sum_delivery'] ?? '-'}'
          ' • المديونية: ${s['sum_debt'] ?? (s['debt_today'] ?? '-')}'
          ' • الربح: ${s['sum_profit'] ?? (s['profit_today'] ?? '-')}';
      if ((s['range'] ?? '') == 'today' && s['today'] is Map) {
        final t = s['today'] as Map;
        line += '  —  (اليوم: مستحقّات ${t['dues_today'] ?? '-'} / مديونية ${t['debt_today'] ?? '-'} / ربح ${t['profit_today'] ?? '-'} )';
      }
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _HCARD,
          borderRadius: _HR,
          border: Border.all(color: _HDIVIDER),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(line, style: const TextStyle(color: _HTEXT, fontWeight: FontWeight.w700)),
      );
    });
  }
}

class _OrdersOnly extends GetView<HistoryController> {
  const _OrdersOnly({super.key});
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      return Column(
        children: [
          const _SummaryBar(kind: HistoryKind.delivered),
          Expanded(
            child: controller.orders.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _HCARD,
                        borderRadius: _HR,
                        border: Border.all(color: _HDIVIDER),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.04),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Text('لا يوجد بيانات',
                          style: TextStyle(color: _HTEXT_MUTE, fontWeight: FontWeight.w700)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (_, i) {
                      final o = controller.orders[i];
                      return _orderTile(o, controller.valueOf(o));
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: controller.orders.length,
                  ),
          ),
        ],
      );
    });
  }
}

class _HistoryTabs extends GetView<HistoryController> {
  const _HistoryTabs({super.key});
  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: [
        // تبويب الطلبات
        Obx(() {
          if (controller.loading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              const _SummaryBar(kind: HistoryKind.dues),
              Expanded(
                child: controller.orders.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: _HCARD,
                            borderRadius: _HR,
                            border: Border.all(color: _HDIVIDER),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.04),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Text('لا يوجد بيانات',
                              style: TextStyle(color: _HTEXT_MUTE, fontWeight: FontWeight.w700)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (_, i) {
                          final o = controller.orders[i];
                          return _orderTile(o, controller.valueOf(o));
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: controller.orders.length,
                      ),
              ),
            ],
          );
        }),
        // تبويب سجلات الإغلاق
        Obx(() {
          if (controller.loading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return controller.closures.isEmpty
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _HCARD,
                      borderRadius: _HR,
                      border: Border.all(color: _HDIVIDER),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.04),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Text('لا يوجد سجلات إغلاق',
                        style: TextStyle(color: _HTEXT_MUTE, fontWeight: FontWeight.w700)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (_, i) {
                    final r = controller.closures[i];
                    final orders = (r['orders'] ?? []) as List;
                    return Card(
                      color: _HCARD,
                      shape: RoundedRectangleBorder(
                        borderRadius: _HR,
                        side: const BorderSide(color: _HDIVIDER),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                        iconColor: _HPRIMARY,
                        collapsedIconColor: _HPRIMARY,
                        title: Text(
                          'تاريخ الإغلاق: ${r['closing_date']} — القيمة: ${r['amount']}',
                          style: const TextStyle(color: _HTEXT, fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          'الطلبات: ${r['order_ids'] ?? ''}',
                          style: const TextStyle(color: _HTEXT_MUTE, fontWeight: FontWeight.w600),
                        ),
                        children: orders.isEmpty
                            ? [
                                const ListTile(
                                  title: Text('لا توجد تفاصيل طلبات',
                                      style: TextStyle(color: _HTEXT_MUTE)),
                                )
                              ]
                            : orders
                                .map(
                                  (o) => ListTile(
                                    title: Text('#${o['id']} — ${o['username']} (${o['phone']})',
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                    subtitle: Text(
                                      'الإجمالي ${o['total']} — عمولة ${o['delivery_fee']} — مديونية ${o['restaurant_due']}',
                                      style: const TextStyle(color: _HTEXT_MUTE),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: controller.closures.length,
                );
        }),
      ],
    );
  }
}

/// بطاقة الطلب داخل القوائم
Widget _orderTile(Map<String, dynamic> o, String valueText) {
  final items = (o['items_text'] ?? '') as String;
  final user = (o['username'] ?? '') as String;
  final phone = (o['phone'] ?? '') as String;

  return Card(
    color: _HCARD,
    shape: RoundedRectangleBorder(
      borderRadius: _HR,
      side: const BorderSide(color: _HDIVIDER),
    ),
    child: ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _HPRIMARY.withOpacity(.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _HDIVIDER),
        ),
        child: const Icon(Icons.receipt_long, color: _HPRIMARY),
      ),
      title: Text(
        '#${o['id']} — $user ($phone)',
        style: const TextStyle(color: _HTEXT, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        items.isEmpty ? '-' : items,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _HTEXT_MUTE, fontWeight: FontWeight.w600),
      ),
      trailing: Text(
        valueText,
        style: const TextStyle(color: _HTEXT, fontWeight: FontWeight.w900),
      ),
    ),
  );
}
