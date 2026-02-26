import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../auth/auth_provider.dart';

// ─── Service providers ───

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// ─── Active conversation ID ───

final activeConversationIdProvider = StateProvider<String?>((ref) => null);

// ─── Messages stream for active conversation ───

final messagesProvider = StreamProvider<List<MessageModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final conversationId = ref.watch(activeConversationIdProvider);
  if (uid == null || conversationId == null) return Stream.value([]);
  return ref.read(firestoreServiceProvider).streamMessages(uid, conversationId);
});

// ─── Model selector ───

final selectedModelProvider = StateProvider<String>((ref) {
  // Use ref.read so this only sets the INITIAL value, not re-evaluate on every user update
  final user = ref.read(userProvider).value;
  if (user == null) return ApiConstants.defaultChutesModel;
  switch (user.effectiveTier) {
    case 'free':
      return ApiConstants.defaultChutesModel;
    case 'byok':
    case 'pro':
      return user.preferredModel.startsWith('openai')
          ? 'glm-4.7-flash'
          : user.preferredModel;
    default:
      return ApiConstants.defaultChutesModel;
  }
});

// ─── Chat state ───

final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});

class ChatState {
  final bool isStreaming;
  final String streamingText;
  final String streamingReasoning;
  final String? error;

  const ChatState({
    this.isStreaming = false,
    this.streamingText = '',
    this.streamingReasoning = '',
    this.error,
  });

  ChatState copyWith({bool? isStreaming, String? streamingText, String? streamingReasoning, String? error}) {
    return ChatState(
      isStreaming: isStreaming ?? this.isStreaming,
      streamingText: streamingText ?? this.streamingText,
      streamingReasoning: streamingReasoning ?? this.streamingReasoning,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  final Uuid _uuid = const Uuid();
  StreamSubscription<String>? _streamSubscription;

  ChatNotifier(this._ref) : super(const ChatState());

  Future<void> sendMessage(String content, {List<Attachment>? attachments}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('SEND: No UID, aborting');
      return;
    }

    final firestoreService = _ref.read(firestoreServiceProvider);
    final apiService = _ref.read(apiServiceProvider);
    final user = _ref.read(userProvider).valueOrNull;
    if (user == null) {
      debugPrint('SEND: No user loaded, aborting');
      return;
    }
    debugPrint('SEND: User tier=${user.effectiveTier}, hasOwnApiKey=${user.hasOwnApiKey}');

    // Get or create conversation
    var conversationId = _ref.read(activeConversationIdProvider);
    final model = _ref.read(selectedModelProvider);
    debugPrint('SEND: model=$model, conversationId=$conversationId');

    if (conversationId == null) {
      final conversation = await firestoreService.createConversation(uid, model);
      conversationId = conversation.conversationId;
      _ref.read(activeConversationIdProvider.notifier).state = conversationId;
      // Auto-generate title from first message
      await firestoreService.autoGenerateTitle(uid, conversationId, content);
    }

    // Save user message
    final userMessage = MessageModel(
      messageId: _uuid.v4(),
      role: 'user',
      content: content,
      attachments: attachments ?? [],
      model: model,
      createdAt: DateTime.now(),
    );
    await firestoreService.addMessage(uid, conversationId, userMessage);

    // Start streaming response
    state = state.copyWith(isStreaming: true, streamingText: '', error: null);

    try {
      // Determine tier — route Chutes models through free tier even for BYOK users
      final isChutesModel = ApiConstants.chutesModels.any((m) => m.modelId == model);
      final tier = isChutesModel ? UserTier.free : _getTier(user);
      debugPrint('SEND: tier=$tier, isChutesModel=$isChutesModel');

      // Get all messages for context
      final allMessages =
          await firestoreService.streamMessages(uid, conversationId).first;
      
      // Prepend system prompt if user has one set
      final messagesForApi = <MessageModel>[
        if (user.systemPrompt.isNotEmpty)
          MessageModel(
            messageId: 'system',
            role: 'system',
            content: user.systemPrompt,
            createdAt: DateTime.now(),
          ),
        ...allMessages,
      ];
      debugPrint('SEND: ${messagesForApi.length} messages for context (incl. system prompt)');

      final idToken = (tier != UserTier.byok)
          ? await _ref.read(authNotifierProvider.notifier).getIdToken()
          : null;

      final cloudFunctionsUrl = 'https://us-central1-geepity-abf95.cloudfunctions.net';
      final selectedEndpointName = _ref.read(zaiEndpointProvider);
      final zaiEndpointUrl = ApiConstants.zaiEndpoints[selectedEndpointName]
          ?? ApiConstants.zaiEndpoints[ApiConstants.defaultZaiEndpoint]!;
      debugPrint('SEND: calling API, tier=$tier, model=$model, endpoint=$selectedEndpointName');

      final stream = apiService.sendMessage(
        messages: messagesForApi,
        tier: tier,
        model: model,
        cloudFunctionsUrl: cloudFunctionsUrl,
        idToken: idToken,
        zaiEndpointUrl: zaiEndpointUrl,
      );

      final contentBuffer = StringBuffer();
      final reasoningBuffer = StringBuffer();

      _streamSubscription = stream.listen(
        (token) {
          if (token.startsWith('<<REASONING>>')) {
            reasoningBuffer.write(token.substring(13));
            state = state.copyWith(streamingReasoning: reasoningBuffer.toString());
          } else {
            contentBuffer.write(token);
            state = state.copyWith(streamingText: contentBuffer.toString());
          }
        },
        onDone: () async {
          // Save assistant message with reasoning
          final assistantMessage = MessageModel(
            messageId: _uuid.v4(),
            role: 'assistant',
            content: contentBuffer.toString(),
            reasoningContent: reasoningBuffer.isNotEmpty ? reasoningBuffer.toString() : null,
            model: model,
            createdAt: DateTime.now(),
          );
          await firestoreService.addMessage(uid, conversationId!, assistantMessage);
          state = state.copyWith(isStreaming: false, streamingText: '', streamingReasoning: '');
        },
        onError: (error) {
          debugPrint('Stream error: $error');
          state = state.copyWith(
            isStreaming: false,
            error: error.toString(),
          );
        },
      );
    } catch (e, stack) {
      debugPrint('Chat send error: $e');
      debugPrint('Stack: $stack');
      state = state.copyWith(
        isStreaming: false,
        error: 'Could not reach the server. Please try again.',
      );
    }
  }

  void stopStreaming() {
    _streamSubscription?.cancel();
    state = state.copyWith(isStreaming: false);
  }

  UserTier _getTier(UserModel user) {
    switch (user.effectiveTier) {
      case 'pro':
        return UserTier.pro;
      case 'byok':
        return UserTier.byok;
      default:
        return UserTier.free;
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
