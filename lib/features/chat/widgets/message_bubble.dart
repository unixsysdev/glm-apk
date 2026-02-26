import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../models/message_model.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isStreaming;
  final String? streamingReasoning;

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.streamingReasoning,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _reasoningExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = widget.message.isUser;

    // Auto-expand reasoning during streaming
    final isStreamingReasoning = widget.isStreaming &&
        widget.streamingReasoning != null &&
        widget.streamingReasoning!.isNotEmpty;

    // Check if there's reasoning to show
    final hasReasoning = widget.message.hasReasoning || isStreamingReasoning;

    final reasoningText = widget.isStreaming
        ? (widget.streamingReasoning ?? '')
        : (widget.message.reasoningContent ?? '');

    // Auto-expand during streaming, allow collapse after
    final showReasoningContent = isStreamingReasoning || _reasoningExpanded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // Assistant avatar
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF00D9A6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'G',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Message content
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF6C63FF)
                    : (isDark
                        ? const Color(0xFF2A2B45)
                        : const Color(0xFFF0F0F8)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attachments
                  if (widget.message.hasAttachments) ...[
                    ...widget.message.attachments.map((a) => _buildAttachment(a, isDark)),
                    const SizedBox(height: 6),
                  ],

                  // Reasoning section (collapsible)
                  if (hasReasoning && !isUser) ...[
                    _buildReasoningSection(reasoningText, isDark, showReasoningContent),
                    const SizedBox(height: 8),
                  ],

                  // Text content
                  if (isUser)
                    Text(
                      widget.message.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    )
                  else
                    MarkdownBody(
                      data: widget.message.content +
                          (widget.isStreaming ? ' ▌' : ''),
                      selectable: true,
                      styleSheet: _markdownStyle(isDark),
                    ),
                ],
              ),
            ),
          ),

          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildReasoningSection(String reasoning, bool isDark, bool expanded) {
    return GestureDetector(
      onTap: () => setState(() => _reasoningExpanded = !_reasoningExpanded),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1B2E).withOpacity(0.6)
              : const Color(0xFFE8E0FF).withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF6C63FF).withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology_rounded,
                  size: 16,
                  color: const Color(0xFF6C63FF).withOpacity(0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  'Reasoning',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6C63FF).withOpacity(0.7),
                  ),
                ),
                const Spacer(),
                Icon(
                  _reasoningExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 18,
                  color: const Color(0xFF6C63FF).withOpacity(0.5),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              Text(
                reasoning,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark
                      ? Colors.white60
                      : const Color(0xFF4A4B6A),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle(bool isDark) {
    return MarkdownStyleSheet(
      p: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF1A1B2E),
        fontSize: 15,
        height: 1.5,
      ),
      code: TextStyle(
        color: const Color(0xFF00D9A6),
        backgroundColor:
            isDark ? const Color(0xFF1A1B2E) : const Color(0xFFE8E0FF),
        fontFamily: 'monospace',
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1B2E)
            : const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white12
              : const Color(0xFFE0E0EC),
        ),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: const Color(0xFF6C63FF),
            width: 3,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      h1: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF1A1B2E),
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      h2: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF1A1B2E),
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      h3: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF1A1B2E),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      listBullet: TextStyle(
        color: isDark ? Colors.white70 : const Color(0xFF4A4B6A),
      ),
      strong: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF1A1B2E),
        fontWeight: FontWeight.w700,
      ),
      em: TextStyle(
        color: isDark ? Colors.white70 : const Color(0xFF4A4B6A),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildAttachment(Attachment attachment, bool isDark) {
    if (attachment.type == 'image') {
      // Handle base64 data URLs
      if (attachment.url.startsWith('data:')) {
        try {
          final base64Str = attachment.url.split(',').last;
          final bytes = base64Decode(base64Str);
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 200,
                height: 100,
                color: Colors.grey.withOpacity(0.2),
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          );
        } catch (_) {
          return Container(
            width: 200,
            height: 100,
            color: Colors.grey.withOpacity(0.2),
            child: const Icon(Icons.broken_image_outlined),
          );
        }
      }
      // Network URLs (Firebase Storage etc.)
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          attachment.url,
          width: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 200,
            height: 100,
            color: Colors.grey.withOpacity(0.2),
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : const Color(0xFFF0F0F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined, size: 18),
          const SizedBox(width: 6),
          Text(
            attachment.fileName,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
