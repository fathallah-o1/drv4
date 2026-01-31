import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui.dart';
import '../orders/order_details_view.dart';
import 'home_controller.dart';
import '../history/history_view.dart';
import '../history/history_types.dart';
import '../driver/driver_profile_view.dart'; // 👈 مضاف

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  // ✅ تعديل ألوان فقط (روح الصورة: بيج/بني/كروت ناعمة)
  static const _bg = Color(0xFFF6F3EF);       // خلفية بيج فاتح
  static const _card = Color(0xFFFFFFFF);     // كرت أبيض
  static const _text = Color(0xFF1B1B1F);
  static const _textMute = Color(0xFF8B8B92); // رمادي أنعم
  static const _divider = Color(0xFFE9E2DC);  // حدود ترابية خفيفة

  // ✅ لون أساسي قريب من الصورة (بديل Ui.orange شكليًا فقط)
  static const _primary = Color(0xFF6A3F2A);  // بني أنيق
  static final _r = BorderRadius.circular(16);

  @override
  Widget build(BuildContext context) {
    final c = Get.put(HomeController());

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _header(c),
              const SizedBox(height: 14),

              _rangeChips(c),
              const SizedBox(height: 12),

              _statsGrid(c, context),

              const SizedBox(height: 18),
              Row(
                children: const [
                  // ✅ لون الأيقونة فقط
                  Icon(Icons.shopping_bag_outlined, color: _primary, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'الطلبات',
                    style: TextStyle(
                      color: _text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Obx(() {
                if (c.orders.isEmpty) {
                  return _emptyCard('لا يوجد طلبات متاحة');
                }
                return Column(
                  children: c.orders.map((o) {
                    final url = (o['maps_url'] ?? '') as String;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: _r,
                        border: Border.all(color: _divider),
                        // ✅ ظل خفيف يشبه الصورة
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.04),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            // ✅ لون أيقونة/خلفية فقط
                            color: _primary.withOpacity(.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _divider),
                          ),
                          child: const Icon(Icons.map, color: _primary),
                        ),
                        title: Text(
                          '#${o['id']} — ${o['username']} (${o['phone']})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const SizedBox(height: 4),
                        trailing: IconButton(
                          icon: const Icon(Icons.directions),
                          // ✅ لون الأيقونة فقط
                          color: _primary,
                          onPressed: () {
                            if (url.isNotEmpty) {
                              launchUrl(Uri.parse(url),
                                  mode: LaunchMode.externalApplication);

                              _snack(
                                title: 'فتح الخريطة',
                                message: 'تم فتح عنوان التسليم في خرائط جوجل',
                                type: _SnackType.ok,
                              );
                            } else {
                              _snack(
                                title: 'تنبيه',
                                message: 'لا يوجد رابط خريطة صالح',
                                type: _SnackType.warn,
                              );
                            }
                          },
                        ),
                        onTap: () => Get.to(
                          () => const OrderDetailsView(),
                          arguments: o,
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),

              const SizedBox(height: 24),

              _closingButtons(c),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(HomeController c) {
    return LayoutBuilder(builder: (ctx, cons) {
      final compact = cons.maxWidth < 360; // شاشات صغيرة
      final chipMax = compact ? 120.0 : 150.0;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          // ✅ لون الهيدر فقط
          color: _primary,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // بطاقة السائق — نجعلها Flexible مع حد أقصى للعرض
            Obx(() {
              final initials = (c.driverName.isNotEmpty)
                  ? c.driverName.value.trim().split(' ')
                      .map((e) => e.isNotEmpty ? e[0] : '')
                      .take(2).join()
                  : 'DR';

              return Flexible(
                flex: 0,
                child: InkWell(
                  onTap: () => Get.to(() => const DriverProfileView(), arguments: {
                    'name': c.driverName.value,
                    'phone': c.driverPhone.value,
                    'last_seen': c.driverLastSeen.value,
                  }),
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: chipMax),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: compact ? 8 : 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(.20)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white.withOpacity(.90),
                            child: Text(
                              initials,
                              style: const TextStyle(
                                // ✅ لون الأحرف فقط
                                color: _primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.driverName.isEmpty ? 'السائق' : c.driverName.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: compact ? 12 : 13,
                                  ),
                                ),
                                Text(
                                  c.driverPhone.isEmpty ? '' : c.driverPhone.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: compact ? 10 : 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(width: 15),

            // مجموعة الحالة/السويتش/الخروج — تنضغط تلقائيًا بفِتِّد بوكس
            Flexible(
              flex: 0,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Obx(
                  () => Row(
                    children: [
                      const Text('متصل', style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 6),
                      Transform.scale(
                        scale: .9,
                        child: Switch.adaptive(
                          value: c.isOnline.value,
                          activeColor: Colors.white,
                          activeTrackColor: Colors.black26,
                          onChanged: (v) => c.setOnline(v),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'تسجيل خروج',
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: () => c.logout(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _rangeChips(HomeController c) {
    final items = ['all', 'month', 'week', 'today'];
    String labelOf(String r) {
      if (r == 'all') return 'كل الوقت';
      if (r == 'month') return 'هذا الشهر';
      if (r == 'week') return 'هذا الأسبوع';
      return 'اليوم';
    }

    return Obx(
      () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          // ✅ نفس روح الكروت
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: items.map((r) {
              final selected = c.range.value == r;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(labelOf(r)),
                  selected: selected,
                  onSelected: (_) {
                    c.range.value = r;
                    c.loadDashboard();
                    _snack(
                      title: 'تم',
                      message: 'تم تغيير المدى إلى: ${labelOf(r)}',
                      type: _SnackType.ok,
                    );
                  },
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: Colors.transparent,
                  // ✅ لون التحديد بني فاتح
                  selectedColor: _primary.withOpacity(.14),
                  labelStyle: TextStyle(
                    color: selected ? _text : _textMute,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: selected ? _primary : _divider,
                    ),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _statsGrid(HomeController c, BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 380;

    Widget statTile(String title, String value,
        {bool filled = false, IconData? icon}) {
      return Container(
        decoration: BoxDecoration(
          // ✅ استبدال filled بلون بني بدل البرتقالي
          color: filled ? _primary : _card,
          borderRadius: _r,
          border: Border.all(color: filled ? Colors.transparent : _divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: filled
                      ? Colors.white.withOpacity(.20)
                      : _primary.withOpacity(.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _divider),
                ),
                child: Icon(
                  icon,
                  color: filled ? Colors.white : _primary,
                  size: 18,
                ),
              ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isSmall ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  color: filled ? Colors.white : _text,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: filled ? Colors.white70 : _textMute,
                fontWeight: FontWeight.w600,
                fontSize: isSmall ? 12 : 13,
              ),
            ),
          ],
        ),
      );
    }

    return Obx(
      () => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.35,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          InkWell(
            onTap: () => Get.to(() => const HistoryView(kind: HistoryKind.delivered)),
            borderRadius: _r,
            child: statTile('تم التسليم', '${c.delivered.value}',
                filled: true, icon: Icons.check_circle),
          ),
          InkWell(
            onTap: () => Get.to(() => const HistoryView(kind: HistoryKind.rejected)),
            borderRadius: _r,
            child: statTile('تم الرفض', '${c.rejected.value}',
                icon: Icons.cancel_outlined),
          ),
          InkWell(
            onTap: () => Get.to(() => const HistoryView(kind: HistoryKind.profit)),
            borderRadius: _r,
            child: statTile('الربح', c.profitAll.value.toStringAsFixed(2),
                icon: Icons.payments_outlined),
          ),
          InkWell(
            onTap: () => Get.to(() => const HistoryView(kind: HistoryKind.dues)),
            borderRadius: _r,
            child: statTile(
                'المستحقات (اليوم)',
                c.duesToday.value.toStringAsFixed(2),
                icon: Icons.account_balance_wallet_outlined),
          ),
          InkWell(
            onTap: () => Get.to(() => const HistoryView(kind: HistoryKind.debt)),
            borderRadius: _r,
            child: statTile(
                'المديونية (اليوم)',
                c.debtToday.value.toStringAsFixed(2),
                icon: Icons.report_gmailerrorred_outlined),
          ),
        ],
      ),
    );
  }

  Widget _closingButtons(HomeController c) {
    Widget btn(String text, VoidCallback onTap) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            // ✅ لون زر الإغلاق فقط (لو تبي يظل برتقالي خليه Ui.orange)
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          onPressed: onTap,
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        btn('إغلاق حساب السائق (اليوم)', () => c.closeDriverDaily()),
        btn('إغلاق حساب المطعم (اليوم)', () => c.closeRestaurantDaily()),
      ],
    );
  }

  static Widget _emptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: _r,
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: _primary),
          const SizedBox(width: 10),
          Text(msg, style: const TextStyle(color: _textMute)),
        ],
      ),
    );
  }

  // ================== Snackbars: تحسين الشكل فقط ==================

  static void _snack({
    required String title,
    required String message,
    required _SnackType type,
  }) {
    IconData icon;
    Color accent;

    switch (type) {
      case _SnackType.ok:
        icon = Icons.check_circle;
        accent = const Color(0xFF1F8A4C);
        break;
      case _SnackType.warn:
        icon = Icons.warning_amber_rounded;
        accent = const Color(0xFFB7791F);
        break;
      case _SnackType.err:
        icon = Icons.error;
        accent = const Color(0xFFC53030);
        break;
    }

    Get.rawSnackbar(
      snackStyle: SnackStyle.FLOATING,
      backgroundColor: Colors.white,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      borderRadius: 16,
      duration: const Duration(seconds: 2),
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(.12),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
      borderColor: const Color(0xFFE9E2DC),
      borderWidth: 1,
      messageText: Row(
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: _text, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(message,
                    style: const TextStyle(
                        color: _textMute, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
      isDismissible: true,
    );
  }
}

enum _SnackType { ok, warn, err }
