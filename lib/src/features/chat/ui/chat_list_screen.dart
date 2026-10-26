import 'package:flutter/material.dart';
import '../../../data/models/chat.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/chat_repository.dart';
import '../../../shared/widgets.dart';
import 'chat_thread_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _search = TextEditingController();
  String _kind = 'all'; // all | partner | store
  late final Stream<List<ChatThread>> _threads =
      ChatRepository.instance.threads(AuthService.instance.uid);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(children: [
              for (final (k, label) in [('all', 'All'), ('partner', 'Partners'), ('store', 'Store')])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: StreamBuilder<List<ChatThread>>(
              stream: _threads,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Could not load chats.'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final q = _search.text.trim().toLowerCase();
                final filtered = snap.data!.where((t) {
                  if (_kind != 'all' && t.kind != _kind) return false;
                  if (q.isEmpty) return true;
                  return t.name.toLowerCase().contains(q) ||
                      t.listingTitle.toLowerCase().contains(q) ||
                      t.lastMessage.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        q.isNotEmpty
                            ? 'No chats match "$q".'
                            : _kind == 'store'
                                ? 'No store conversations yet.\nContact a seller from the Store tab.'
                                : 'No conversations yet.\nMatch with someone on Home to start chatting!',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, i) {
                    final t = filtered[i];
                    return ListTile(
                      leading: t.isStore
                          ? Stack(clipBehavior: Clip.none, children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(width: 40, height: 40, child: coverImage(t.listingCover)),
                              ),
                              Positioned(right: -6, bottom: -6, child: Avatar(url: t.avatar, radius: 11)),
                            ])
                          : Avatar(url: t.avatar),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(t.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          if (t.muted)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.notifications_off, size: 14),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        t.isStore ? '🛒 ${t.listingTitle} · ${t.lastMessage}' : t.lastMessage,
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
  }
}
