import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth/auth_provider.dart';
import '../chat/chat_provider.dart';

class ApiKeySetupScreen extends ConsumerStatefulWidget {
  const ApiKeySetupScreen({super.key});

  @override
  ConsumerState<ApiKeySetupScreen> createState() => _ApiKeySetupScreenState();
}

class _ApiKeySetupScreenState extends ConsumerState<ApiKeySetupScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isValidating = false;
  bool _isObscured = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _testKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'Please enter your API key');
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final apiService = ref.read(apiServiceProvider);
    final isValid = await apiService.validateZaiKey(key);

    if (isValid) {
      await apiService.saveApiKey(key);
      // Update Firestore
      final uid = ref.read(firebaseAuthProvider).value?.uid;
      if (uid != null) {
        await ref
            .read(firestoreServiceProvider)
            .updateUserPreferences(uid, {'hasOwnApiKey': true});
      }
      setState(() {
        _successMessage = 'API key validated and saved!';
        _isValidating = false;
      });
      if (mounted) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      }
    } else {
      setState(() {
        _errorMessage = 'Invalid API key. Please check and try again.';
        _isValidating = false;
      });
    }
  }

  void _openReferralLink() async {
    final referralLink =
        dotenv.env['ZAI_REFERRAL_LINK'] ?? 'https://z.ai/subscribe';
    final uri = Uri.parse(referralLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(userProvider);
    final freeRemaining = userAsync.whenOrNull(data: (u) => u?.freeMessagesRemaining) ?? 0;
    final isUsedUp = freeRemaining <= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Started'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — dynamic based on message count
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF).withOpacity(0.15),
                    const Color(0xFF00D9A6).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isUsedUp ? Icons.chat_bubble_outline : Icons.rocket_launch_rounded,
                    color: const Color(0xFF6C63FF),
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isUsedUp
                        ? 'Your free messages are used up'
                        : 'Upgrade Your Experience',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isUsedUp
                        ? 'Choose how you\'d like to continue chatting'
                        : 'Unlock premium models and unlimited messaging',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ─── Path A: BYOK ───
            Text(
              'Option 1: Bring Your Own Key',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1B2E),
                  ),
            ),
            const SizedBox(height: 12),

            // API key input
            TextField(
              controller: _keyController,
              obscureText: _isObscured,
              decoration: InputDecoration(
                hintText: 'Paste your Z.ai API key',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isObscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _isObscured = !_isObscured),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Error / Success messages
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFFF6B6B), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Color(0xFFFF6B6B), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            if (_successMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Color(0xFF4CAF50), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(
                            color: Color(0xFF4CAF50), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Test key button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isValidating ? null : _testKey,
                child: _isValidating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Test & Save Key'),
              ),
            ),
            const SizedBox(height: 12),

            // Referral link
            Center(
              child: TextButton.icon(
                onPressed: _openReferralLink,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Get a Z.ai API key'),
              ),
            ),
            Text(
              'New to Z.ai? Get 10% off your first GLM Coding Plan',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // ─── Path B: Pro subscription ───
            Text(
              'Option 2: Subscribe to Geepity Pro',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1B2E),
                  ),
            ),
            const SizedBox(height: 12),

            // Pro features card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFB74D).withOpacity(0.1),
                    const Color(0xFFFF8A65).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFB74D).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _proFeature(Icons.all_inclusive, '500 messages per month'),
                  const SizedBox(height: 10),
                  _proFeature(Icons.auto_awesome, 'Gemini 3.1 Pro, Claude Sonnet 4.6, Opus 4.6, GPT-5.3 Codex'),
                  const SizedBox(height: 10),
                  _proFeature(Icons.sync, 'Conversation sync across devices'),
                  const SizedBox(height: 10),
                  _proFeature(Icons.image_rounded, 'Image generation models'),
                  const SizedBox(height: 10),
                  _proFeature(Icons.chat_rounded, 'All free open-source models included'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '\$4.99/mo',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1B2E),
                              ),
                            ),
                            Text(
                              'Monthly',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: isDark ? Colors.white12 : const Color(0xFFE0E0EC),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '\$39.99/yr',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1B2E),
                              ),
                            ),
                            Text(
                              'Save 33%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF00D9A6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Powered by OpenRouter',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // TODO: Open RevenueCat paywall
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Subscription coming soon! Use BYOK for now.')),
                  );
                },
                child: const Text('Subscribe to Pro'),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            // ─── Agent Ultra teaser ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF).withOpacity(0.08),
                    const Color(0xFF00D9A6).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF00D9A6)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Agent Ultra',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D9A6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Coming Soon',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF00D9A6))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Agentic remote tasks — let the AI do the work for you. '
                    'Includes all Pro features plus autonomous agent capabilities.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _proFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFFFB74D)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}
