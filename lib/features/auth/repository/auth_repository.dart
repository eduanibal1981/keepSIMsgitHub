/// SIM Shield — Auth Repository
///
/// Implements [AuthContract] using Supabase Auth and native social sign-in.
/// Handles native mobile flow (ID token) and web OAuth flow.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
  final Future<AuthorizationCredentialAppleID> Function(String)
  _appleCredential;
  final FlutterSecureStorage _appleNameStorage;
  bool _googleInitialized = false;

  AuthRepository(
    this._client,
    this._cache,
    this._connectivity, {
    Future<AuthorizationCredentialAppleID> Function(String)? appleCredential,
    FlutterSecureStorage appleNameStorage = const FlutterSecureStorage(),
  }) : _appleCredential = appleCredential ?? _requestAppleCredential,
       _appleNameStorage = appleNameStorage;

  static Future<AuthorizationCredentialAppleID> _requestAppleCredential(
    String hashedNonce,
  ) => SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: hashedNonce,
  );

  @override
  Future<Result<UserProfile>> signInWithApple() async {
    // Other platforms require a separately configured Services ID/OAuth flow.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return const Failure(
        AppFailure.auth(
          message: 'Apple sign-in is available in the iPhone app.',
        ),
      );
    }

    try {
      final rawNonce = _client.auth.generateRawNonce();
      final credential = await _appleCredential(
        sha256.convert(utf8.encode(rawNonce)).toString(),
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        return const Failure(
          AppFailure.auth(
            message: 'Apple did not return a sign-in token. Please try again.',
          ),
        );
      }

      // Apple sends the name only once. Retain it securely if the token
      // exchange or subsequent profile save fails, and retry on the next login
      // by this same Apple account. Never store the identity token or nonce.
      final nameKey = credential.userIdentifier == null
          ? null
          : 'apple_sign_in_name_${credential.userIdentifier}';
      final givenName = credential.givenName?.trim() ?? '';
      final familyName = credential.familyName?.trim() ?? '';
      Map<String, dynamic>? name;
      if (givenName.isNotEmpty || familyName.isNotEmpty) {
        name = {
          'full_name': [
            givenName,
            familyName,
          ].where((part) => part.isNotEmpty).join(' '),
          if (givenName.isNotEmpty) 'given_name': givenName,
          if (familyName.isNotEmpty) 'family_name': familyName,
        };
        if (nameKey != null) {
          try {
            await _appleNameStorage.write(
              key: nameKey,
              value: jsonEncode(name),
            );
          } catch (_) {
            // A keychain failure must not prevent the normal server save.
          }
        }
      } else if (nameKey != null) {
        try {
          final pending = await _appleNameStorage.read(key: nameKey);
          if (pending != null) {
            name = jsonDecode(pending) as Map<String, dynamic>;
          }
        } catch (_) {
          // Continue signing in if local storage is unavailable.
        }
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      final user = response.user;
      if (user == null || response.session == null) {
        return const Failure(
          AppFailure.auth(message: 'Apple sign-in failed. Please try again.'),
        );
      }

      // A failed profile fetch must never restore another account's cache.
      await _cache.remove('cached_user_profile');

      if (name != null) {
        try {
          await _client.auth.updateUser(UserAttributes(data: name));
          // The insert trigger has already created the profile. Metadata
          // updates do not sync it; fill only an empty name, preserving edits.
          await _client
              .from('profiles')
              .update({'full_name': name['full_name']})
              .eq('id', user.id)
              .or('full_name.is.null,full_name.eq.');
          if (nameKey != null) await _appleNameStorage.delete(key: nameKey);
        } catch (_) {
          // Authentication succeeded. Keep the pending name for a later login;
          // profile/onboarding remains usable during a temporary save failure.
        }
      }
      return await getCurrentProfile();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const Failure(AppFailure.auth(message: 'Sign-in canceled.'));
      }
      return const Failure(
        AppFailure.auth(
          message:
              'Apple sign-in could not be completed. Please try again or sign in with email.',
        ),
      );
    } on SignInWithAppleException {
      return const Failure(
        AppFailure.auth(
          message:
              'Apple sign-in is unavailable on this device. Please sign in with email.',
        ),
      );
    } on AuthException {
      return const Failure(
        AppFailure.auth(
          message:
              'Apple sign-in could not be verified. Please try again or sign in with email.',
        ),
      );
    } catch (_) {
      return const Failure(
        AppFailure.auth(
          message:
              'Unable to sign in with Apple. Check your connection and try again.',
        ),
      );
    }
  }

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
