import 'package:flutter/material.dart';
import 'chat_list_screen.dart';

// If you already have another user's profile page, import it here
// import '../../profile/ui/other_user_profile_screen.dart';

class ChatThreadScreen extends StatefulWidget {
  final ChatThread thread;
  const ChatThreadScreen({super.key, required this.thread});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  bool _muted = false;
  bool _blocked = false;

  final _messages = <Message>[
    Message(text: 'Hey, are you still up for tennis tomorrow?', isMe: false),
    Message(text: 'Yeah, I’m ready to go! What time works for you?', isMe: true),
    Message(text: 'How about 10 AM at the Central Park courts?', isMe: false),
    Message(text: 'Sounds perfect! See you there.', isMe: true),
    Message(text: 'Great! Looking forward to it.', isMe: false),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_muted)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.notifications_off, size: 14),
                  ),
                const Text('Online', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _openOptions,
            tooltip: 'Options',
          )
        ],
      ),
      body: Column(
        children: [
          if (_blocked)
            Container(
              width: double.infinity,
              color: Colors.red.withOpacity(.1),
              padding: const EdgeInsets.all(12),
              child: const Text(
                'You blocked this user. You can unblock them from settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _Bubble(msg: _messages[i]),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      enabled: !_blocked,
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: _blocked ? 'Blocked' : 'Type a message…',
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _blocked ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Actions ---------------------------------------------------------------

  void _openOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OptionTile(
                icon: Icons.person_outline,
                label: 'View Profile',
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: navigate to the other user's profile page
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => _ViewProfileStub(name: widget.thread.name, avatar: widget.thread.avatar)));
                },
              ),
              _OptionTile(
                icon: _muted ? Icons.notifications_off : Icons.notifications_active_outlined,
                label: _muted ? 'Unmute Notifications' : 'Mute Notifications',
                onTap: () {
                  setState(() => _muted = !_muted);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_muted ? 'Conversation muted' : 'Conversation unmuted'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              _OptionTile(
                icon: Icons.block,
                label: 'Block',
                danger: true,
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await _confirm(
                    title: 'Block ${widget.thread.name}?',
                    message: 'They will no longer be able to message you.',
                    confirmLabel: 'Block',
                  );
                  if (ok == true) {
                    setState(() => _blocked = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User blocked')),
                    );
                  }
                },
              ),
              _OptionTile(
                icon: Icons.report_outlined,
                label: 'Report',
                danger: true,
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await _confirm(
                    title: 'Report ${widget.thread.name}?',
                    message: 'We’ll review this conversation for policy violations.',
                    confirmLabel: 'Report',
                  );
                  if (ok == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report submitted')),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: confirmLabel == 'Report' ? Colors.red : null,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(Message(text: text, isMe: true));
      _controller.clear();
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }
}

// --- Models & UI bits --------------------------------------------------------

class Message {
  final String text;
  final bool isMe;
  const Message({required this.text, required this.isMe});
}

class _Bubble extends StatelessWidget {
  final Message msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;
    final cs = Theme.of(context).colorScheme;
    final bg = isMe ? cs.primary : Colors.grey.shade200;
    final fg = isMe ? Colors.white : Colors.black87;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Text(msg.text, style: TextStyle(color: fg)),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : Theme.of(context).colorScheme.onSurface;
    final bg = danger ? Colors.red.withOpacity(.06) : Colors.grey.shade100;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: bg,
        onTap: onTap,
      ),
    );
  }
}

// Simple placeholder for "View Profile" until you wire a real screen.
class _ViewProfileStub extends StatelessWidget {
  final String name;
  final String avatar;
  const _ViewProfileStub({required this.name, required this.avatar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: NetworkImage(avatar),
          onBackgroundImageError: (_, __) {},
        ),
      ),
    );
  }
}