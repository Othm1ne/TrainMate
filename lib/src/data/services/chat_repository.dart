import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat.dart';
import 'user_repository.dart';

class ChatRepository {
  ChatRepository._();
  static final instance = ChatRepository._();

  CollectionReference<Map<String, dynamic>> get _chats =>
      FirebaseFirestore.instance.collection('chats');

  Stream<List<ChatThread>> threads(String myUid) => _chats
      .where('members', arrayContains: myUid)
      .orderBy('lastTime', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => ChatThread.fromDoc(d, myUid)).toList());

  Stream<ChatThread> thread(String chatId, String myUid) => _chats
      .doc(chatId)
      .snapshots()
      .map((d) => ChatThread.fromDoc(d, myUid));

  Stream<List<Message>> messages(String chatId, String myUid) => _chats
      .doc(chatId)
      .collection('messages')
      .orderBy('sentAt')
      .limitToLast(200)
      .snapshots()
      .map((s) => s.docs.map((d) => Message.fromDoc(d, myUid)).toList());

  Future<void> send(String chatId, String myUid, String text) async {
    final batch = FirebaseFirestore.instance.batch();
    final chat = _chats.doc(chatId);
    batch.set(chat.collection('messages').doc(), {
      'senderId': myUid,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
    });
    batch.update(chat, {
      'lastMessage': text,
      'lastTime': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> setMuted(String chatId, String myUid, bool muted) =>
      _chats.doc(chatId).update({
        'mutedBy': muted
            ? FieldValue.arrayUnion([myUid])
            : FieldValue.arrayRemove([myUid]),
      });

  Future<void> setBlocked(ChatThread t, String myUid, bool blocked) async {
    await _chats.doc(t.id).update({
      'blockedBy': blocked
          ? FieldValue.arrayUnion([myUid])
          : FieldValue.arrayRemove([myUid]),
    });
    blocked
        ? await UserRepository.instance.block(myUid, t.otherUid)
        : await UserRepository.instance.unblock(myUid, t.otherUid);
  }
}
