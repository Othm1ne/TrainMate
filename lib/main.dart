// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options_dev.dart';
import 'src/services/push_notifications.dart';
import 'src/core/router.dart'; // ✅ centralized routes
import 'src/features/auth/ui/signup_screen.dart';
import 'src/shell/main_shell.dart';

/// ---- initialize Firebase ONCE; tolerate duplicate-app race gracefully ----
Future<void> _initFirebaseOnce() async {
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
}

@pragma('vm:entry-point') // required for Android FCM background isolate
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _initFirebaseOnce();
  // Optionally log or process background notifications
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initFirebaseOnce();

  // App Check (soft mode)
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.deviceCheck,
  );

  // FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Optional status bar styling
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TrainMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
        useMaterial3: true,
      ),
      routerConfig: AppRouter.config, // ✅ use GoRouter for navigation
    );
  }
}
