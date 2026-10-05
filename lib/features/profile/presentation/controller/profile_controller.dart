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
import 'package:keep_sims/features/profile/domain/models/notification_email_status.dart';

part 'profile_controller.g.dart';

@riverpod
Future<NotificationEmailStatus> profileNotificationEmailStatus(Ref ref) async {
  final id = ref.watch(authControllerProvider).value?.id;
  if (id == null) return const NotificationEmailStatus();
  final result = await ref
      .watch(profileRepositoryProvider)
      .getNotificationEmailStatus();
  return switch (result) {
    Success(data: final status) => status,
    Failure(error: final error) => throw UserFriendlyException(error.message),
  };
}

@riverpod
class ProfileController extends _$ProfileController {
  @override
  FutureOr<void> build() async {
    // Nothing to initialize, just an action controller
  }

  Future<Result<UserProfile>> updateDetails({
    required String fullName,
    required String homeCountryCode,
  }) async {
    final name = fullName.trim();
    final country = homeCountryCode.trim().toUpperCase();
    if (name.isEmpty ||
        name.length > 100 ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      return const Failure(
        AppFailure.validation(
          message: 'Enter your name and select your home country.',
        ),
      );
    }
    final profile = ref.read(authControllerProvider).value;
    if (profile == null) return const Failure(AppFailure.auth());
    state = const AsyncLoading();
    final result = await ref
        .read(profileRepositoryProvider)
        .updateProfileDetails(
          profile.copyWith(fullName: name, homeCountryCode: country),
        );
    if (!ref.mounted) return result;
    switch (result) {
      case Success():
        state = const AsyncData(null);
        ref.invalidate(authControllerProvider);
      case Failure(error: final error):
        state = AsyncError(error.message, StackTrace.current);
    }
    return result;
  }

  /// Complete the onboarding flow.
  /// Updates name, country, currency, and completes onboarding in a single transaction.
  Future<Result<UserProfile>> completeOnboarding({
    required String fullName,
    required String homeCountryCode,
    required String preferredCurrency,
    required bool isPowerUser,
    String? subscriptionTier,
  }) async {
    state = const AsyncValue.loading();

    final profileState = ref.read(authControllerProvider);
    final profile = profileState.value;

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
      subscriptionTier:
          subscriptionTier ?? (isPowerUser ? 'premium' : 'standard'),
      onboardingCompleted: true,
      updatedAt: DateTime.now(),
    );

    final repo = ref.read(profileRepositoryProvider);
    final result = await repo.updateProfile(updatedProfile);

    switch (result) {
      case Success(data: final updated):
        // No longer syncing global tier to SIM lines, as tiers are line-specific

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
