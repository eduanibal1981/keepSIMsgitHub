/// SIM Shield — Auth Repository
///
/// Implements [AuthContract] using Supabase Auth + Google Sign-In.
/// Handles native mobile flow (ID token) and web OAuth flow.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/auth_session_manager.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import '../contract/auth_contract.dart';
import '../model/auth_model.dart';
import 'google_sign_in_failure.dart';

/// Google OAuth client IDs.
const _webClientId =
    '420312855823-qj7f4inghifnlh1lj4rq29nmutm7lgo1.apps.googleusercontent.com';
const _iosClientId =
    '420312855823-f68m5ditqrbom89huf4b9lv7ql11giqm.apps.googleusercontent.com';

class AuthRepository implements AuthContract {
  final SupabaseClient _client;
  final LocalCacheService _cache;
  final ConnectivityService _connectivity;
  bool _googleInitialized = false;

  AuthRepository(this._client, this._cache, this._connectivity);

  // ── Google Sign-In ──────────────────────────────────────────

  /// Initialize Google Sign-In singleton (safe to call multiple times).
  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;

    try {
      await GoogleSignIn.instance.initialize(
        clientId: Platform.isIOS ? _iosClientId : null,
        serverClientId: _webClientId,
      );
      _googleInitialized = true;
    } on StateError catch (e) {
      // Already initialized — safe to continue
      if (e.message.contains('already been called')) {
        _googleInitialized = true;
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<Result<UserProfile>> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: OAuth redirect flow
        await _client.auth.signInWithOAuth(OAuthProvider.google);
        // After redirect, the session is picked up by onAuthStateChange.
        return const Failure(
          AppFailure.auth(message: 'Redirecting to Google...'),
        );
      }

      // Mobile: Native Google Sign-In flow
      await _ensureGoogleInitialized();

      final googleUser = await GoogleSignIn.instance.authenticate();

      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        return const Failure(
          AppFailure.auth(message: 'Failed to obtain ID token from Google.'),
        );
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      if (response.user == null) {
        return const Failure(
          AppFailure.auth(message: 'Sign-in failed. No user returned.'),
        );
      }

      // Fetch the profile created by the DB trigger
      return await getCurrentProfile();
    } on GoogleSignInException catch (e) {
      return Failure(googleSignInFailure(e));
    } on AuthException catch (e) {
      return Failure(AppFailure.auth(message: e.message));
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('canceled') || errStr.contains('sign_in_canceled')) {
        return const Failure(AppFailure.auth(message: 'Sign-in canceled.'));
      }
      return _handleException(e);
    }
  }

  // ── Email/Password Sign-In ───────────────────────────────────

  @override
  Future<Result<UserProfile>> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return const Failure(
          AppFailure.auth(message: 'Sign-in failed. No user returned.'),
        );
      }

      // Fetch the profile created by the DB trigger
      return await getCurrentProfile();
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        return const Failure(
          AppFailure.auth(
            message:
                'Email not confirmed. Please check your inbox and verify your email.',
          ),
        );
      }
      return Failure(AppFailure.auth(message: e.message));
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return _handleException(e);
    }
  }

  @override
  Future<Result<void>> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'io.supabase.keepsims://login-callback/',
      );

      if (response.user == null) {
        return const Failure(
          AppFailure.auth(message: 'Sign-up failed. No user returned.'),
        );
      }

      return const Success(null);
    } on AuthException catch (e) {
      return Failure(AppFailure.auth(message: e.message));
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return _handleException(e);
    }
  }

  @override
  Future<Result<void>> resendConfirmationEmail(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: 'io.supabase.keepsims://login-callback/',
      );
      return const Success(null);
    } on AuthException catch (e) {
      return Failure(AppFailure.auth(message: e.message));
    } catch (e) {
      return _handleException(e);
    }
  }

  @override
  Future<Result<void>> verifyOTP(String email, String token) async {
    try {
      final response = await _client.auth.verifyOTP(
        type: OtpType.signup,
        email: email,
        token: token,
      );
      if (response.session == null && response.user == null) {
        return const Failure(
          AppFailure.auth(message: 'Verification failed. No user returned.'),
        );
      }
      return const Success(null);
    } on AuthException catch (e) {
      return Failure(AppFailure.auth(message: e.message));
    } catch (e) {
      return _handleException(e);
    }
  }

  // ── Sign Out ────────────────────────────────────────────────

  @override
  Future<Result<void>> signOut() async {
    try {
      await _client.auth.signOut();
      await _cache.remove('cached_user_profile');
      await _cache.remove('cached_sim_lines');
      await _cache.remove('cached_countries');
      await _cache.remove('cached_schedules');
      await _cache.remove('cached_wallet');
      await _cache.remove('cached_wallet_transactions');
      return const Success(null);
    } on AuthException catch (e) {
      await _cache.remove('cached_user_profile');
      return Failure(AppFailure.auth(message: e.message));
    } catch (e) {
      await _cache.remove('cached_user_profile');
      return _handleException(e);
    }
  }

  // ── Current Profile ─────────────────────────────────────────

  @override
  Future<Result<UserProfile>> getCurrentProfile() async {
    if (_connectivity.isOffline) {
      final cached = _cache.readJson('cached_user_profile');
      if (cached != null) {
        return Success(UserProfile.fromJson(cached as Map<String, dynamic>));
      }
      return const Failure(
        AppFailure.auth(
          message: 'No internet connection and no cached profile found.',
        ),
      );
    }

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final response = await AuthSessionManager.withAuthRecovery(
        _client,
        () => _client.from('profiles').select().eq('id', userId).single(),
      );

      await _cache.writeJson('cached_user_profile', response);
      return Success(UserProfile.fromJson(response));
    } on PostgrestException catch (e) {
      final cached = _cache.readJson('cached_user_profile');
      if (cached != null) {
        return Success(UserProfile.fromJson(cached as Map<String, dynamic>));
      }

      if (e.code == 'PGRST116') {
        return const Failure(
          AppFailure.notFound(message: 'Profile not found.'),
        );
      }
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      final cached = _cache.readJson('cached_user_profile');
      if (cached != null) {
        return Success(UserProfile.fromJson(cached as Map<String, dynamic>));
      }
      return _handleException(e);
    }
  }

  // ── Auth State ──────────────────────────────────────────────

  @override
  bool get isAuthenticated => _client.auth.currentUser != null;

  @override
  Future<bool> ensureValidSession({bool force = false}) async {
    return AuthSessionManager.ensureFreshSession(_client, force: force);
  }

  @override
  Stream<String?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((data) => data.session?.user.id);

  Failure<T> _handleException<T>(Object e) {
    final errStr = e.toString();
    if (errStr.contains('SocketException') ||
        errStr.contains('Failed host lookup') ||
        errStr.contains('ClientException') ||
        errStr.contains('Network_error') ||
        errStr.contains('connection closed') ||
        errStr.contains('connection failed') ||
        errStr.contains('handshake') ||
        errStr.contains('connection timed out') ||
        errStr.contains('network is unreachable')) {
      return const Failure(AppFailure.network());
    }
    return Failure(AppFailure.unknown(message: errStr));
  }
}
