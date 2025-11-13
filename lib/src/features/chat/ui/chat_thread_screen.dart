import 'package:flutter/material.dart';
import '../model/chat_thread.dart';

class ChatThreadScreen extends StatefulWidget {
  final ChatThread thread;
  const ChatThreadScreen({super.key, required this.thread});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _ctrl = TextEditingController();
  final _messages = <_Msg>[
    _Msg(text: 'Hey, are you still up for tennis tomorrow?', mine: false),
    _Msg(text: "Yeah, I'm ready to go! What time works for you?", mine: true),
    _Msg(text: 'How about 10 AM at the Central Park courts?', mine: false),
    _Msg(text: 'Sounds perfect! See you there.', mine: true),
    _Msg(text: 'Great! Looking forward to it.', mine: false),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Msg(text: text, mine: true));
      _ctrl.clear();
    });
  }

  void _openOptions() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            _OptTile(
              icon: Icons.person_outline,
              text: 'View Profile',
              onTap: () {
                Navigator.pop(context);
                // TODO: push profile
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('View Profile tapped')),
                );
              },
            ),
            _OptTile(
              icon: Icons.notifications_off_outlined,
              text: 'Mute Notifications',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conversation muted (demo)')),
                );
              },
            ),
            _OptTile(
              icon: Icons.block_outlined,
              text: 'Block',
              danger: true,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User blocked (demo)')),
                );
              },
            ),
            _OptTile(
              icon: Icons.flag_outlined,
              text: 'Report',
              danger: true,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reported (demo)')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Text('Online', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _openOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final align =
                m.mine ? Alignment.centerRight : Alignment.centerLeft;
                final bg = m.mine ? Colors.blue : Colors.grey.shade200;
                final fg = m.mine ? Colors.white : Colors.black87;
                return Align(
                  alignment: align,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * .75,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(m.text, style: TextStyle(color: fg)),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _send,
                    child: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  final String text;
  final bool mine;
  _Msg({required this.text, required this.mine});
}

class _OptTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool danger;
  final VoidCallback onTap;
  const _OptTile({
    required this.icon,
    required this.text,
    this.danger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(text, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
