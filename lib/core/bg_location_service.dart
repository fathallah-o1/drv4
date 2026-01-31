import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart'; // لإصلاح DartPluginRegistrant.ensureInitialized()
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/api.dart';

class BackgroundLocationService {
  static const _channelId = 'evoranta_driver_channel';
  static const _channelName = 'EVORANTA Driver Tracking';
  static const _channelDesc = 'Foreground service for driver location tracking';
  static const _notifId = 9913;

  static final FlutterLocalNotificationsPlugin _fln =
FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // ✅ 1) تهيئة local notifications + إنشاء قناة Android
    await _initNotificationChannel();

    // ✅ 2) إعداد background service
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'EVORANTA Driver',
        initialNotificationContent: 'مشاركة الموقع مفعّلة',
        foregroundServiceNotificationId: _notifId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  static Future<void> start(int driverId) async {
    // ✅ Android 13+ لازم إذن إشعارات Runtime
    await _ensureNotificationPermission();

    final service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      await service.startService();
      service.invoke('set-driver', {'driver_id': driverId});
      Future.delayed(const Duration(milliseconds: 400), () {
        service.invoke('set-driver', {'driver_id': driverId});
      });
    } else {
      service.invoke('set-driver', {'driver_id': driverId});
    }
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stop-service');
    }
  }

  // ----------------- Helpers -----------------

  static Future<void> _ensureNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final res = await Permission.notification.request();
        // لو رفض المستخدم، لا نشغل الخدمة حتى لا ينهار startForeground
        if (!res.isGranted) return;
      }
    } catch (_) {
      // أجهزة/إصدارات قديمة: تجاهل
    }
  }

  static Future<void> _initNotificationChannel() async {
    // تهيئة بسيطة (لا نحتاج تفاصيل iOS هنا)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    try {
      await _fln.initialize(initSettings);
    } catch (_) {
      // تجاهل أي خطأ تهيئة
    }

    // ✅ إنشاء القناة — أهم خطوة لمنع Bad notification
    const androidChannel = AndroidNotificationChannel(_channelId,_channelName,description: _channelDesc,importance: Importance.low, // foreground عادة low/balanced
    );

    try {
      final androidPlugin = _fln
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(androidChannel);
    } catch (_) {
      // تجاهل
    }
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    // ✅ ارفع الخدمة للـ foreground + إشعار صالح (القناة موجودة الآن)
    try {
      await service.setAsForegroundService();
    } catch (_) {}

    try {
      await service.setForegroundNotificationInfo(
        title: 'EVORANTA Driver',
        content: 'إرسال الموقع نشط…',
      );
    } catch (_) {}
  }

  int? driverId;
  service.on('set-driver').listen((data) {
    final id = int.tryParse('${data?['driver_id'] ?? ''}');
    if (id != null && id > 0) driverId = id;
  });

  final timer = Timer.periodic(const Duration(seconds: 8), (_) async {
    if (driverId == null || driverId == 0) return;

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
    }
    if (perm == LocationPermission.deniedForever) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await Api.postJson('driver_ping.php', {
        'driver_id': '$driverId',
        'lat': pos.latitude.toStringAsFixed(7),
        'lng': pos.longitude.toStringAsFixed(7),
      });

      if (service is AndroidServiceInstance) {
        try {
          await service.setForegroundNotificationInfo(
            title: 'EVORANTA Driver',
            content:
                'يتم إرسال موقعك… (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})',
          );
        } catch (_) {}
      }
    } catch (_) {
      // تجاهل الأخطاء المؤقتة
    }
  });

  service.on('stop-service').listen((event) async {
    timer.cancel();
    await service.stopSelf();
  });
}
