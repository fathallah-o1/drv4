import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/ui.dart';
import 'driver_profile_controller.dart';

class DriverProfileView extends StatelessWidget {
  const DriverProfileView({super.key});

  // ✅ ألوان بنفس روح الصورة
  static const Color _bg = Color(0xFFF6F3EF);
  static const Color _card = Color(0xFFFFFFFF);
  static const Color _divider = Color(0xFFE9E2DC);
  static const Color _text = Color(0xFF1B1B1F);
  static const Color _muted = Color(0xFF8B8B92);
  static const Color _primary = Color(0xFF6A3F2A);
  static final BorderRadius _r = BorderRadius.circular(16);

  @override
  Widget build(BuildContext context) {
    final c = Get.put(DriverProfileController());

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text(
            'بيانات السائق',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          backgroundColor: _bg,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: _primary),
          titleTextStyle: const TextStyle(color: _primary, fontSize: 18),
        ),
        body: Obx(() {
          nameCtrl.text = c.name.value;
          phoneCtrl.text = c.phone.value; // للعرض فقط

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _card,
                    shape: BoxShape.circle,
                    border: Border.all(color: _divider),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: _primary.withOpacity(.12),
                    backgroundImage: (c.avatarUrl.value.isNotEmpty)
                        ? NetworkImage(c.avatarUrl.value)
                        : null,
                    child: (c.avatarUrl.value.isEmpty)
                        ? const Icon(Icons.person, size: 42, color: _primary)
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _infoCard(
                child: Column(
                  children: [
                    _infoRow('آخر ظهور', c.lastSeen.value),
                    const SizedBox(height: 8),
                    _infoRow('تاريخ التسجيل', c.createdAt.value),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _field(label: 'الاسم', ctrl: nameCtrl),
              const SizedBox(height: 10),

              // ===== الهاتف للعرض فقط (readOnly) =====
              TextField(
                controller: phoneCtrl,
                readOnly: true, // ✅ يمنع التعديل
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'الهاتف',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primary, width: 1.2),
                  ),
                  filled: true,
                  fillColor: _card,
                  suffixIcon: const Icon(Icons.lock_outline, color: _primary),
                  labelStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
                ),
              ),

              const SizedBox(height: 14),

              Obx(
                () => ElevatedButton(
                  onPressed: c.loading.value
                      ? null
                      : () {
                          // نحفظ الاسم فقط — بدون تعديل الهاتف
                          c.name.value = nameCtrl.text.trim();
                          c.saveProfile();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: c.loading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'حفظ التغييرات',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              Divider(color: _divider),
              const SizedBox(height: 8),

              const Text(
                'تغيير كلمة المرور',
                style: TextStyle(color: _text, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),

              _field(label: 'القديمة', ctrl: oldCtrl, obscure: true),
              const SizedBox(height: 8),
              _field(label: 'الجديدة', ctrl: newCtrl, obscure: true),
              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: () => c.changePassword(oldCtrl.text, newCtrl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B2B2B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'تغيير كلمة المرور',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.2),
        ),
        filled: true,
        fillColor: _card,
        labelStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _infoCard({required Widget child}) {
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
      child: child,
    );
  }

  Widget _infoRow(String k, String v) {
    return Row(
      children: [
        Text('$k: ', style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
        Expanded(
          child: Text(
            v.isEmpty ? '—' : v,
            textAlign: TextAlign.start,
            style: const TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
