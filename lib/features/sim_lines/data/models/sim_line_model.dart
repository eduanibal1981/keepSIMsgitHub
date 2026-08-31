import 'package:freezed_annotation/freezed_annotation.dart';

part 'sim_line_model.freezed.dart';
part 'sim_line_model.g.dart';

@freezed
abstract class SimLine with _$SimLine {
  const factory SimLine({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'phone_number') required String phoneNumber,
    String? nickname,
    @JsonKey(name: 'avatar_icon') @Default('sim_card') String avatarIcon,
    @JsonKey(name: 'country_id') String? countryId,
    @JsonKey(name: 'carrier_id') String? carrierId,
    @JsonKey(name: 'carrier_rule_id') String? carrierRuleId,
    @Default('active') String status,
    @JsonKey(name: 'verification_status')
    @Default('unverified')
    String verificationStatus,
    @JsonKey(name: 'health_score') @Default(100) int healthScore,
    @JsonKey(name: 'last_topup_at') DateTime? lastTopupAt,
    @JsonKey(name: 'next_topup_due') DateTime? nextTopupDue,
    @JsonKey(name: 'validity_expires_at') DateTime? validityExpiresAt,
    @JsonKey(name: 'protection_tier')
    @Default('standard')
    String protectionTier,
    @JsonKey(name: 'is_auto_detected') @Default(false) bool isAutoDetected,
    // Location fact only: the user is in this SIM's home country.
    @JsonKey(name: 'is_home_mode') @Default(false) bool isHomeMode,
    // Intent: auto-refill protection is paused (set on entering home mode
    // unless requiresProtectionAtHome). All pausing/health keys on this.
    @JsonKey(name: 'protection_paused') @Default(false) bool protectionPaused,
    // This line must stay protected even while the user is home
    // (e.g. a resident's dormant second SIM that would die unattended).
    @JsonKey(name: 'requires_protection_at_home')
    @Default(false)
    bool requiresProtectionAtHome,
    @JsonKey(name: 'household_id') String? householdId,
    @JsonKey(name: 'plan_type') @Default('free') String planType,
    @JsonKey(name: 'plan_expires_at') DateTime? planExpiresAt,
    @JsonKey(name: 'is_carrier_verified') @Default(false) bool isCarrierVerified,
    @JsonKey(name: 'carrier_status')
    @Default('pending')
    String carrierStatus,
    @JsonKey(name: 'detected_operator_name') String? detectedOperatorName,
    @JsonKey(name: 'carrier_verified_at') DateTime? carrierVerifiedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _SimLine;

  factory SimLine.fromJson(Map<String, dynamic> json) =>
      _$SimLineFromJson(json);
}

/// I2: what a line is *entitled to*, in one place.
///
/// There are two tier columns on `sim_lines` and they disagree on live data:
/// `plan_type` is what a purchase writes (`trg_fn_apply_plan_tier_from_payment`,
/// `pay_plan_fee_from_wallet`), while `protection_tier` is an older column that
/// nothing in the payment path updates — **3 of the 4 production premium lines
/// carry `plan_type='premium'` with `protection_tier='standard'`**. Gating on
/// `protection_tier`, or on the account-level `profiles.subscription_tier`
/// (which is `'premium'` for *nobody*), silently withholds paid features from
/// paying customers.
///
/// `plan_type` is authoritative. `protection_tier` is accepted only as a
/// widening fallback so no existing entitlement is taken away.
extension SimLineEntitlement on SimLine {
  String get effectiveTier {
    final plan = planType.trim().toLowerCase();
    if (plan == 'premium') return 'premium';
    final protection = protectionTier.trim().toLowerCase();
    if (protection == 'premium') return 'premium';
    if (plan == 'standard' || protection == 'standard') return 'standard';
    return 'free';
  }

  bool get isPremiumPlan => effectiveTier == 'premium';

  /// True for anything the user has paid for — i.e. not the free tier.
  bool get isPaidPlan => effectiveTier != 'free';
}

extension SimLineWritablePayload on SimLine {
  Map<String, dynamic> toClientWritableJson() {
    return {
      'phone_number': phoneNumber,
      'nickname': nickname,
      'avatar_icon': avatarIcon,
      'status': status,
      'country_id': countryId,
      'carrier_id': carrierId,
      'carrier_rule_id': carrierRuleId,
      'household_id': householdId,
      'is_home_mode': isHomeMode,
      'protection_paused': protectionPaused,
      'requires_protection_at_home': requiresProtectionAtHome,
      'is_carrier_verified': isCarrierVerified,
      'carrier_status': carrierStatus,
      'detected_operator_name': detectedOperatorName,
      'carrier_verified_at': carrierVerifiedAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
