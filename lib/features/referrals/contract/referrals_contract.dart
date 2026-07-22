/// KeepSIMs — Referrals Contract Interface
///
/// Standard contract for managing user referrals, point balance, redemptions, and applying referral codes.
library;

import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/referrals/model/referral_model.dart';

abstract class ReferralsContract {
  /// Fetches aggregated referral summary for the current authenticated user.
  Future<Result<ReferralSummary>> getSummary();

  /// Applies a referral code for the current user's profile.
  Future<Result<void>> applyReferral(String referralCode);

  /// Redeems 10 points for $2.00 wallet credit.
  Future<Result<Map<String, dynamic>>> redeemPoints();
}
