import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/chat_message.dart';
import 'speaking_indicator.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  /// Called when the user taps the speaker icon (tap again while speaking to
  /// stop).
  final VoidCallback? onSpeak;

  /// True while this message is being read aloud.
  final bool isSpeaking;

  const MessageBubble({
    super.key,
    required this.message,
    this.onSpeak,
    this.isSpeaking = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == Sender.user;
    final scheme = Theme.of(context).colorScheme;
    final bg = isUser ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = isUser ? scheme.onPrimary : scheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(message.text, style: TextStyle(color: fg, fontSize: 15)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.emotion != null && !isUser) ...[
                  Icon(Icons.favorite, size: 11, color: fg.withValues(alpha: 0.6)),
                  const SizedBox(width: 3),
                  Text(
                    message.emotion!,
                    style: TextStyle(
                        color: fg.withValues(alpha: 0.6), fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  DateFormat('HH:mm').format(message.createdAt),
                  style:
                      TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 11),
                ),
                if (!isUser && onSpeak != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onSpeak,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: isSpeaking
                          ? SpeakingIndicator(
                              color: fg.withValues(alpha: 0.85))
                          : Icon(Icons.volume_up,
                              size: 16, color: fg.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
