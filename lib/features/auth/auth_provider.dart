import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

// ─── Service providers ───

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// ─── Firebase Auth stream ───

final firebaseAuthProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ─── User model stream (Firestore) ───

final userProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(firebaseAuthProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.read(firestoreServiceProvider).streamUser(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// ─── Auth notifier ───

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({this.status = AuthStatus.initial, this.errorMessage});

  AuthState copyWith({AuthStatus? status, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthNotifier(this._ref) : super(const AuthState()) {
    // Listen to Firebase Auth state
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        state = state.copyWith(status: AuthStatus.authenticated);
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    });
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Create user document in Firestore
      if (userCredential.user != null) {
        await _ref
            .read(firestoreServiceProvider)
            .createUserDocument(userCredential.user!);
      }

      state = state.copyWith(status: AuthStatus.authenticated);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message ?? 'Authentication failed',
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Sign-in failed: ${e.toString()}',
      );
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  /// Get current Firebase ID token for Cloud Function auth
  Future<String?> getIdToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }
}

// ─── Theme mode provider ───

final themeModeProvider = StateProvider<bool>((ref) => true); // true = dark

// ─── Z.ai endpoint provider ───

final zaiEndpointProvider = StateProvider<String>((ref) => ApiConstants.defaultZaiEndpoint);
