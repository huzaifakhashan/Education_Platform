import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat.dart';
import '../models/profile.dart';
import 'auth_service.dart';

/// One-to-one private messages. A chat lives at `chats/{uidA}_{uidB}` (ids sorted)
/// with its messages in the `messages` subcollection.
class ChatService {
  ChatService(this._auth);

  final AuthService _auth;
  final _db = FirebaseFirestore.instance;

  String get _me => _auth.uid!;

  static String chatIdFor(String a, String b) => ([a, b]..sort()).join('_');

  DocumentReference<Map<String, dynamic>> _chat(String id) => _db.collection('chats').doc(id);

  /// My conversations, most recent first.
  Stream<List<ChatSummary>> watchChats() {
    return _db.collection('chats').where('participants', arrayContains: _me).snapshots().map((snap) {
      final list = [for (final d in snap.docs) ChatSummary.fromMap(d.id, d.data())];
      list.sort((a, b) => (b.updatedAt ?? DateTime.now()).compareTo(a.updatedAt ?? DateTime.now()));
      return list;
    });
  }

  Stream<List<ChatMessage>> watchMessages(String chatId) {
    return _chat(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => [for (final d in snap.docs) ChatMessage.fromMap(d.id, d.data())]);
  }

  /// Creates the chat if needed and returns its id.
  Future<String> openChat(Profile other) async {
    final id = chatIdFor(_me, other.uid);
    await _chat(id).set({
      'participants': [_me, other.uid]..sort(),
      'names': {_me: _auth.name, other.uid: other.name},
    }, SetOptions(merge: true));
    return id;
  }

  Future<void> send(String chatId, String otherId, String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final chat = _chat(chatId);
    final batch = _db.batch();
    batch.set(chat.collection('messages').doc(), {
      'senderId': _me,
      'text': clean,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(chat, {
      'lastMessage': clean,
      'lastSenderId': _me,
      'updatedAt': FieldValue.serverTimestamp(),
      'unread.$otherId': true,
    });
    await batch.commit();
  }

  Future<void> markRead(String chatId) => _chat(chatId).update({'unread.$_me': false});
}
