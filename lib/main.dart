import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/conversations/conversations_screen.dart';
import 'features/settings/api_key_setup_screen.dart';
import 'models/user_model.dart';
import 'services/firestore_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

FirebaseOptions get _firebaseOptions => FirebaseOptions(
  apiKey: dotenv.env['FIREBASE_API_KEY']!,
  appId: dotenv.env['FIREBASE_APP_ID']!,
  messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
  projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
  storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET']!,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: _firebaseOptions);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment
  await dotenv.load(fileName: '.env');

  // Initialize Firebase
  await Firebase.initializeApp(options: _firebaseOptions);

  // Set up background messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Lock orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const ProviderScope(child: GeepityApp()));
}

class GeepityApp extends ConsumerWidget {
  const GeepityApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Geepity',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  Future<void> _setupFCM() async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            FirestoreService().updateFcmToken(user.uid, token);
          } catch (_) {}
        }
      }

      messaging.onTokenRefresh.listen((newToken) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            FirestoreService().updateFcmToken(user.uid, newToken);
          } catch (_) {}
        }
      });

      FirebaseMessaging.onMessage.listen((message) {
        if (message.notification != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message.notification!.body ?? ''),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('FCM setup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(firebaseAuthProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const SignInScreen();
        }
        // Try to load user data, but don't crash if Firestore denies
        return ref.watch(userProvider).when(
          data: (UserModel? userData) {
            if (userData != null &&
                userData.isFree &&
                !userData.hasFreeMessages) {
              return const ApiKeySetupScreen();
            }
            return const ConversationsScreen();
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) {
            debugPrint('User provider error: $e');
            return const ConversationsScreen();
          },
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF6C63FF),
              ),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      ),
      error: (e, _) {
        debugPrint('Auth error: $e');
        return const SignInScreen();
      },
    );
  }
}
