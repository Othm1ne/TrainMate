import 'package:flutter/material.dart';
import '../../../data/models/chat.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/chat_repository.dart';
import '../../../data/services/user_repository.dart';
import '../../../shared/widgets.dart';
import '../../profile/ui/profile_screen.dart';
import '../../store/data/booking.dart';
import '../../store/data/listing.dart';
import '../../store/data/store_repository.dart';
import '../../store/ui/booking_detail_screen.dart';
import '../../store/ui/listing_detail_screen.dart';
import '../../store/ui/store_widgets.dart';

class ChatThreadScreen extends StatefulWidget {
  final ChatThread thread;
  const ChatThreadScreen({super.key, required this.thread});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _myUid = AuthService.instance.uid;
  late final Stream<ChatThread> _threadStream =
      ChatRepository.instance.thread(widget.thread.id, _myUid);
  late final Stream<List<Message>> _messages =
      ChatRepository.instance.messages(widget.thread.id, _myUid);
  late ChatThread _t = widget.thread;
  int _lastCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _blocked => _t.blockedByMe || _t.blockedByOther;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatThread>(
      stream: _threadStream,
      initialData: widget.thread,
      builder: (context, snap) {
        _t = snap.data ?? widget.thread;
        return Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Avatar(url: _t.avatar, radius: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(_t.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (_t.muted)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.notifications_off, size: 14),
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
                  color: Colors.red.withValues(alpha: .1),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _t.blockedByMe
                        ? 'You blocked this user. Unblock them from the ⋮ menu.'
                        : 'You can no longer reply to this conversation.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_t.isStore && _t.listingId != null)
                _StoreHeader(thread: _t, myUid: _myUid),
              Expanded(
                child: StreamBuilder<List<Message>>(
                  stream: _messages,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final msgs = snap.data!;
                    if (msgs.isEmpty) {
                      return Center(
                        child: Text('Say hi to ${_t.name} 👋',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      );
                    }
                    if (msgs.length != _lastCount) {
                      _lastCount = msgs.length;
                      _scrollToBottom();
                    }
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) => _Bubble(msg: msgs[i]),
                    );
                  },
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
                          textCapitalization: TextCapitalization.sentences,
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
      },
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
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ProfileScreen(uid: _t.otherUid)));
                },
              ),
              _OptionTile(
                icon: _t.muted ? Icons.notifications_off : Icons.notifications_active_outlined,
                label: _t.muted ? 'Unmute Notifications' : 'Mute Notifications',
                onTap: () async {
                  Navigator.pop(ctx);
                  final muted = !_t.muted;
                  await ChatRepository.instance.setMuted(_t.id, _myUid, muted);
                  if (mounted) showSnack(context, muted ? 'Conversation muted' : 'Conversation unmuted');
                },
              ),
              _OptionTile(
                icon: Icons.block,
                label: _t.blockedByMe ? 'Unblock' : 'Block',
                danger: !_t.blockedByMe,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (_t.blockedByMe) {
                    await ChatRepository.instance.setBlocked(_t, _myUid, false);
                    if (mounted) showSnack(context, 'User unblocked');
                    return;
                  }
                  final ok = await _confirm(
                    title: 'Block ${_t.name}?',
                    message: 'They will no longer be able to message you.',
                    confirmLabel: 'Block',
                  );
                  if (ok == true) {
                    await ChatRepository.instance.setBlocked(_t, _myUid, true);
                    if (mounted) showSnack(context, 'User blocked');
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
                    title: 'Report ${_t.name}?',
                    message: 'We’ll review this conversation for policy violations.',
                    confirmLabel: 'Report',
                  );
                  if (ok == true) {
                    await UserRepository.instance.report(
                      reporterId: _myUid,
                      reportedId: _t.otherUid,
                      chatId: _t.id,
                    );
                    if (mounted) showSnack(context, 'Report submitted');
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
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await ChatRepository.instance.send(_t.id, _myUid, text);
    } catch (_) {
      if (!mounted) return;
      _controller.text = text;
      showSnack(context, 'Message not sent. Check your connection.');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }
}

// --- UI bits -----------------------------------------------------------------

class _Bubble extends StatelessWidget {
  final Message msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;
    final cs = Theme.of(context).colorScheme;
    final bg = isMe ? cs.primary : Colors.grey.shade200;
    final fg = isMe ? cs.onPrimary : Colors.black87;
    final time =
        '${msg.sentAt.hour.toString().padLeft(2, '0')}:${msg.sentAt.minute.toString().padLeft(2, '0')}';

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(msg.text, style: TextStyle(color: fg)),
            const SizedBox(height: 2),
            Text(time, style: TextStyle(color: fg.withValues(alpha: .6), fontSize: 10)),
          ],
        ),
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
    final bg = danger ? Colors.red.withValues(alpha: .06) : Colors.grey.shade100;

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

/// Store chats: the listing and the latest rental between the two members.
class _StoreHeader extends StatefulWidget {
  final ChatThread thread;
  final String myUid;
  const _StoreHeader({required this.thread, required this.myUid});

  @override
  State<_StoreHeader> createState() => _StoreHeaderState();
}

class _StoreHeaderState extends State<_StoreHeader> {
  late final Stream<List<Booking>> _bookings =
      StoreRepository.instance.bookingsForListing(widget.myUid, widget.thread.listingId!);

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;
    return Material(
      color: Colors.grey.shade100,
      child: Column(children: [
        ListTile(
          dense: true,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(width: 40, height: 40, child: coverImage(t.listingCover)),
          ),
          title: Text(t.listingTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: const Text('View listing'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: t.listingId!)),
          ),
        ),
        StreamBuilder<List<Booking>>(
          stream: _bookings,
          builder: (context, snap) {
            // Only bookings between these two members.
            final list = (snap.data ?? const <Booking>[])
                .where((b) => b.members(t.otherUid, widget.myUid))
                .toList();
            if (list.isEmpty) return const SizedBox.shrink();
            final b = list.first;
            return ListTile(
              dense: true,
              leading: const Icon(Icons.event_available),
              title: Text('${b.dateLabel} · ${euros(b.price)}'),
              subtitle: Text(b.isOwner(widget.myUid) ? 'Rental request for your item' : 'Your rental'),
              trailing: StatusChip.booking(b.status),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: b.id)),
              ),
            );
          },
        ),
        const Divider(height: 1),
      ]),
    );
  }
}
