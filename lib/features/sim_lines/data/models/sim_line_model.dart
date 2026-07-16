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
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _SimLine;

  factory SimLine.fromJson(Map<String, dynamic> json) =>
      _$SimLineFromJson(json);
}
