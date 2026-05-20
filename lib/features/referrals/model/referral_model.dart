/// SIM Shield — Referral Model
///
/// Maps to the `referrals` table in Supabase, with joined `UserProfile` for referred users.
/// Uses Freezed with snake_case JSON serialization.
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';

part 'referral_model.freezed.dart';
part 'referral_model.g.dart';

@freezed
abstract class Referral with _$Referral {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Referral({
    required String id,
    required String referrerId,
    required String referredId,
    required String referralCode,
    required double rewardAmount,
    required bool referrerCredited,
    required bool referredCredited,
    DateTime? createdAt,
    // Joined referred friend's profile details
    UserProfile? referredProfile,
  }) = _Referral;

  factory Referral.fromJson(Map<String, dynamic> json) =>
      _$ReferralFromJson(json);
}
