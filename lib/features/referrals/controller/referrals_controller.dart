/// KeepSIMs — Referrals Controller
///
/// Manages state for Refer & Earn points, friend invitations, and point redemptions.
/// Invalidates wallet, auth, and dashboard controllers on redemption for instant UI updates.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/dashboard/presentation/controller/dashboard_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import '../model/referral_model.dart';

part 'referrals_controller.g.dart';

@riverpod
class ReferralsController extends _$ReferralsController {
  @override
  FutureOr<ReferralSummary> build() async {
    final authProfile = ref.watch(authControllerProvider);
    final profile = authProfile.value;
    if (profile == null) {
      throw Exception('User is not authenticated');
    }

    final repo = ref.watch(referralsRepositoryProvider);
    final result = await repo.getSummary();

    switch (result) {
      case Success(data: final summary):
        return summary;
      case Failure(error: final f):
        throw Exception(f.message);
    }
  }

  /// Applies a referral code for the current user. Returns error message if failed, null on success.
  Future<String?> applyReferral(String code) async {
    final repo = ref.read(referralsRepositoryProvider);
    final result = await repo.applyReferral(code);

    switch (result) {
      case Success():
        ref.invalidate(authControllerProvider);
        ref.invalidate(dashboardControllerProvider);
        ref.invalidateSelf();
        return null;
      case Failure(error: final f):
        return f.message;
    }
  }

  /// Redeems 10 points for $2.00 wallet credit. Returns error message if failed, null on success.
  Future<String?> redeemPoints() async {
    final repo = ref.read(referralsRepositoryProvider);
    final result = await repo.redeemPoints();

    switch (result) {
      case Success():
        ref.invalidate(walletControllerProvider);
        ref.invalidate(dashboardControllerProvider);
        ref.invalidateSelf();
        return null;
      case Failure(error: final f):
        return f.message;
    }
  }
}
