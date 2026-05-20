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
import '../contract/auth_contract.dart';
import '../model/auth_model.dart';

/// Google OAuth client IDs.
const _webClientId =
    '420312855823-qj7f4inghifnlh1lj4rq29nmutm7lgo1.apps.googleusercontent.com';
const _iosClientId =
    '420312855823-f68m5ditqrbom89huf4b9lv7ql11giqm.apps.googleusercontent.com';

class AuthRepository implements AuthContract {
  final SupabaseClient _client;
  bool _googleInitialized = false;

  AuthRepository(this._client);

  // ── Google Sign-In ──────────────────────────────────────────

  /// Initialize Google Sign-In singleton (safe to call multiple times).
  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;

    try {
      final clientId = Platform.isIOS ? _iosClientId : _webClientId;
      await GoogleSignIn.instance.initialize(
        clientId: clientId,
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
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
        );
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
      return getCurrentProfile();
    } on AuthException catch (e) {
      return Failure(AppFailure.auth(message: e.message));
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  // ── Sign Out ────────────────────────────────────────────────

  @override
  Future<Result<void>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Success(null);
    } on AuthException catch (e) {
      return Failure(AppFailure.auth(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  // ── Current Profile ─────────────────────────────────────────

  @override
  Future<Result<UserProfile>> getCurrentProfile() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return Success(UserProfile.fromJson(response));
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Failure(AppFailure.notFound(message: 'Profile not found.'));
      }
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  // ── Auth State ──────────────────────────────────────────────

  @override
  bool get isAuthenticated => _client.auth.currentUser != null;

  @override
  Stream<String?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((data) => data.session?.user.id);
}
