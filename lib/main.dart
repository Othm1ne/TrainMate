import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trainmate/src/app.dart';
import 'firebase_options_dev.dart'; // your dev options file
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    debugPrintStack(stackTrace: details.stack);
  };

  try {
    debugPrint('==> Firebase init start');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('==> Firebase init OK');

    // Use debug providers until you add your debug token in the console.
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    debugPrint('==> AppCheck activated');
  } catch (e, st) {
    debugPrint('!! Firebase init failed: $e\n$st');
  }

  runApp(const TrainMateApp());
}
