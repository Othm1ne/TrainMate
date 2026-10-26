import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  String get uid => _auth.currentUser!.uid;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<UserCredential> signUp(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    // Best effort: the "Verified" badge relies on this.
    cred.user?.sendEmailVerification().ignore();
    return cred;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// Returns null if the user cancelled.
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) return _auth.signInWithPopup(GoogleAuthProvider());
    final account = await GoogleSignIn().signIn();
    if (account == null) return null;
    final tokens = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithApple() {
    final provider = AppleAuthProvider()..addScope('email')..addScope('name');
    if (kIsWeb) return _auth.signInWithPopup(provider);
    return _auth.signInWithProvider(provider);
  }

  Future<void> signOut() async {
    if (!kIsWeb) await GoogleSignIn().signOut().catchError((_) => null);
    await _auth.signOut();
  }
}

/// Human-readable message for auth errors.
String authErrorMessage(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
    }
    return e.message ?? 'Authentication failed.';
  }
  return 'Something went wrong. Please try again.';
}
