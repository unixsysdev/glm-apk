import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String conversationId;
  final String title;
  final String model;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;
  final String? lastMessagePreview;
  final String? folder;
  final bool isFavorite;
  final int totalTokens;

  const ConversationModel({
    required this.conversationId,
    required this.title,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
    this.lastMessagePreview,
    this.folder,
    this.isFavorite = false,
    this.totalTokens = 0,
  });

  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConversationModel(
      conversationId: data['conversationId'] ?? doc.id,
      title: data['title'] ?? 'New Chat',
      model: data['model'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      messageCount: data['messageCount'] ?? 0,
      lastMessagePreview: data['lastMessagePreview'],
      folder: data['folder'],
      isFavorite: data['isFavorite'] ?? false,
      totalTokens: data['totalTokens'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'title': title,
      'model': model,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'messageCount': messageCount,
      'lastMessagePreview': lastMessagePreview,
      'folder': folder,
      'isFavorite': isFavorite,
      'totalTokens': totalTokens,
    };
  }

  ConversationModel copyWith({
    String? title,
    String? model,
    DateTime? updatedAt,
    int? messageCount,
    String? lastMessagePreview,
    String? folder,
    bool? isFavorite,
    int? totalTokens,
  }) {
    return ConversationModel(
      conversationId: conversationId,
      title: title ?? this.title,
      model: model ?? this.model,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageCount: messageCount ?? this.messageCount,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      folder: folder ?? this.folder,
      isFavorite: isFavorite ?? this.isFavorite,
      totalTokens: totalTokens ?? this.totalTokens,
    );
  }
}
