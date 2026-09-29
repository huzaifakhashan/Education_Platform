class ChatSummary {
  final String id;
  final List<String> participants;
  final Map<String, String> names;
  final String lastMessage;
  final String? lastSenderId;
  final DateTime? updatedAt;
  final Map<String, bool> unread;

  const ChatSummary({
    required this.id,
    required this.participants,
    required this.names,
    required this.lastMessage,
    required this.lastSenderId,
    required this.updatedAt,
    required this.unread,
  });

  String otherId(String me) => participants.firstWhere((p) => p != me, orElse: () => me);
  String otherName(String me) => names[otherId(me)] ?? 'مستخدم';
  bool isUnread(String me) => unread[me] == true;

  factory ChatSummary.fromMap(String id, Map<String, dynamic> m) => ChatSummary(
        id: id,
        participants: List<String>.from(m['participants'] ?? const []),
        names: Map<String, String>.from(m['names'] ?? const {}),
        lastMessage: (m['lastMessage'] as String?) ?? '',
        lastSenderId: m['lastSenderId'] as String?,
        updatedAt: _toDate(m['updatedAt']),
        unread: Map<String, bool>.from(m['unread'] ?? const {}),
      );
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> m) => ChatMessage(
        id: id,
        senderId: (m['senderId'] as String?) ?? '',
        text: (m['text'] as String?) ?? '',
        // Null while the server timestamp is still pending (local write).
        createdAt: _toDate(m['createdAt']) ?? DateTime.now(),
      );
}

DateTime? _toDate(Object? v) {
  // Firestore Timestamp exposes toDate(); avoid importing cloud_firestore in models.
  if (v == null) return null;
  try {
    return (v as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}
