import 'package:flutter/material.dart';
import 'chat_thread_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _search = TextEditingController();

  final _threads = <ChatThread>[
    ChatThread(
      name: 'Ethan Harper',
      avatar: 'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=200',
      lastMessage: 'See you at the gym!',
      lastTime: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    ChatThread(
      name: 'Olivia Bennett',
      avatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200',
      lastMessage: "I'm ready to play!",
      lastTime: DateTime.now().subtract(const Duration(minutes: 20)),
    ),
    ChatThread(
      name: 'Noah Carter',
      avatar: 'https://images.unsplash.com/photo-1603415526960-f7e0328d13df?w=200',
      lastMessage: "I'm on my way!",
      lastTime: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    ChatThread(
      name: 'Ava Mitchell',
      avatar: 'https://images.unsplash.com/photo-1544006659-f0b21884ce1d?w=200',
      lastMessage: "I'm ready to play!",
      lastTime: DateTime.now().subtract(const Duration(minutes: 40)),
    ),
    ChatThread(
      name: 'Liam Foster',
      avatar: 'https://images.unsplash.com/photo-1552374196-c4e7ffc6e126?w=200',
      lastMessage: "I'm on my way!",
      lastTime: DateTime.now().subtract(const Duration(minutes: 50)),
    ),
    ChatThread(
      name: 'Sophia Reynolds',
      avatar: 'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?w=200',
      lastMessage: "I'm ready to play!",
      lastTime: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    ChatThread(
      name: 'Jackson Hayes',
      avatar: 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=200',
      lastMessage: "I'm on my way!",
      lastTime: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _threads.where((t) {
      final q = _search.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      return t.name.toLowerCase().contains(q) ||
          t.lastMessage.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final t = filtered[i];
                return ListTile(
                  leading: CircleAvatar(backgroundImage: NetworkImage(t.avatar)),
                  title: Text(t.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    t.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    _relativeTime(t.lastTime),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatThreadScreen(thread: t),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
    // you can swap to a package like "timeago" later if you want locales
  }
}

class ChatThread {
  final String name;
  final String avatar;
  final String lastMessage;
  final DateTime lastTime;

  const ChatThread({
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.lastTime,
  });
}
