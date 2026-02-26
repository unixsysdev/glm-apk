import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── User Operations ───

  /// Get user document reference
  DocumentReference _userDoc(String uid) => _firestore.collection('users').doc(uid);

  /// Create initial user document on first sign-in
  Future<void> createUserDocument(User firebaseUser) async {
    final docRef = _userDoc(firebaseUser.uid);
    final doc = await docRef.get();
    if (doc.exists) {
      // Sync profile from Firebase Auth + update lastActive
      await docRef.update({
        'lastActive': FieldValue.serverTimestamp(),
        'displayName': firebaseUser.displayName ?? '',
        'photoUrl': firebaseUser.photoURL,
      });
      // Fix corrupted counter from old migrations
      await fixFreeMessagesIfNeeded(firebaseUser.uid);
      return;
    }

    final user = UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? '',
      photoUrl: firebaseUser.photoURL,
      createdAt: DateTime.now(),
      lastActive: DateTime.now(),
    );
    await docRef.set(user.toFirestore());
  }

  /// Stream user document for real-time updates
  Stream<UserModel?> streamUser(String uid) {
    return _userDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  /// Get user once
  Future<UserModel?> getUser(String uid) async {
    final doc = await _userDoc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Update user preferences (only fields users are allowed to modify)
  Future<void> updateUserPreferences(String uid, Map<String, dynamic> updates) async {
    // Ensure we don't write restricted fields
    updates.remove('freeMessagesRemaining');
    updates.remove('subscriptionTier');
    updates.remove('subscriptionExpiry');
    updates.remove('proMessagesUsedThisMonth');
    await _userDoc(uid).update(updates);
  }

  /// Fix corrupted free message counter (NaN, null, or over 30)
  Future<void> fixFreeMessagesIfNeeded(String uid) async {
    final doc = await _userDoc(uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>?;
      final current = data?['freeMessagesRemaining'];
      final needsReset = current == null ||
          (current is double && (current.isNaN || current.isInfinite)) ||
          (current is num && current > 30);
      if (needsReset) {
        await _userDoc(uid).update({'freeMessagesRemaining': 30});
      }
    }
  }

  /// Update FCM token
  Future<void> updateFcmToken(String uid, String token) async {
    await _userDoc(uid).set({'fcmToken': token}, SetOptions(merge: true));
  }

  // ─── Conversation Operations ───

  CollectionReference _conversationsCol(String uid) =>
      _userDoc(uid).collection('conversations');

  /// Create a new conversation
  Future<ConversationModel> createConversation(String uid, String model) async {
    final docRef = _conversationsCol(uid).doc();
    final conversation = ConversationModel(
      conversationId: docRef.id,
      title: 'New Chat',
      model: model,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await docRef.set(conversation.toFirestore());
    return conversation;
  }

  /// Stream all conversations for a user
  Stream<List<ConversationModel>> streamConversations(String uid) {
    return _conversationsCol(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ConversationModel.fromFirestore(doc)).toList());
  }

  /// Update conversation (title, model, etc.)
  Future<void> updateConversation(
      String uid, String conversationId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _conversationsCol(uid).doc(conversationId).update(updates);
  }

  /// Delete a conversation and all its messages
  Future<void> deleteConversation(String uid, String conversationId) async {
    // Delete all messages first
    final messages = await _messagesCol(uid, conversationId).get();
    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_conversationsCol(uid).doc(conversationId));
    await batch.commit();
  }

  // ─── Message Operations ───

  CollectionReference _messagesCol(String uid, String conversationId) =>
      _conversationsCol(uid).doc(conversationId).collection('messages');

  /// Add a message to a conversation
  Future<void> addMessage(
      String uid, String conversationId, MessageModel message) async {
    await _messagesCol(uid, conversationId)
        .doc(message.messageId)
        .set(message.toFirestore());

    // Update conversation metadata
    final preview = message.content.length > 80
        ? '${message.content.substring(0, 80)}...'
        : message.content;
    await updateConversation(uid, conversationId, {
      'messageCount': FieldValue.increment(1),
      'lastMessagePreview': preview,
    });
  }

  /// Stream messages for a conversation
  Stream<List<MessageModel>> streamMessages(String uid, String conversationId) {
    return _messagesCol(uid, conversationId)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  /// Auto-generate conversation title from first user message
  Future<void> autoGenerateTitle(
      String uid, String conversationId, String firstMessage) async {
    String title = firstMessage.trim();
    if (title.length > 50) {
      title = '${title.substring(0, 47)}...';
    }
    await updateConversation(uid, conversationId, {'title': title});
  }

  /// Toggle conversation favorite
  Future<void> toggleFavorite(String uid, String conversationId, bool isFavorite) async {
    await updateConversation(uid, conversationId, {'isFavorite': isFavorite});
  }

  /// Move conversation to folder
  Future<void> moveToFolder(String uid, String conversationId, String? folder) async {
    await updateConversation(uid, conversationId, {'folder': folder});
  }

  /// Get all messages for a conversation (for export)
  Future<List<MessageModel>> getMessages(String uid, String conversationId) async {
    final snapshot = await _messagesCol(uid, conversationId)
        .orderBy('createdAt')
        .get();
    return snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList();
  }

  /// Get distinct folder names for a user
  Future<List<String>> getFolders(String uid) async {
    final snapshot = await _conversationsCol(uid).get();
    final folders = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      final folder = data?['folder'];
      if (folder != null && folder is String && folder.isNotEmpty) {
        folders.add(folder);
      }
    }
    return folders.toList()..sort();
  }
}
