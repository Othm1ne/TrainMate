// lib/src/core/router.dart
import 'package:go_router/go_router.dart';
import '../features/onboarding/ui/onboarding_screen.dart';
import '../features/auth/ui/login_screen.dart';

class AppRouter {
  static final config = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
    ],
  );
}
