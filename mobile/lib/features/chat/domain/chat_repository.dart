class Conversation {
  const Conversation({
    required this.id,
    required this.withPublicId,
    required this.status,
    required this.unread,
    this.lastMessageAt,
  });
  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'].toString(),
    withPublicId: json['withPublicId'] as String? ?? '',
    status: json['status'] as String? ?? 'ACTIVE',
    unread: (json['unread'] as num?)?.toInt() ?? 0,
    lastMessageAt: DateTime.tryParse(json['lastMessageAt'] as String? ?? '')
        ?.toUtc(),
  );
  final String id;
  final String withPublicId;
  final String status;
  final int unread;
  final DateTime? lastMessageAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'withPublicId': withPublicId,
    'status': status,
    'unread': unread,
    'lastMessageAt': ?lastMessageAt?.toUtc().toIso8601String(),
  };
}

enum ChatMessageType { text, image }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.text,
    this.mediaId,
    required this.createdAt,
    this.pending = false,
    this.failed = false,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'].toString(),
    conversationId: json['conversationId'].toString(),
    senderId: json['senderId'] as String? ?? '',
    type: json['type'] == 'IMAGE'
        ? ChatMessageType.image
        : ChatMessageType.text,
    text: json['text'] as String?,
    mediaId: json['mediaId'] as String?,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
  );
  final String id;
  final String conversationId;
  final String senderId;
  final ChatMessageType type;
  final String? text;
  final String? mediaId;
  final DateTime createdAt;
  final bool pending;
  final bool failed;
  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'type': type == ChatMessageType.image ? 'IMAGE' : 'TEXT',
    'text': ?text,
    'mediaId': ?mediaId,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
  ChatMessage copyWith({String? id, bool? pending, bool? failed}) =>
      ChatMessage(
        id: id ?? this.id,
        conversationId: conversationId,
        senderId: senderId,
        type: type,
        text: text,
        mediaId: mediaId,
        createdAt: createdAt,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
      );
}

abstract interface class ChatRepository {
  Future<Conversation> createConversation(String withPublicId);
  Future<List<Conversation>> conversations();
  Future<List<ChatMessage>> messages(
    String conversationId, {
    String? before,
    int limit = 30,
  });
  Future<ChatMessage> sendText(String conversationId, String text);
  Future<ChatMessage> sendImage(String conversationId, String mediaId);
  Future<void> markRead(String conversationId);
}
