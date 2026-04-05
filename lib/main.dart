import 'dart:async';

import 'package:academic_async/bindings/app_bindings.dart';
import 'package:academic_async/controllers/theme_controller.dart';
import 'package:academic_async/pages/auth/auth_gate_page.dart';
import 'package:academic_async/pages/homepage.dart';
import 'package:academic_async/services/background_service.dart';
import 'package:academic_async/services/event_sync_service.dart';
import 'package:academic_async/services/notification_service.dart';
import 'package:academic_async/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController();
  await themeController.loadPersistedPreferences();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Get.put(themeController, permanent: true);
  runApp(const MyApp());
  unawaited(_warmUpServicesAfterLaunch());
}

Future<void> _warmUpServicesAfterLaunch() async {
  try {
    await NotificationService.initialize();
    await NotificationService.requestPermission();
  } catch (error, stackTrace) {
    debugPrint('Notification bootstrap failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await BackgroundService.initializeAndRegister();
    } catch (error, stackTrace) {
      debugPrint('Background service registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  try {
    await EventSyncService.syncEvents(forceFull: true, sideEffects: true);
  } catch (error, stackTrace) {
    debugPrint('Event sync bootstrap failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class MyApp extends GetView<ThemeController> {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ThemeController>()) {
      Get.put(ThemeController(), permanent: true);
    }

    return Obx(() {
      final Color seed = controller.seedColor.value;
      final bool firebaseReady = Firebase.apps.isNotEmpty;

      return GetMaterialApp(
        title: 'Academic Async',
        debugShowCheckedModeBanner: false,
        initialBinding: AppBindings(),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: seed,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: controller.themeMode.value,
        home: firebaseReady ? const AuthGatePage() : const Homepage(),
      );
    });
  }
}
