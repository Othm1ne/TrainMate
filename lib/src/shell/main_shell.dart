import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../data/services/push_service.dart';
import '../data/services/auth_service.dart';
import '../data/services/user_repository.dart';
import '../features/home/ui/home_screen.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import '../features/premium/ui/premium_screen.dart';
import '../features/store/ui/store_screen.dart';
import '../features/profile/ui/profile_screen.dart';
import '../features/chat/ui/chat_list_screen.dart';
import '../features/events/ui/events_list_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 0 Chat, 1 Events, 2 Home, 3 Store, 4 Profile
  int _tab = 2;
  late final List<Widget> _pages;
  StreamSubscription<RemoteMessage>? _pushSub;

  @override
  void initState() {
    super.initState();
    _pages = [
      const ChatListScreen(),
      const EventsListScreen(),
      HomeScreen(onOpenPremium: _openPremium),
      const StoreScreen(),
      const ProfileScreen(),
    ];
    // Keep distances accurate; silently ignored if permission is denied.
    UserRepository.instance.refreshLocation(AuthService.instance.uid).ignore();
    PushService.instance.register(AuthService.instance.uid);
    // The OS doesn't show notifications while the app is open: use a snackbar.
    _pushSub = PushService.instance.onForegroundMessage.listen((m) {
      final n = m.notification;
      if (n == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text([n.title, n.body].whereType<String>().join(': '))),
      );
    });
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    super.dispose();
  }

  // Premium moved out of the tab bar to make room for the Store (spec §14).
  void _openPremium() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab's state (e.g. the swipe deck) alive.
      body: IndexedStack(index: _tab, children: _pages),

      // Fancy bottom bar with center bump & animation
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.reactCircle,            // animated, bouncy center
        items: const [
          TabItem(icon: Icons.chat_bubble, title: 'Chat'),
          TabItem(icon: Icons.event, title: 'Events'),
          TabItem(icon: Icons.home, title: 'Home'),   // center bump
          TabItem(icon: Icons.storefront, title: 'Store'),
          TabItem(icon: Icons.person, title: 'Profile'),
        ],
        initialActiveIndex: _tab,
        height: 64,
        color: Colors.black54,                    // inactive icon/text
        activeColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}
