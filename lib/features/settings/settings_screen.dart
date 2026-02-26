import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../auth/auth_provider.dart';
import '../chat/chat_provider.dart';
import 'api_key_setup_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _maskedKey;

  @override
  void initState() {
    super.initState();
    _loadMaskedKey();
  }

  Future<void> _loadMaskedKey() async {
    final key = await ref.read(apiServiceProvider).getMaskedApiKey();
    if (mounted) setState(() => _maskedKey = key);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading settings')),
        data: (user) {
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ─── Account Section ───
                _sectionHeader(context, 'Account'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: user.photoUrl != null
                              ? NetworkImage(user.photoUrl!)
                              : null,
                          backgroundColor: const Color(0xFF6C63FF),
                          child: user.photoUrl == null
                              ? Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName
                                    : FirebaseAuth.instance.currentUser?.displayName ?? 'User',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.email,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        _tierBadge(user.effectiveTier),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ─── API Key Section (visible if BYOK) ───
                if (user.hasOwnApiKey) ...[
                  _sectionHeader(context, 'API Key'),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.key_rounded,
                              color: Color(0xFF6C63FF)),
                          title: Text(_maskedKey ?? '••••••••'),
                          subtitle: const Text('Z.ai API Key'),
                        ),
                        const Divider(height: 1),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ApiKeySetupScreen()),
                                  );
                                },
                                child: const Text('Update Key'),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFE0E0EC),
                            ),
                            Expanded(
                              child: TextButton(
                                onPressed: () => _removeApiKey(),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFFF6B6B),
                                ),
                                child: const Text('Remove Key'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.language_rounded,
                          color: Color(0xFF6C63FF)),
                      title: const Text('API Endpoint'),
                      subtitle: Text(
                        ref.watch(zaiEndpointProvider),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (endpoint) {
                          ref.read(zaiEndpointProvider.notifier).state = endpoint;
                        },
                        itemBuilder: (context) => ApiConstants.zaiEndpoints.keys
                            .map((name) => PopupMenuItem(
                                  value: name,
                                  child: Row(
                                    children: [
                                      if (name == ref.read(zaiEndpointProvider))
                                        const Icon(Icons.check, size: 16, color: Color(0xFF6C63FF))
                                      else
                                        const SizedBox(width: 16),
                                      const SizedBox(width: 8),
                                      Text(name, style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ))
                            .toList(),
                        child: const Icon(Icons.arrow_drop_down),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Go Pro option for BYOK users
                  if (!user.isPro)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.star_rounded, color: Color(0xFFFFB74D)),
                        title: const Text('Upgrade to Geepity Pro'),
                        subtitle: const Text('Gemini, Claude, GPT-4.1 + more'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ApiKeySetupScreen()),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                ],

                // ─── Subscription Section (visible if Pro) ───
                if (user.isPro) ...[
                  _sectionHeader(context, 'Subscription'),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.star_rounded,
                              color: Color(0xFFFFB74D)),
                          title: const Text('Geepity Pro'),
                          subtitle: user.subscriptionExpiry != null
                              ? Text(
                                  'Renews ${_formatDate(user.subscriptionExpiry!)}')
                              : null,
                        ),
                        ListTile(
                          leading: const Icon(Icons.bar_chart_rounded,
                              color: Color(0xFF00D9A6)),
                          title: Text(
                              '${user.proMessagesUsedThisMonth} / 500 messages'),
                          subtitle: const Text('This month'),
                          trailing: SizedBox(
                            width: 60,
                            child: LinearProgressIndicator(
                              value: user.proMessagesUsedThisMonth / 500,
                              backgroundColor:
                                  const Color(0xFF6C63FF).withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation(
                                user.proMessagesUsedThisMonth > 450
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xFF6C63FF),
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Manage Subscription'),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () {
                            launchUrl(
                              Uri.parse(
                                  'https://play.google.com/store/account/subscriptions'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ─── Upgrade (for free users without key) ───
                if (user.isFree && !user.hasOwnApiKey) ...[
                  _sectionHeader(context, 'Upgrade'),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF00D9A6)),
                      title: Text('${user.freeMessagesRemaining} / 30 free messages today'),
                      subtitle: const Text('30 messages/day with open-source models'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF00D9A6)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.rocket_launch_rounded,
                            color: Colors.white, size: 20),
                      ),
                      title: const Text('Add API Key or Go Pro'),
                      subtitle: const Text('Unlock more models and features'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ApiKeySetupScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ─── Preferences ───
                _sectionHeader(context, 'Preferences'),
                Card(
                  child: Column(
                    children: [
                      // Default model
                      if (!user.isFree)
                        ListTile(
                          leading: const Icon(Icons.auto_awesome,
                              color: Color(0xFF6C63FF)),
                          title: const Text('Default Model'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (model) {
                              ref
                                  .read(firestoreServiceProvider)
                                  .updateUserPreferences(
                                      user.uid, {'preferredModel': model});
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  user.preferredModel.startsWith('openai')
                                      ? 'glm-4.7-flash'
                                      : user.preferredModel,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                            itemBuilder: (context) => ApiConstants.zaiModels
                                .map((m) => PopupMenuItem(
                                      value: m,
                                      child: Text(m, style: const TextStyle(fontSize: 14)),
                                    ))
                                .toList(),
                          ),
                        ),

                      // Notifications
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_outlined),
                        title: const Text('Notifications'),
                        subtitle: const Text('Usage alerts & updates'),
                        value: user.notificationsEnabled,
                        activeColor: const Color(0xFF6C63FF),
                        onChanged: (value) {
                          ref
                              .read(firestoreServiceProvider)
                              .updateUserPreferences(
                                  user.uid, {'notificationsEnabled': value});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── System Prompt / Persona ───
                _sectionHeader(context, 'Custom Persona'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System prompt sent with every message. Define how the AI should behave.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: TextEditingController(text: user.systemPrompt),
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'e.g. "You are a senior Flutter developer..."',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.all(10),
                          ),
                          onChanged: (value) {
                            // Debounce - save after user stops typing
                            Future.delayed(const Duration(milliseconds: 800), () {
                              ref.read(firestoreServiceProvider)
                                  .updateUserPreferences(user.uid, {'systemPrompt': value});
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.lightbulb_outline, size: 14, color: Color(0xFFFFB74D)),
                            const SizedBox(width: 4),
                            Text(
                              'Tip: Use personas for coding, writing, or tutoring',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Info ───
                _sectionHeader(context, 'Info'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('About Geepity'),
                        onTap: () => _showAbout(context),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy'),
                        trailing: const Icon(Icons.open_in_new, size: 16),
                        onTap: () => launchUrl(
                          Uri.parse(AppStrings.privacyPolicyUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('Terms of Service'),
                        trailing: const Icon(Icons.open_in_new, size: 16),
                        onTap: () => launchUrl(
                          Uri.parse(AppStrings.termsUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Sign Out ───
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(authNotifierProvider.notifier).signOut();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6B6B),
                      side: const BorderSide(color: Color(0xFFFF6B6B)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            );
        },
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6C63FF),
            ),
      ),
    );
  }

  Widget _tierBadge(String tier) {
    final Color color;
    final String label;
    switch (tier) {
      case 'pro':
        color = const Color(0xFFFFB74D);
        label = 'PRO';
        break;
      case 'byok':
        color = const Color(0xFF00D9A6);
        label = 'BYOK';
        break;
      default:
        color = const Color(0xFF8A8BAA);
        label = 'FREE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _removeApiKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove API Key?'),
        content: const Text(
            'This will remove your saved Z.ai API key. You\'ll revert to free mode or can add a new key later.'),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(apiServiceProvider).deleteApiKey();
      final uid = ref.read(firebaseAuthProvider).value?.uid;
      if (uid != null) {
        await ref
            .read(firestoreServiceProvider)
            .updateUserPreferences(uid, {'hasOwnApiKey': false});
      }
      setState(() => _maskedKey = null);
    }
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Geepity',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF00D9A6)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'G',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      children: [
        const Text(
          'Your AI assistant — free to start.\n\n'
          'Powered by open-source models & OpenRouter.',
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFFB74D)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
