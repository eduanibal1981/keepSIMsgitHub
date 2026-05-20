/// SIM Shield — Referrals Contract Interface
///
/// Standard contract for managing user referrals and applying referral codes.
library;

import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/referrals/model/referral_model.dart';

abstract class ReferralsContract {
  /// Fetches a list of referrals made by the current user.
  Future<Result<List<Referral>>> getReferrals();

  /// Applies a referral code to the current user's profile.
  Future<Result<void>> applyReferral(String referralCode);
}
