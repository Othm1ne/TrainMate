import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import 'location_service.dart';
import 'match_repository.dart' show functions;
import 'storage_service.dart';

class UserRepository {
  UserRepository._();
  static final instance = UserRepository._();

  CollectionReference<Map<String, dynamic>> get users =>
      FirebaseFirestore.instance.collection('users');

  Stream<UserProfile?> watch(String uid) => users
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? UserProfile.fromDoc(d) : null);

  Future<UserProfile?> get(String uid) async {
    final d = await users.doc(uid).get();
    return d.exists ? UserProfile.fromDoc(d) : null;
  }

  /// Creates the profile document right after sign-up.
  Future<void> create(UserProfile p) async {
    final photoUrl = await StorageService.instance
        .upload(p.photoPath, 'users/${p.uid}/avatar.jpg');
    await users.doc(p.uid).set({
      ...p.copyWith(photoPath: photoUrl).toMap(),
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'isPremium': false,
      'blocked': <String>[],
    });
  }

  /// Saves edits from the Edit Profile screen (uploads a new picture if any).
  Future<UserProfile> update(UserProfile p) async {
    final photoUrl = await StorageService.instance
        .upload(p.photoPath, 'users/${p.uid}/avatar.jpg');
    final updated = p.copyWith(photoPath: photoUrl);
    await users.doc(p.uid).update({...updated.toMap(), 'photoUrl': photoUrl});

    // Keep the name/photo copies shown in chat lists in sync.
    final chats = await FirebaseFirestore.instance
        .collection('chats')
        .where('members', arrayContains: p.uid)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final c in chats.docs) {
      batch.update(c.reference, {
        'memberInfo.${p.uid}': {'name': updated.name, 'photoUrl': photoUrl ?? ''},
      });
    }
    await batch.commit();
    return updated;
  }

  /// Refreshes the stored position so distances stay accurate.
  Future<void> refreshLocation(String uid) async {
    final loc = await LocationService.instance.current();
    if (loc == null) return;
    await users.doc(uid).update({
      'lat': loc.lat,
      'lng': loc.lng,
      if (loc.label.isNotEmpty) 'location': loc.label,
    });
  }

  /// isPremium can only be set by the server (see firestore.rules).
  /// Payments are not integrated yet: the function grants it directly —
  /// add receipt verification in functions/src/matching.ts before release.
  Future<void> activatePremium() =>
      functions.httpsCallable('activatePremium').call<void>();

  Future<void> block(String uid, String other) =>
      users.doc(uid).update({'blocked': FieldValue.arrayUnion([other])});

  Future<void> unblock(String uid, String other) =>
      users.doc(uid).update({'blocked': FieldValue.arrayRemove([other])});

  Future<void> report({
    required String reporterId,
    required String reportedId,
    String? chatId,
    String reason = '',
  }) =>
      FirebaseFirestore.instance.collection('reports').add({
        'reporterId': reporterId,
        'reportedId': reportedId,
        'chatId': chatId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
}
