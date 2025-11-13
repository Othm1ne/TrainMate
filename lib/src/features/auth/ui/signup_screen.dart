// lib/src/features/auth/ui/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _createFirestoreProfile(User user, {String? displayName}) async {
    final uid = user.uid;
    final doc = FirebaseFirestore.instance.collection('users').doc(uid);
    final now = DateTime.now();

    final exists = (await doc.get()).exists;
    if (exists) return; // prevent overwriting an existing profile

    await doc.set({
      'name': displayName ?? user.displayName ?? 'New User',
      'location': 'Unknown',
      'joinedYear': now.year,
      'level': '',
      'bio': '',
      'sports': [],
      'badges': [],
      'photoPath': user.photoURL ?? '',
      'createdAt': now.toIso8601String(),
    });
  }

  Future<void> _signUpWithEmail() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) return;

    setState(() => _loading = true);
    try {
      // 1️⃣ Create Firebase Auth user
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      // 2️⃣ Create Firestore profile
      await _createFirestoreProfile(cred.user!, displayName: _nameCtrl.text.trim());

      // 3️⃣ Update Auth display name
      await cred.user?.updateDisplayName(_nameCtrl.text.trim());

      if (context.mounted) context.go('/main');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Sign-up failed')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      // 1️⃣ Trigger Google sign-in flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return; // cancelled by user
      }

      // 2️⃣ Obtain auth details from Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3️⃣ Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4️⃣ Sign in to Firebase with the Google credentials
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user!;
      await _createFirestoreProfile(user);

      if (context.mounted) context.go('/main');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),

            // --- Email Sign Up Button ---
            ElevatedButton.icon(
              onPressed: _loading ? null : _signUpWithEmail,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.person_add),
              label: Text(_loading ? 'Creating Account...' : 'Sign Up'),
            ),

            const SizedBox(height: 12),

            // --- Google Sign In Button ---
            OutlinedButton.icon(
              onPressed: _loading ? null : _signInWithGoogle,
              icon: Image.asset('assets/icons/google.png',height: 24, width: 24),
              label: const Text('Sign in with Google', style: TextStyle(color: Colors.black87)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Already have an account? Log in'),
            ),
          ],
        ),
      ),
    );
  }
}
