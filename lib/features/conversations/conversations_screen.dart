import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/conversation_model.dart';
import '../../services/export_service.dart';
import '../auth/auth_provider.dart';
import '../chat/chat_provider.dart';
import '../chat/chat_screen.dart';
import '../settings/settings_screen.dart';
import 'conversations_provider.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final Set<String> _collapsedFolders = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChat({String? conversationId}) {
    ref.read(activeConversationIdProvider.notifier).state = conversationId;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = ref.watch(conversationSearchProvider).toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search conversations...',
                  border: InputBorder.none,
                  fillColor: Colors.transparent,
                ),
                onChanged: (value) {
                  ref.read(conversationSearchProvider.notifier).state = value;
                },
              )
            : Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF00D9A6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
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
                  const SizedBox(width: 10),
                  const Text('Geepity'),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(conversationSearchProvider.notifier).state = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: conversationsAsync.when(
        data: (allConversations) {
          // Apply search filter
          final conversations = query.isEmpty
              ? allConversations
              : allConversations
                  .where((c) =>
                      c.title.toLowerCase().contains(query) ||
                      (c.lastMessagePreview?.toLowerCase().contains(query) ??
                          false))
                  .toList();

          if (conversations.isEmpty) return _buildEmptyState(context);

          // Group by folder
          final favorites = conversations.where((c) => c.isFavorite).toList();
          final folders = <String, List<ConversationModel>>{};
          for (final c in conversations) {
            final folder = (c.folder != null && c.folder!.isNotEmpty) ? c.folder! : 'General';
            folders.putIfAbsent(folder, () => []);
            folders[folder]!.add(c);
          }

          // Sort folder names: General first, then alphabetical
          final sortedFolderNames = folders.keys.toList()
            ..sort((a, b) {
              if (a == 'General') return -1;
              if (b == 'General') return 1;
              return a.compareTo(b);
            });

          return RefreshIndicator(
            color: const Color(0xFF6C63FF),
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // Favorites section (if any)
                if (favorites.isNotEmpty) ...[
                  _buildFolderHeader(
                    context,
                    icon: Icons.star_rounded,
                    iconColor: const Color(0xFFFFB74D),
                    title: 'Favorites',
                    count: favorites.length,
                    folderKey: '__favorites__',
                  ),
                  if (!_collapsedFolders.contains('__favorites__'))
                    ...favorites.map((c) => _buildConversationTile(context, c, isDark)),
                  const SizedBox(height: 12),
                ],

                // Folder sections
                ...sortedFolderNames.expand((folderName) {
                  final items = folders[folderName]!;
                  final isGeneral = folderName == 'General';
                  return [
                    _buildFolderHeader(
                      context,
                      icon: isGeneral ? Icons.chat_bubble_outline : Icons.folder_outlined,
                      iconColor: isGeneral ? const Color(0xFF6C63FF) : const Color(0xFF00D9A6),
                      title: folderName,
                      count: items.length,
                      folderKey: folderName,
                    ),
                    if (!_collapsedFolders.contains(folderName))
                      ...items.map((c) => _buildConversationTile(context, c, isDark)),
                    const SizedBox(height: 12),
                  ];
                }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildEmptyState(context),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openChat(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildFolderHeader(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required int count,
    required String folderKey,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCollapsed = _collapsedFolders.contains(folderKey);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {
          if (isCollapsed) {
            _collapsedFolders.remove(folderKey);
          } else {
            _collapsedFolders.add(folderKey);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              isCollapsed ? Icons.expand_more : Icons.expand_less,
              size: 18,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: Color(0xFF6C63FF),
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No conversations yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to start your first chat',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(
      BuildContext context, ConversationModel conv, bool isDark) {
    return Dismissible(
      key: Key(conv.conversationId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete conversation?'),
            content: const Text(
                'This will permanently delete this conversation and all its messages.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B6B),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          ref
              .read(firestoreServiceProvider)
              .deleteConversation(uid, conv.conversationId);
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openChat(conversationId: conv.conversationId),
          onLongPress: () => _showConversationMenu(context, conv),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (conv.isFavorite)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB74D)),
                      ),
                    Expanded(
                      child: Text(
                        conv.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(conv.updatedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _shortModelName(conv.model),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        conv.lastMessagePreview ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (conv.totalTokens > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${(conv.totalTokens / 1000).toStringAsFixed(1)}k',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConversationMenu(BuildContext context, ConversationModel conv) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final firestoreService = ref.read(firestoreServiceProvider);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(conv.isFavorite ? Icons.star_outlined : Icons.star_outline,
                  color: const Color(0xFFFFB74D)),
              title: Text(conv.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
              onTap: () {
                firestoreService.toggleFavorite(uid, conv.conversationId, !conv.isFavorite);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined, color: Color(0xFF00D9A6)),
              title: const Text('Move to Folder'),
              onTap: () {
                Navigator.pop(context);
                _showFolderDialog(context, uid, conv);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Color(0xFF6C63FF)),
              title: const Text('Export as Markdown'),
              onTap: () async {
                Navigator.pop(context);
                final messages = await firestoreService.getMessages(uid, conv.conversationId);
                await ExportService.shareAsMarkdown(conv.title, messages);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                firestoreService.deleteConversation(uid, conv.conversationId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFolderDialog(BuildContext context, String uid, ConversationModel conv) {
    final controller = TextEditingController(text: conv.folder ?? '');
    final firestoreService = ref.read(firestoreServiceProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Folder name (empty = General)',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<String>>(
              future: firestoreService.getFolders(uid),
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
                return Wrap(
                  spacing: 6,
                  children: snap.data!.map((f) => ActionChip(
                    label: Text(f, style: const TextStyle(fontSize: 12)),
                    onPressed: () => controller.text = f,
                  )).toList(),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final folder = controller.text.trim();
              firestoreService.moveToFolder(uid, conv.conversationId, folder.isEmpty ? null : folder);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 2) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  String _shortModelName(String model) {
    final chutesMatch = ApiConstants.chutesModels.where((m) => m.modelId == model);
    if (chutesMatch.isNotEmpty) return chutesMatch.first.displayName;
    final proMatch = ApiConstants.proModels.where((m) => m.modelId == model);
    if (proMatch.isNotEmpty) return proMatch.first.displayName;
    switch (model) {
      case 'glm-5':
        return 'GLM-5';
      case 'glm-4.7':
        return 'GLM-4.7';
      case 'glm-4.7-flash':
        return 'Flash';
      default:
        return model.split('/').last;
    }
  }
}
