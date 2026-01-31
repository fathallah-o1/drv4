import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/ui.dart';
import 'login_controller.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  // ✅ ألوان بنفس روح التصميم الموحد
  static const _bg = Color(0xFFF6F3EF);        // خلفية بيج
  static const _card = Color(0xFFFFFFFF);      // كرت أبيض
  static const _text = Color(0xFF1B1B1F);
  static const _textMute = Color(0xFF8B8B92);
  static const _divider = Color(0xFFE9E2DC);
  static const _primary = Color(0xFF6A3F2A);   // بني أساسي

  @override
  Widget build(BuildContext context) {
    final c = Get.put(LoginController());

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.all(24),
            width: 420,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.delivery_dining, color: _primary),
                    SizedBox(width: 8),
                    Text(
                      'تسجيل دخول السائق',
                      style: TextStyle(
                        color: _text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                TextField(
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: _text),
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    labelStyle: const TextStyle(color: _textMute, fontWeight: FontWeight.w700),
                    filled: true,
                    fillColor: _card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: _divider),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: _primary, width: 1.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    prefixIcon: const Icon(Icons.phone, color: _primary),
                  ),
                  onChanged: (v) => c.phone.value = v,
                ),

                const SizedBox(height: 12),

                TextField(
                  obscureText: true,
                  style: const TextStyle(color: _text),
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    labelStyle: const TextStyle(color: _textMute, fontWeight: FontWeight.w700),
                    filled: true,
                    fillColor: _card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: _divider),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: _primary, width: 1.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    prefixIcon: const Icon(Icons.lock, color: _primary),
                  ),
                  onChanged: (v) => c.pass.value = v,
                ),

                const SizedBox(height: 8),

                Obx(
                  () => Text(
                    c.error.value,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: c.loading.value ? null : c.submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: c.loading.value
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'دخول',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
