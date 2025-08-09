import 'package:flutter/material.dart';
import '../features/home/ui/home_screen.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import '../features/profile/ui/profile_screen.dart';
import '../features/chat/ui/chat_list_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 0 Chat, 1 Events, 2 Home, 3 Profile, 4 Premium
  int _tab = 2;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const ChatListScreen(),
      const _Stub(title: 'Events'),
      HomeScreen(onOpenPremium: () => setState(() => _tab = 4)),
      const ProfileScreen(),
      const _Stub(title: 'Premium'),
    ];

    return Scaffold(
      body: pages[_tab],

      // Fancy bottom bar with center bump & animation
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.reactCircle,            // animated, bouncy center
        items: const [
          TabItem(icon: Icons.chat_bubble, title: 'Chat'),
          TabItem(icon: Icons.event, title: 'Events'),
          TabItem(icon: Icons.home, title: 'Home'),   // center bump
          TabItem(icon: Icons.person, title: 'Profile'),
          TabItem(icon: Icons.workspace_premium, title: 'Premium'),
        ],
        initialActiveIndex: _tab,
        height: 64,
        color: Colors.black54,                    // inactive icon/text
        activeColor: ThemeMode.system == ThemeMode.dark
            ? Colors.tealAccent
            : Theme.of(context).colorScheme.primary,
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
