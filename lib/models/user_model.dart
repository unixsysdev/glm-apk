import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final int freeMessagesRemaining;
  final bool hasOwnApiKey;
  final String subscriptionTier; // "free" | "pro"
  final DateTime? subscriptionExpiry;
  final int proMessagesUsedThisMonth;
  final String preferredModel;
  final String systemPrompt;
  final bool notificationsEnabled;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime lastActive;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.freeMessagesRemaining = 30,
    this.hasOwnApiKey = false,
    this.subscriptionTier = 'free',
    this.subscriptionExpiry,
    this.proMessagesUsedThisMonth = 0,
    this.preferredModel = 'openai/openai/gpt-oss-120b-TEE',
    this.systemPrompt = '',
    this.notificationsEnabled = true,
    this.fcmToken,
    required this.createdAt,
    required this.lastActive,
  });

  bool get isFree => subscriptionTier == 'free' && !hasOwnApiKey;
  bool get isByok => hasOwnApiKey;
  bool get isPro => subscriptionTier == 'pro';
  bool get hasFreeMessages => freeMessagesRemaining > 0;
  bool get hasProMessages => proMessagesUsedThisMonth < 500;

  bool get isProExpired {
    if (!isPro || subscriptionExpiry == null) return false;
    return subscriptionExpiry!.isBefore(DateTime.now());
  }

  String get effectiveTier {
    if (isPro && !isProExpired) return 'pro';
    if (isByok) return 'byok';
    return 'free';
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'],
      freeMessagesRemaining: _safeInt(data['freeMessagesRemaining'], 30),
      hasOwnApiKey: data['hasOwnApiKey'] ?? false,
      subscriptionTier: data['subscriptionTier'] ?? 'free',
      subscriptionExpiry: data['subscriptionExpiry'] != null
          ? (data['subscriptionExpiry'] as Timestamp).toDate()
          : null,
      proMessagesUsedThisMonth: _safeInt(data['proMessagesUsedThisMonth'], 0),
      preferredModel: data['preferredModel'] ?? 'openai/gpt-oss-120b-TEE',
      systemPrompt: data['systemPrompt'] ?? '',
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      fcmToken: data['fcmToken'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastActive: data['lastActive'] != null
          ? (data['lastActive'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'freeMessagesRemaining': freeMessagesRemaining,
      'hasOwnApiKey': hasOwnApiKey,
      'subscriptionTier': subscriptionTier,
      'subscriptionExpiry': subscriptionExpiry != null
          ? Timestamp.fromDate(subscriptionExpiry!)
          : null,
      'proMessagesUsedThisMonth': proMessagesUsedThisMonth,
      'preferredModel': preferredModel,
      'systemPrompt': systemPrompt,
      'notificationsEnabled': notificationsEnabled,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    int? freeMessagesRemaining,
    bool? hasOwnApiKey,
    String? subscriptionTier,
    DateTime? subscriptionExpiry,
    int? proMessagesUsedThisMonth,
    String? preferredModel,
    String? systemPrompt,
    bool? notificationsEnabled,
    String? fcmToken,
    DateTime? createdAt,
    DateTime? lastActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      freeMessagesRemaining: freeMessagesRemaining ?? this.freeMessagesRemaining,
      hasOwnApiKey: hasOwnApiKey ?? this.hasOwnApiKey,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      proMessagesUsedThisMonth: proMessagesUsedThisMonth ?? this.proMessagesUsedThisMonth,
      preferredModel: preferredModel ?? this.preferredModel,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
  static int _safeInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) {
      if (value.isNaN || value.isInfinite) return fallback;
      return value.toInt();
    }
    return fallback;
  }
}
