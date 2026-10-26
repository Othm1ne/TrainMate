import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'data/models/user_profile.dart';
import 'data/services/auth_service.dart';
import 'data/services/user_repository.dart';
import 'features/auth/ui/signup_screen.dart';
import 'features/onboarding/ui/onboarding_screen.dart';
import 'shell/main_shell.dart';

ThemeData get _theme => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
      useMaterial3: true,
    );

class TrainMateApp extends StatelessWidget {
  const TrainMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrainMate',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      home: const AuthGate(),
    );
  }
}

/// Signed out → onboarding; signed in without a profile (Google/Apple
/// first login) → complete profile; otherwise → the main app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      builder: (context, auth) {
        if (auth.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        final user = auth.data;
        if (user == null) return const OnboardingScreen();

        return StreamBuilder<UserProfile?>(
          key: ValueKey(user.uid),
          stream: UserRepository.instance.watch(user.uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _Splash();
            }
            if (snap.data == null) {
              return const SignUpScreen(completeProfile: true);
            }
            return const MainShell();
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Image.asset('assets/images/logo_icon.png', height: 160),
        ),
      );
}

/// Shown when Firebase could not start (usually: not configured yet).
class SetupErrorApp extends StatelessWidget {
  final String error;
  const SetupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text('Firebase is not set up',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(error, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
