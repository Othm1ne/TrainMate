// lib/src/features/auth/ui/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _ensureFirestoreProfile(User user) async {
    final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final exists = (await doc.get()).exists;
    if (exists) return;

    final now = DateTime.now();
    await doc.set({
      'name': user.displayName ?? 'New User',
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

  Future<void> _loginWithEmail() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) return;
    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      await _ensureFirestoreProfile(cred.user!);

      if (context.mounted) context.go('/main');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);

    try {
      // 1️⃣ Start Google sign-in flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return; // cancelled by user
      }

      // 2️⃣ Retrieve authentication tokens
      final googleAuth = await googleUser.authentication;

      // 3️⃣ Build Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4️⃣ Sign in with Firebase
      final userCred =
      await FirebaseAuth.instance.signInWithCredential(credential);
      await _ensureFirestoreProfile(userCred.user!);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),

            // --- Email login ---
            ElevatedButton.icon(
              onPressed: _loading ? null : _loginWithEmail,
              icon: _loading
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login),
              label: Text(_loading ? 'Logging in...' : 'Login'),
            ),

            const SizedBox(height: 12),

            // --- Google login ---
            OutlinedButton.icon(
              onPressed: _loading ? null : _loginWithGoogle,
              icon: Image.asset('assets/icons/google.png',height: 24, width: 24),
              label: const Text(
                'Continue with Google',
                style: TextStyle(color: Colors.black87),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide(color: cs.outlineVariant),
              ),
            ),

            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/signup'),
              child: const Text("Don't have an account? Sign up"),
            ),
          ],
        ),
      ),
    );
  }
}
