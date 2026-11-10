/// Represents a single message in the AI chat conversation.
///
/// Each message is either from the [isUser] (student) or from the AI.
/// When [isStreaming] is true, the AI is still generating the response.
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isStreaming;

  const ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isStreaming = false,
  });

  /// Create a user message
  factory ChatMessage.user(String content) {
    return ChatMessage(
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  /// Create an AI message (optionally still streaming)
  factory ChatMessage.ai(String content, {bool isStreaming = false}) {
    return ChatMessage(
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      isStreaming: isStreaming,
    );
  }

  /// Create a copy with updated content (used during streaming)
  ChatMessage copyWith({String? content, bool? isStreaming}) {
    return ChatMessage(
      content: content ?? this.content,
      isUser: isUser,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
