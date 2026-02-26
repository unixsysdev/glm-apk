import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/message_model.dart';
import '../../core/constants.dart';
import '../auth/auth_provider.dart';
import 'chat_provider.dart';
import 'widgets/message_bubble.dart';
import 'widgets/model_selector.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  final List<Attachment> _pendingAttachments = [];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;
    _controller.clear();
    final attachments = List<Attachment>.from(_pendingAttachments);
    setState(() => _pendingAttachments.clear());
    ref.read(chatNotifierProvider.notifier).sendMessage(
      text.isNotEmpty ? text : 'What is in this image?',
      attachments: attachments.isNotEmpty ? attachments : null,
    );
    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await File(picked.path).readAsBytes();
      final base64 = base64Encode(bytes);
      final ext = picked.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final dataUrl = 'data:$mimeType;base64,$base64';
      setState(() {
        _pendingAttachments.add(Attachment(
          type: 'image',
          url: dataUrl,
          fileName: picked.name,
          mimeType: mimeType,
        ));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);
    final chatState = ref.watch(chatNotifierProvider);
    final userAsync = ref.watch(userProvider);
    final user = userAsync.valueOrNull;

    // Scroll when streaming
    if (chatState.isStreaming) {
      _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geepity'),
        actions: [
          // Free messages counter
          if (user != null && user.isFree)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: user.freeMessagesRemaining <= 5
                    ? const Color(0xFFFF6B6B).withOpacity(0.2)
                    : const Color(0xFF6C63FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 14,
                    color: user.freeMessagesRemaining <= 5
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF6C63FF),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${user.freeMessagesRemaining}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: user.freeMessagesRemaining <= 5
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFF6C63FF),
                    ),
                  ),
                ],
              ),
            ),

          // Model selector
          const ModelSelector(),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messages.when(
              data: (msgs) {
                if (msgs.isEmpty && !chatState.isStreaming) {
                  return _buildEmptyState(context);
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: msgs.length + (chatState.isStreaming ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < msgs.length) {
                      return MessageBubble(message: msgs[index]);
                    }
                    // Streaming message
                    return MessageBubble(
                      message: MessageModel(
                        messageId: 'streaming',
                        role: 'assistant',
                        content: chatState.streamingText,
                        createdAt: DateTime.now(),
                      ),
                      isStreaming: true,
                      streamingReasoning: chatState.streamingReasoning,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildEmptyState(context),
            ),
          ),

          // Error banner
          if (chatState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFF6B6B).withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFFF6B6B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatState.error!,
                      style: const TextStyle(
                          color: Color(0xFFFF6B6B), fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      // Clear error by re-setting state
                    },
                  ),
                ],
              ),
            ),

          // Input bar
          _buildInputBar(context, chatState, user),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF00D9A6)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.chat_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'Start a conversation',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Ask anything — code, research, ideas...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, ChatState chatState, dynamic user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = user != null && user.isFree && !user.hasFreeMessages;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242540) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Attachment preview strip
          if (_pendingAttachments.isNotEmpty)
            Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingAttachments.length,
                itemBuilder: (context, i) {
                  final att = _pendingAttachments[i];
                  return Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF6C63FF).withOpacity(0.3),
                          ),
                          image: att.type == 'image' && att.url.startsWith('data:')
                              ? DecorationImage(
                                  image: MemoryImage(base64Decode(att.url.split(',').last)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: att.type != 'image'
                            ? const Center(child: Icon(Icons.description, size: 28))
                            : null,
                      ),
                      Positioned(
                        top: -4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _pendingAttachments.removeAt(i)),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6B6B),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment button — only for vision-capable models
          Builder(
            builder: (context) {
              final currentModel = ref.watch(selectedModelProvider);
              final allModels = [...ApiConstants.chutesModels, ...ApiConstants.proModels];
              final match = allModels.where((m) => m.modelId == currentModel);
              final supportsImages = match.isNotEmpty && match.first.supportsImages;
              return IconButton(
                icon: Icon(
                  Icons.attach_file_rounded,
                  color: supportsImages
                      ? (isDark ? Colors.white38 : const Color(0xFF8A8BAA))
                      : (isDark ? Colors.white12 : const Color(0xFFD0D0D0)),
                ),
                onPressed: isDisabled || !supportsImages
                    ? (supportsImages ? null : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('This model does not support image uploads'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      })
                    : () => _showAttachmentOptions(context),
              );
            },
          ),

          // Text field
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !isDisabled,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: isDisabled
                    ? 'Free messages used up — add API key or go Pro'
                    : 'Type a message...',
                border: InputBorder.none,
                fillColor: Colors.transparent,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),

          // Send / Stop button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: chatState.isStreaming
                ? IconButton(
                    key: const ValueKey('stop'),
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.stop_rounded,
                          color: Colors.white, size: 20),
                    ),
                    onPressed: () =>
                        ref.read(chatNotifierProvider.notifier).stopStreaming(),
                  )
                : IconButton(
                    key: const ValueKey('send'),
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF8B83FF)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white, size: 20),
                    ),
                    onPressed: isDisabled ? null : _sendMessage,
                  ),
          ),
        ],
      ),
        ],
      ),
    );
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_rounded, color: Color(0xFF6C63FF)),
              ),
              title: const Text('Photo from Gallery'),
              subtitle: const Text('Pick an image to analyze'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9A6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.camera_alt_rounded, color: Color(0xFF00D9A6)),
              ),
              title: const Text('Take Photo'),
              subtitle: const Text('Use camera to capture'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
