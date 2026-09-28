/// SIM Shield — Auth Controller
///
/// Riverpod AsyncNotifier for authentication state.
/// Initializes by checking current session in build().
library;

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:keep_sims/core/result.dart';
import '../contract/auth_contract.dart';
import '../model/auth_model.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/features/notifications/data/repositories/device_token_repository.dart';

import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'package:keep_sims/core/failure.dart';

part 'auth_controller.g.dart';

/// Provides the current auth state as an [AsyncValue<UserProfile?>].
///
/// - `AsyncData(profile)` → user is signed in
/// - `AsyncData(null)` → user is not signed in
/// - `AsyncLoading` → checking auth state
/// - `AsyncError` → something went wrong
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<UserProfile?> build() async {
    final repo = ref.read(authRepositoryProvider);

    // Listen to auth state changes and invalidate self, skipping the initial
    // event emitted synchronously upon subscribing to prevent infinite loops.
    final sub = repo.authStateChanges.distinct().skip(1).listen((_) {
      ref.invalidateSelf();
    });

    // Clean up the subscription when the provider is disposed
    ref.onDispose(sub.cancel);

    // Check if already authenticated
    if (!repo.isAuthenticated) {
      OneSignal.logout();
      return null;
    }

    // Proactively verify session freshness; if expired, refresh it now.
    // If the session cannot be refreshed (e.g. refresh token revoked or dead),
    // cleanly treat as unauthenticated.
    final hasValidSession = await repo.ensureValidSession();
    if (!hasValidSession && !repo.isAuthenticated) {
      OneSignal.logout();
      return null;
    }

    // Fetch current profile
    final profile = await _fetchProfile(repo);
    if (profile != null) {
      // Register this device's push identifiers for the dispatcher; never block
      // auth on it.
      unawaited(
        ref
            .read(deviceTokenRepositoryProvider)
            .registerCurrentDevice(profile.id),
      );
    }
    return profile;
  }

  /// Resend confirmation email.
  Future<void> resendConfirmationEmail(String email) async {
    state = const AsyncValue.loading();
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.resendConfirmationEmail(email);

    switch (result) {
      case Success(data: final _):
        state = const AsyncValue.data(null);
      case Failure(error: final f):
        state = AsyncValue.error(f.message, StackTrace.current);
    }
  }

  /// Verify OTP for email signup.
  Future<void> verifyOTP(String email, String token) async {
    state = const AsyncValue.loading();
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.verifyOTP(email, token);

    switch (result) {
      case Success(data: final _):
        ref.invalidateSelf(); // Re-fetch the profile and trigger router
      case Failure(error: final f):
        state = AsyncValue.error(f.message, StackTrace.current);
    }
  }

  /// Fetch the current user's profile from the repository.
  Future<UserProfile?> _fetchProfile(AuthContract repo) async {
    final result = await repo.getCurrentProfile();

    return switch (result) {
      Success(data: final profile) => profile,
      Failure(error: final e) => throw UserFriendlyException(e.message),
    };
  }

  /// Sign in with Google.
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();

    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signInWithGoogle();

    switch (result) {
      case Success(data: final _):
        ref.invalidateSelf();
      case Failure(error: final f):
        // Don't set error for OAuth redirect (web flow)
        if (f.message == 'Redirecting to Google...') {
          return;
        }
        final msgLower = f.message.toLowerCase();
        if (msgLower.contains('canceled') || msgLower.contains('sign_in_canceled') || msgLower.contains('account reauth failed')) {
          state = const AsyncValue.data(null);
          return;
        }
        state = AsyncValue.error(f.message, StackTrace.current);
    }
  }

  /// Sign in with Email and Password.
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    state = const AsyncValue.loading();

    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signInWithEmailAndPassword(email, password);

    switch (result) {
      case Success(data: final _):
        ref.invalidateSelf();
      case Failure(error: final f):
        state = AsyncValue.error(f.message, StackTrace.current);
    }
  }

  /// Sign up with Email and Password.
  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    state = const AsyncValue.loading();

    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signUpWithEmailAndPassword(email, password);

    switch (result) {
      case Success(data: final _):
        state = const AsyncValue.data(null);
      case Failure(error: final f):
        state = AsyncValue.error(f.message, StackTrace.current);
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    final userId = state.value?.id;
    if (userId != null) {
      try {
        await ref
            .read(deviceTokenRepositoryProvider)
            .unregisterCurrentDevice(userId);
      } catch (_) {
        // Non-fatal: device unregistration must never block sign out.
      }
    }

    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signOut();

    switch (result) {
      case Success(data: final _):
        OneSignal.logout();
        state = const AsyncValue.data(null);
      case Failure(error: final f):
        state = AsyncValue.error(f.message, StackTrace.current);
    }
  }
}
