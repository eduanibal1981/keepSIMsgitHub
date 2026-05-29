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

import 'package:onesignal_flutter/onesignal_flutter.dart';

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

    // Fetch current profile
    final profile = await _fetchProfile(repo);
    if (profile != null) {
      OneSignal.login(profile.id);
    }
    return profile;
  }

  /// Fetch the current user's profile from the repository.
  Future<UserProfile?> _fetchProfile(AuthContract repo) async {
    final result = await repo.getCurrentProfile();

    return switch (result) {
      Success(data: final profile) => profile,
      Failure(error: final e) => throw Exception(e.message),
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
        state = AsyncValue.error(f.message, StackTrace.current);
    }
  }

  /// Sign out.
  Future<void> signOut() async {
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
