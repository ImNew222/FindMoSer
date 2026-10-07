import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../config/app_theme.dart';
import '../models/chat_message.dart';

/// A neumorphic-styled chat bubble for the AI chat screen.
///
/// Renders differently based on whether the message is from the user or AI.
/// Supports markdown rendering for AI responses and copy-on-long-press.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final int animationIndex;

  const ChatBubble({super.key, required this.message, this.animationIndex = 0});

  void _copyToClipboard(BuildContext context) {
    if (message.content.isEmpty) return;
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copied', style: TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
        backgroundColor: AppTheme.textPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final screenWidth = MediaQuery.of(context).size.width;

    return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () => _copyToClipboard(context),
            child: Container(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.78),
              margin: EdgeInsets.only(
                top: 4,
                bottom: 4,
                left: isUser ? 48 : 0,
                right: isUser ? 0 : 48,
              ),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Message bubble -- neumorphic raised
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : AppTheme.background,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 6),
                        bottomRight: Radius.circular(isUser ? 6 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.neumorphicLight.withValues(
                            alpha: 0.7,
                          ),
                          offset: const Offset(-3, -3),
                          blurRadius: 8,
                        ),
                        BoxShadow(
                          color: AppTheme.neumorphicDark.withValues(alpha: 0.4),
                          offset: const Offset(3, 3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // AI label
                        if (!isUser)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 11,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Faculty assistant',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Message content
                        if (message.content.isNotEmpty &&
                            !message.isUser &&
                            !message.isStreaming)
                          // AI responses: render as markdown
                          MarkdownBody(
                            data: message.content,
                            selectable: true,
                            shrinkWrap: true,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: AppTheme.textPrimary,
                              ),
                              strong: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              em: const TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: AppTheme.textPrimary,
                              ),
                              code: TextStyle(
                                fontSize: 13,
                                color: AppTheme.primary,
                                backgroundColor: AppTheme.surfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: AppTheme.surfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              codeblockPadding: const EdgeInsets.all(12),
                              listBullet: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                              ),
                              h1: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                              h2: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              h3: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.4,
                                    ),
                                    width: 3,
                                  ),
                                ),
                              ),
                              blockquotePadding: const EdgeInsets.only(
                                left: 12,
                              ),
                            ),
                          )
                        else if (message.content.isNotEmpty && message.isUser)
                          // User messages: plain text
                          Text(
                            message.content,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: AppTheme.textPrimary,
                            ),
                          )
                        else if (message.content.isNotEmpty &&
                            message.isStreaming)
                          // Streaming AI: plain text (markdown not stable during stream)
                          Text(
                            message.content,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: AppTheme.textPrimary,
                            ),
                          ),

                        // Typing indicator (when streaming and content is empty)
                        if (message.isStreaming && message.content.isEmpty)
                          _buildTypingIndicator(),

                        // Streaming cursor
                        if (message.isStreaming && message.content.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: SizedBox(
                              width: 8,
                              height: 16,
                              child: Container(color: AppTheme.primary)
                                  .animate(onPlay: (c) => c.repeat())
                                  .fadeIn(duration: 500.ms)
                                  .then()
                                  .fadeOut(duration: 500.ms),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Timestamp + copy hint
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textHint,
                          ),
                        ),
                        if (!isUser &&
                            message.content.isNotEmpty &&
                            !message.isStreaming) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.copy_rounded,
                            size: 10,
                            color: AppTheme.textHint.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Hold to copy',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.textHint.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate(
          delay: Duration(
            milliseconds: animationIndex >= 0 ? animationIndex * 50 : 0,
          ),
        )
        .fadeIn(duration: 200.ms)
        .slideY(begin: 0.1, end: 0, duration: 200.ms);
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            )
            .animate(
              onPlay: (c) => c.repeat(),
              delay: Duration(milliseconds: i * 200),
            )
            .scaleXY(begin: 0.5, end: 1.0, duration: 600.ms)
            .then()
            .scaleXY(begin: 1.0, end: 0.5, duration: 600.ms);
      }),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
