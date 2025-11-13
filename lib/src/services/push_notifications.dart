import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PushNotifications {
  static Future<void> init() async {
    final fm = FirebaseMessaging.instance;

    // Android 13+ permission
    await fm.requestPermission();

    final uid = FirebaseAuth.instance.currentUser!.uid;

    Future<void> saveToken(String? token) async {
      if (token == null) return;
      await FirebaseFirestore.instance.doc('users/$uid/devices/$token').set({
        'platform': Platform.isIOS ? 'ios' : 'android',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await saveToken(await fm.getToken());
    fm.onTokenRefresh.listen(saveToken);

    // Foreground message hook (show a snackbar or local notif if you want)
    FirebaseMessaging.onMessage.listen((message) {
      // TODO: show in-app banner/snackbar if desired
    });
  }
}
