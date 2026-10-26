import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Registers this device's FCM token under users/{uid}/devices/{token}, so
/// the Cloud Functions can notify about matches and messages.
class PushService {
  PushService._();
  static final instance = PushService._();

  String? _uid;
  String? _token;
  StreamSubscription<String>? _refreshSub;

  /// Foreground messages (the OS doesn't show them while the app is open).
  Stream<RemoteMessage> get onForegroundMessage =>
      kIsWeb ? const Stream.empty() : FirebaseMessaging.onMessage;

  Future<void> register(String uid) async {
    // Web push needs a VAPID key + service worker; mobile only for now.
    if (kIsWeb || _uid == uid) return;
    _uid = uid;
    try {
      final fm = FirebaseMessaging.instance;
      final settings = await fm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      // Token API is deprecated in favour of FID register()/onRegistered, but
      // the Admin SDK's sendEachForMulticast (functions/src/notify.ts) still
      // targets registration tokens. Migrate both sides together.
      // ignore: deprecated_member_use
      await _save(await fm.getToken());
      // ignore: deprecated_member_use
      _refreshSub ??= fm.onTokenRefresh.listen(_save);
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  Future<void> _save(String? token) async {
    final uid = _uid;
    if (token == null || uid == null) return;
    _token = token;
    await FirebaseFirestore.instance.doc('users/$uid/devices/$token').set({
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Call before signing out so this device stops receiving the user's pushes.
  Future<void> unregister() async {
    final uid = _uid, token = _token;
    _uid = null;
    _token = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
    if (uid == null || token == null) return;
    await FirebaseFirestore.instance
        .doc('users/$uid/devices/$token')
        .delete()
        .catchError((_) {});
  }
}
