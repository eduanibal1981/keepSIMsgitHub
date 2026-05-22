/// SIM Shield — Referrals Controller
///
/// Manages state for successful friend invitations and interactive code redemption.
/// Invalidates wallet and auth subsystems on redemption to trigger instant updates.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/dashboard/presentation/controller/dashboard_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import '../model/referral_model.dart';

part 'referrals_controller.g.dart';

/// Aggregated state for the Referrals system.
class ReferralsState {
  final List<Referral> referrals;
  final bool isSubmitting;

  const ReferralsState({required this.referrals, this.isSubmitting = false});

  ReferralsState copyWith({List<Referral>? referrals, bool? isSubmitting}) {
    return ReferralsState(
      referrals: referrals ?? this.referrals,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

@riverpod
class ReferralsController extends _$ReferralsController {
  @override
  FutureOr<ReferralsState> build() async {
    // 1. Reactively watch auth changes to rebuild referrals data
    final authProfile = ref.watch(authControllerProvider);
    final profile = authProfile.valueOrNull;
    if (profile == null) {
      throw Exception('User is not authenticated');
    }

    final repo = ref.watch(referralsRepositoryProvider);

    // 2. Fetch successful referrals ledger
    final result = await repo.getReferrals();

    switch (result) {
      case Success(data: final list):
        return ReferralsState(referrals: list);
      case Failure(error: final f):
        throw Exception(f.message);
    }
  }

  /// Redeems a referral code. Returns error message if fails, null on success.
  Future<String?> applyReferral(String code) async {
    final current = state.valueOrNull;
    if (current == null) return 'Session expired. Please sign in again.';

    // 1. Set loading state
    state = AsyncData(current.copyWith(isSubmitting: true));

    final repo = ref.read(referralsRepositoryProvider);
    final result = await repo.applyReferral(code);

    switch (result) {
      case Success():
        // 2. Invalidate profile, wallet, and dashboard to reflect credits immediately
        ref.invalidate(authControllerProvider);
        ref.invalidate(walletControllerProvider);
        ref.invalidate(dashboardControllerProvider);

        // 3. Force rebuild referrals state in background
        ref.invalidateSelf();
        return null;

      case Failure(error: final f):
        // 4. Restore submitting state
        state = AsyncData(current.copyWith(isSubmitting: false));
        return f.message;
    }
  }
}
