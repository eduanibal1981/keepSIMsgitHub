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
    @JsonKey(name: 'health_score') @Default(100) int healthScore,
    @JsonKey(name: 'last_topup_at') DateTime? lastTopupAt,
    @JsonKey(name: 'next_topup_due') DateTime? nextTopupDue,
    @JsonKey(name: 'validity_expires_at') DateTime? validityExpiresAt,
    @JsonKey(name: 'protection_tier') @Default('standard') String protectionTier,
    @JsonKey(name: 'is_auto_detected') @Default(false) bool isAutoDetected,
    @JsonKey(name: 'household_id') String? householdId,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _SimLine;

  factory SimLine.fromJson(Map<String, dynamic> json) => _$SimLineFromJson(json);
}
