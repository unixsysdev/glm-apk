import 'package:cloud_firestore/cloud_firestore.dart';

class Attachment {
  final String type; // "image" | "file"
  final String url;
  final String fileName;
  final String mimeType;

  const Attachment({
    required this.type,
    required this.url,
    required this.fileName,
    required this.mimeType,
  });

  factory Attachment.fromMap(Map<String, dynamic> map) {
    return Attachment(
      type: map['type'] ?? 'file',
      url: map['url'] ?? '',
      fileName: map['fileName'] ?? '',
      mimeType: map['mimeType'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'url': url,
      'fileName': fileName,
      'mimeType': mimeType,
    };
  }
}

class MessageModel {
  final String messageId;
  final String role; // "user" | "assistant" | "system"
  final String content;
  final String? reasoningContent;
  final List<Attachment> attachments;
  final String? model;
  final int? tokenCount;
  final DateTime createdAt;

  const MessageModel({
    required this.messageId,
    required this.role,
    required this.content,
    this.reasoningContent,
    this.attachments = const [],
    this.model,
    this.tokenCount,
    required this.createdAt,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isSystem => role == 'system';
  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasImages => attachments.any((a) => a.type == 'image');
  bool get hasReasoning => reasoningContent != null && reasoningContent!.isNotEmpty;

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      messageId: data['messageId'] ?? doc.id,
      role: data['role'] ?? 'user',
      content: data['content'] ?? '',
      reasoningContent: data['reasoningContent'],
      attachments: (data['attachments'] as List<dynamic>?)
              ?.map((a) => Attachment.fromMap(a as Map<String, dynamic>))
              .toList() ??
          [],
      model: data['model'],
      tokenCount: data['tokenCount'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'messageId': messageId,
      'role': role,
      'content': content,
      'reasoningContent': reasoningContent,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'model': model,
      'tokenCount': tokenCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Convert to OpenAI-compatible format for API calls
  Map<String, dynamic> toApiFormat() {
    if (hasImages) {
      return {
        'role': role,
        'content': [
          {'type': 'text', 'text': content},
          ...attachments
              .where((a) => a.type == 'image')
              .map((a) => {
                    'type': 'image_url',
                    'image_url': {'url': a.url},
                  }),
        ],
      };
    }
    return {
      'role': role,
      'content': content,
    };
  }

  MessageModel copyWith({
    String? content,
    String? reasoningContent,
    List<Attachment>? attachments,
    String? model,
    int? tokenCount,
  }) {
    return MessageModel(
      messageId: messageId,
      role: role,
      content: content ?? this.content,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      attachments: attachments ?? this.attachments,
      model: model ?? this.model,
      tokenCount: tokenCount ?? this.tokenCount,
      createdAt: createdAt,
    );
  }
}
