/// One turn of the conversation about a scanned toy.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.isFromParent,
    required this.content,
    required this.createdAt,
  });

  final String id;

  /// True for the parent's question, false for the assistant's answer. Stored
  /// as a role string; kept as a flag here because that is the only thing the
  /// UI ever asks.
  final bool isFromParent;

  final String content;
  final DateTime createdAt;

  factory ChatMessage.fromRow(Map<String, dynamic> r) => ChatMessage(
        id: r['id']?.toString() ?? '',
        isFromParent: r['role'] == 'user',
        content: r['content']?.toString() ?? '',
        createdAt: DateTime.tryParse('${r['created_at']}')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// A question the parent has just asked, before the server has stored it.
  /// Shown immediately so the conversation does not appear to swallow it.
  factory ChatMessage.pending(String content) => ChatMessage(
        id: 'pending',
        isFromParent: true,
        content: content,
        createdAt: DateTime.now(),
      );
}
