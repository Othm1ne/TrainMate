import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;
  final _fs   = FirebaseStorage.instance;

  /* ---------------- E-mail / password sign-up ---------------- */
  Future<void> createAccount({
    required String email,
    required String password,
    required String fullName,
    required int age,
    required String level,
    required List<String> sports,
    File?   profileImage,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final uid  = cred.user!.uid;

    String? photoUrl;
    if (profileImage != null) {
      final ref = _fs.ref('users/$uid/profile.jpg');
      await ref.putFile(profileImage);
      photoUrl = await ref.getDownloadURL();
      await cred.user!.updatePhotoURL(photoUrl);
    }
    await cred.user!.updateDisplayName(fullName);

    await _db.doc('users/$uid').set({
      'name'   : fullName,
      'age'    : age,
      'level'  : level,
      'sports' : sports,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /* ---------------- Google sign-in ---------------- */
  Future<void> signInWithGoogle() async {
    final gUser = await GoogleSignIn().signIn();
    if (gUser == null) return;                               // user cancelled
    final gAuth = await gUser.authentication;
    final cred  = GoogleAuthProvider.credential(
      idToken: gAuth.idToken,
      accessToken: gAuth.accessToken,
    );
    final userCred = await _auth.signInWithCredential(cred);
    final uid = userCred.user!.uid;

    // first-time login → make shell profile
    final doc = await _db.doc('users/$uid').get();
    if (!doc.exists) {
      await _db.doc('users/$uid').set({
        'name' : userCred.user!.displayName,
        'photoUrl': userCred.user!.photoURL,
        'sports': [],
        'level' : 'Beginner',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
