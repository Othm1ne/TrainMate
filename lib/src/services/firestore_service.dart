import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/profile/models/user_profile.dart';

class FirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Fetch current user's profile
  static Future<UserProfile?> getCurrentUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    return UserProfile(
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      joinedYear: data['joinedYear'] ?? DateTime.now().year,
      level: data['level'] ?? '',
      bio: data['bio'] ?? '',
      sports: List<String>.from(data['sports'] ?? []),
      badges: List<String>.from(data['badges'] ?? []),
      photoPath: data['photoPath'],
    );
  }

  /// Update or create current user's profile
  static Future<void> updateUserProfile(UserProfile profile) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).set({
      'name': profile.name,
      'location': profile.location,
      'joinedYear': profile.joinedYear,
      'level': profile.level,
      'bio': profile.bio,
      'sports': profile.sports,
      'badges': profile.badges,
      'photoPath': profile.photoPath,
    }, SetOptions(merge: true));
  }
}
