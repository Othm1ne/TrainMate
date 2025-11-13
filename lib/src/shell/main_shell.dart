// lib/src/features/shell/main_shell.dart
import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';

import '../features/home/ui/home_screen.dart';
import '../features/profile/ui/profile_screen.dart';
import '../features/chat/ui/chat_list_screen.dart';
import '../features/events/ui/events_list_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 2; // Center tab = Home

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const ChatListScreen(),
      const EventsListScreen(),
      const HomeScreen(),
      const ProfileScreen(),
      const _Stub(title: 'Premium'),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.reactCircle,
        items: const [
          TabItem(icon: Icons.chat_bubble, title: 'Chat'),
          TabItem(icon: Icons.event, title: 'Events'),
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.person, title: 'Profile'),
          TabItem(icon: Icons.workspace_premium, title: 'Premium'),
        ],
        initialActiveIndex: _tab,
        height: 64,
        color: Colors.black54,
        activeColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _Stub extends StatelessWidget {
  final String title;
  const _Stub({required this.title, super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(child: Text('$title – coming soon…')),
  );
}
