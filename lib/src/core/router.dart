// lib/src/core/router.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/onboarding/ui/onboarding_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/signup_screen.dart';
import '../shell/main_shell.dart';

class AppRouter {
  static final GoRouter config = GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;

      // current location
      final goingToLogin = state.matchedLocation == '/login';
      final goingToSignup = state.matchedLocation == '/signup';
      final goingToOnboarding = state.matchedLocation == '/';

      // if not logged in, block access to main shell
      if (user == null) {
        if (goingToLogin || goingToSignup || goingToOnboarding) return null;
        return '/login';
      }

      // if logged in, skip onboarding/login/signup
      if (goingToLogin || goingToSignup || goingToOnboarding) {
        return '/main';
      }

      return null; // no redirect needed
    },

    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/main',
        builder: (_, __) => const MainShell(),
      ),
    ],
  );
}

/// Helper to listen to auth changes and trigger GoRouter rebuilds
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
