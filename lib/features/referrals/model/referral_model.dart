/// KeepSIMs — Referral Model
///
/// Maps to referral points, redemptions, and referred users in Supabase.
/// Uses Freezed with snake_case JSON serialization.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'referral_model.freezed.dart';
part 'referral_model.g.dart';

@freezed
abstract class ReferredFriend with _$ReferredFriend {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ReferredFriend({
    required String id,
    required String referrerId,
    required String referredUserId,
    required String code,
    DateTime? createdAt,
    String? displayName,
    String? avatarUrl,
  }) = _ReferredFriend;

  factory ReferredFriend.fromJson(Map<String, dynamic> json) =>
      _$ReferredFriendFromJson(json);
}

@freezed
abstract class ReferralPointEntry with _$ReferralPointEntry {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ReferralPointEntry({
    required String id,
    required String referrerId,
    required String referredUserId,
    String? simLineId,
    required int points,
    required String source,
    DateTime? createdAt,
  }) = _ReferralPointEntry;

  factory ReferralPointEntry.fromJson(Map<String, dynamic> json) =>
      _$ReferralPointEntryFromJson(json);
}

@freezed
abstract class ReferralRedemptionEntry with _$ReferralRedemptionEntry {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ReferralRedemptionEntry({
    required String id,
    required String userId,
    required int pointsSpent,
    String? walletTxnId,
    DateTime? createdAt,
  }) = _ReferralRedemptionEntry;

  factory ReferralRedemptionEntry.fromJson(Map<String, dynamic> json) =>
      _$ReferralRedemptionEntryFromJson(json);
}

@freezed
abstract class ReferralSummary with _$ReferralSummary {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ReferralSummary({
    required int pointsBalance,
    required int totalPointsEarned,
    required int pointsSpent,
    required String referralCode,
    required List<ReferredFriend> referredFriends,
    required List<ReferralPointEntry> pointHistory,
    required List<ReferralRedemptionEntry> redemptions,
  }) = _ReferralSummary;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) =>
      _$ReferralSummaryFromJson(json);
}
