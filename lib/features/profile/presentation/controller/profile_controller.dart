/// SIM Shield — Profile Controller
///
/// Riverpod AsyncNotifier for managing the profile and onboarding updates.
library;

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';

part 'profile_controller.g.dart';

@riverpod
class ProfileController extends _$ProfileController {
  @override
  FutureOr<void> build() async {
    // Nothing to initialize, just an action controller
  }

  /// Complete the onboarding flow.
  /// Updates name, country, currency, and completes onboarding in a single transaction.
  Future<Result<UserProfile>> completeOnboarding({
    required String fullName,
    required String homeCountryCode,
    required String preferredCurrency,
    required bool isPowerUser,
    required String subscriptionTier,
  }) async {
    state = const AsyncValue.loading();

    final profileState = ref.read(authControllerProvider);
    final profile = profileState.valueOrNull;

    if (profile == null) {
      state = AsyncValue.error('User session not found.', StackTrace.current);
      return const Failure<UserProfile>(
        AppFailure.auth(message: 'User session not found.'),
      );
    }

    final updatedProfile = profile.copyWith(
      fullName: fullName,
      homeCountryCode: homeCountryCode,
      preferredCurrency: preferredCurrency,
      isPowerUser: isPowerUser,
      subscriptionTier: subscriptionTier,
      onboardingCompleted: true,
      updatedAt: DateTime.now(),
    );

    final repo = ref.read(profileRepositoryProvider);
    final result = await repo.updateProfile(updatedProfile);

    switch (result) {
      case Success(data: final updated):
        state = const AsyncValue.data(null);
        // Invalidate auth state to reload the profile across the entire app
        ref.invalidate(authControllerProvider);
        return Success(updated);
      case Failure(error: final e):
        state = AsyncValue.error(e.message, StackTrace.current);
        return Failure(e);
    }
  }
}
