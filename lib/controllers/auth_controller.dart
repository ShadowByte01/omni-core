import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../providers/providers.dart';

/// Authentication state for OmniCore.
@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.localOnly,
    this.user,
    this.error,
  });

  final AuthStatus status;
  final OmniUser? user;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLocalOnly => status == AuthStatus.localOnly;

  AuthState copyWith({
    AuthStatus? status,
    OmniUser? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

enum AuthStatus { localOnly, unauthenticated, authenticating, authenticated, error }

@immutable
class OmniUser {
  const OmniUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
}

/// Riverpod controller handling **optional** Google Sign-In via Supabase.
///
/// Auth is strictly optional. If Supabase is not configured, or if the session
/// is `null`, the app boots in [AuthStatus.localOnly] mode and relies purely
/// on the local Drift database — it never prompts for login.
final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  StreamSubscription? _sub;

  @override
  AuthState build() {
    final configured = ref.read(isSupabaseConfiguredProvider);
    if (!configured) {
      // Pure offline / local-only mode. Never prompts.
      return const AuthState(status: AuthStatus.localOnly);
    }

    // Subscribe to Supabase auth state changes (fires after build()).
    final client = _client();
    _sub = client.auth.onAuthStateChange.listen((event) {
      _applySession(event.session);
    });

    ref.onDispose(() => _sub?.cancel());
    // Return the initial state derived from the current session without
    // touching `state` (which isn't initialised inside build()).
    return _stateFromSession(client.auth.currentSession);
  }

  SupabaseClient _client() => Supabase.instance.client;

  AuthState _stateFromSession(Session? session) {
    if (session == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
    final u = session.user;
    final meta = u.userMetadata;
    return AuthState(
      status: AuthStatus.authenticated,
      user: OmniUser(
        id: u.id,
        email: u.email ?? '',
        displayName: meta?['full_name'] as String? ?? u.email ?? 'You',
        photoUrl: meta?['avatar_url'] as String?,
      ),
    );
  }

  /// Called from the auth-state stream (after build()) to keep [state] in sync.
  void _applySession(Session? session) {
    state = _stateFromSession(session);
  }

  /// Begins the optional Google OAuth flow via Supabase.
  Future<void> signInWithGoogle() async {
    final configured = ref.read(isSupabaseConfiguredProvider);
    if (!configured) {
      state = const AuthState(
        status: AuthStatus.error,
        error: 'Cloud sync is not configured. The app stays offline.',
      );
      return;
    }

    state = const AuthState(status: AuthStatus.authenticating);
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: _serverClientId(),
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      if (idToken == null) {
        state = const AuthState(
          status: AuthStatus.error,
          error: 'Could not obtain Google ID token.',
        );
        return;
      }

      final client = _client();
      await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      // onAuthStateChange will update the state.
    } on AuthException catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.message);
    } on Exception catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  /// Signs out of both Supabase and Google. Returns to local-only operation.
  Future<void> signOut() async {
    final configured = ref.read(isSupabaseConfiguredProvider);
    try {
      if (configured) {
        await _client().auth.signOut();
      }
      await GoogleSignIn().signOut();
    } on Exception {
      // Swallow — we always want to return to a local-only state.
    }
    state = AuthState(
      status: configured
          ? AuthStatus.unauthenticated
          : AuthStatus.localOnly,
    );
  }

  String? _serverClientId() {
    // The Google OAuth web client ID used by Supabase. Provide via
    // --dart-define=GOOGLE_SERVER_CLIENT_ID=...
    return const String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue: '',
    ).isEmpty
        ? null
        : const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  }
}
