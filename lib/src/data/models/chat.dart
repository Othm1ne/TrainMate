import 'package:cloud_firestore/cloud_firestore.dart';

/// Deterministic id so both users always land in the same conversation.
String chatIdFor(String a, String b) {
  final ids = [a, b]..sort();
  return ids.join('_');
}

class ChatThread {
  final String id;
  final String otherUid;
  final String name;
  final String avatar;
  final String lastMessage;
  final DateTime lastTime;
  final bool muted; // muted by me
  final bool blockedByMe;
  final bool blockedByOther;
  // Store chats (one per listing + customer), see functions/src/store.
  final String kind; // partner | store
  final String? listingId;
  final String listingTitle;
  final String listingCover;

  const ChatThread({
    this.id = '',
    this.otherUid = '',
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.lastTime,
    this.muted = false,
    this.blockedByMe = false,
    this.blockedByOther = false,
    this.kind = 'partner',
    this.listingId,
    this.listingTitle = '',
    this.listingCover = '',
  });

  bool get isStore => kind == 'store';

  factory ChatThread.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc, String myUid) {
    final m = doc.data() ?? const {};
    final members = List<String>.from(m['members'] ?? const []);
    final other = members.firstWhere((u) => u != myUid, orElse: () => '');
    final info = Map<String, dynamic>.from(
        (m['memberInfo'] as Map?)?[other] ?? const {});
    final blockedBy = List<String>.from(m['blockedBy'] ?? const []);
    final t = m['lastTime'];
    final listing = Map<String, dynamic>.from(m['listingInfo'] ?? const {});
    return ChatThread(
      id: doc.id,
      otherUid: other,
      name: info['name'] ?? 'TrainMate user',
      avatar: info['photoUrl'] ?? '',
      lastMessage: m['lastMessage'] ?? '',
      lastTime: t is Timestamp ? t.toDate() : DateTime.now(),
      muted: List<String>.from(m['mutedBy'] ?? const []).contains(myUid),
      blockedByMe: blockedBy.contains(myUid),
      blockedByOther: blockedBy.any((u) => u != myUid),
      kind: m['kind'] ?? 'partner',
      listingId: m['listingId'],
      listingTitle: listing['title'] ?? '',
      listingCover: listing['cover'] ?? '',
    );
  }
}

class Message {
  final String id;
  final String text;
  final String senderId;
  final DateTime sentAt;
  final bool isMe;

  Message({
    this.id = '',
    required this.text,
    this.senderId = '',
    DateTime? sentAt,
    required this.isMe,
  }) : sentAt = sentAt ?? DateTime.now();

  factory Message.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc, String myUid) {
    final m = doc.data() ?? const {};
    final t = m['sentAt'];
    final sender = m['senderId'] ?? '';
    return Message(
      id: doc.id,
      text: m['text'] ?? '',
      senderId: sender,
      // sentAt is null locally until the server timestamp resolves.
      sentAt: t is Timestamp ? t.toDate() : DateTime.now(),
      isMe: sender == myUid,
    );
  }
}
