// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sim_line_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SimLine _$SimLineFromJson(Map<String, dynamic> json) => _SimLine(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  phoneNumber: json['phone_number'] as String,
  nickname: json['nickname'] as String?,
  avatarIcon: json['avatar_icon'] as String? ?? 'sim_card',
  countryId: json['country_id'] as String?,
  carrierId: json['carrier_id'] as String?,
  carrierRuleId: json['carrier_rule_id'] as String?,
  status: json['status'] as String? ?? 'active',
  verificationStatus: json['verification_status'] as String? ?? 'unverified',
  healthScore: (json['health_score'] as num?)?.toInt() ?? 100,
  lastTopupAt: json['last_topup_at'] == null
      ? null
      : DateTime.parse(json['last_topup_at'] as String),
  nextTopupDue: json['next_topup_due'] == null
      ? null
      : DateTime.parse(json['next_topup_due'] as String),
  validityExpiresAt: json['validity_expires_at'] == null
      ? null
      : DateTime.parse(json['validity_expires_at'] as String),
  protectionTier: json['protection_tier'] as String? ?? 'standard',
  isAutoDetected: json['is_auto_detected'] as bool? ?? false,
  isHomeMode: json['is_home_mode'] as bool? ?? false,
  householdId: json['household_id'] as String?,
  planType: json['plan_type'] as String? ?? 'free',
  planExpiresAt: json['plan_expires_at'] == null
      ? null
      : DateTime.parse(json['plan_expires_at'] as String),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$SimLineToJson(_SimLine instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'phone_number': instance.phoneNumber,
  'nickname': instance.nickname,
  'avatar_icon': instance.avatarIcon,
  'country_id': instance.countryId,
  'carrier_id': instance.carrierId,
  'carrier_rule_id': instance.carrierRuleId,
  'status': instance.status,
  'verification_status': instance.verificationStatus,
  'health_score': instance.healthScore,
  'last_topup_at': instance.lastTopupAt?.toIso8601String(),
  'next_topup_due': instance.nextTopupDue?.toIso8601String(),
  'validity_expires_at': instance.validityExpiresAt?.toIso8601String(),
  'protection_tier': instance.protectionTier,
  'is_auto_detected': instance.isAutoDetected,
  'is_home_mode': instance.isHomeMode,
  'household_id': instance.householdId,
  'plan_type': instance.planType,
  'plan_expires_at': instance.planExpiresAt?.toIso8601String(),
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
