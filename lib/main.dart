// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
// 👇 مهم للوصول لأعلام الديبج المرئية
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app_routes.dart';
import 'core/env.dart';
import 'modules/auth/login_view.dart';
import 'modules/home/home_view.dart';
import 'modules/orders/order_details_view.dart';
import 'modules/closures/closures_view.dart';
import 'modules/history/history_view.dart';
import 'modules/driver/driver_profile_view.dart'; // 👈 مضاف

// خدمة تتبّع الموقع بالخلفية (سنؤجل تشغيلها لما المستخدم يفعّل أونلاين)
import 'core/bg_location_service.dart';

void main() async {
  // ✅ اجعل كل شيء داخل نفس الـ Zone لتفادي Zone mismatch
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ✅ عـطِّل كل أوضاع الديبج التي ترسم خطوط/حدود/ألوان على الواجهة
    debugPaintSizeEnabled = false; // حدود الويدجت البنفسجية
    debugPaintBaselinesEnabled = false; // خطوط البيسلاين الحمراء/الزرقاء
    debugPaintPointersEnabled = false; // دوائر لمس
    debugPaintLayerBordersEnabled = false; // حدود الطبقات
    debugRepaintRainbowEnabled = false; // ألوان إعادة الرسم

    // لالتقاط أي استثناءات مبكّرة ومنع خروج التطبيق
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
    };

    await GetStorage.init();
    final box = GetStorage();
    Env.driverId = box.read('driverId') ?? 0;

    // ✳️ لا نشغّل خدمة الخلفية هنا؛ نهيّئها بعد أول فريم فقط
    runApp(const DrvApp());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await BackgroundLocationService.init(); // تهيئة فقط
      } catch (_) {
        // نتجاهل أي خطأ هنا — لا نسقط التطبيق
      }
    });
  }, (err, stack) {
    debugPrint('Zoned error: $err\n$stack');
  });
}

class DrvApp extends StatelessWidget {
  const DrvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Driver',
      // 👇 إيقاف أي أوفرلاي مرئي من MaterialApp أيضاً
      showPerformanceOverlay: false,
      checkerboardRasterCacheImages: false,
      checkerboardOffscreenLayers: false,
      debugShowMaterialGrid: false,

      initialRoute: Env.driverId == 0 ? AppRoutes.login : AppRoutes.home,
      getPages: [
        GetPage(name: AppRoutes.login, page: () => const LoginView()),
        GetPage(name: AppRoutes.home, page: () => const HomeView()),
        GetPage(name: AppRoutes.orderDetails, page: () => const OrderDetailsView()),
        GetPage(name: AppRoutes.closures, page: () => const ClosuresView()),
        GetPage(name: '/history', page: () => const HistoryView()), // احتياط
        GetPage(name: AppRoutes.driverProfile, page: () => const DriverProfileView()), // 👈 مضاف
      ],
      theme: ThemeData(primarySwatch: Colors.orange),
    );
  }
}
