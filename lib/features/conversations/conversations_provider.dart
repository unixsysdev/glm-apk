import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/conversation_model.dart';
import '../auth/auth_provider.dart';

// ─── Conversations stream ───

final conversationsProvider = StreamProvider<List<ConversationModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return ref.read(firestoreServiceProvider).streamConversations(uid);
});

// ─── Search query ───

final conversationSearchProvider = StateProvider<String>((ref) => '');

// ─── Filtered conversations ───

final filteredConversationsProvider = Provider<List<ConversationModel>>((ref) {
  final conversations = ref.watch(conversationsProvider).value ?? [];
  final query = ref.watch(conversationSearchProvider).toLowerCase();
  if (query.isEmpty) return conversations;
  return conversations
      .where((c) =>
          c.title.toLowerCase().contains(query) ||
          (c.lastMessagePreview?.toLowerCase().contains(query) ?? false))
      .toList();
});
