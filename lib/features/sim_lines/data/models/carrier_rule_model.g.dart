// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carrier_rule_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CarrierRule _$CarrierRuleFromJson(Map<String, dynamic> json) => _CarrierRule(
  id: json['id'] as String,
  carrierId: json['carrier_id'] as String,
  ruleType: json['rule_type'] as String,
  inactivityLimitDays: (json['inactivity_limit_days'] as num).toInt(),
  gracePeriodDays: (json['grace_period_days'] as num).toInt(),
  minimumTopupAmount: _parseDouble(json['minimum_topup_amount']),
  topupValidityDays: (json['topup_validity_days'] as num).toInt(),
  inappPricing: _parseDouble(json['inapp_pricing']),
  inappPricingCurrency: json['inapp_pricing_currency'] as String,
  offerId: json['offer_id'] as String?,
  offerValue: (json['offer_value'] as num?)?.toInt(),
  activityRequirement: json['activity_requirement'] as String? ?? 'recharge_ok',
  validityQualifyingTopupAmount: _parseNullableDouble(
    json['validity_qualifying_topup_amount'],
  ),
  activityRequirementNote: json['activity_requirement_note'] as String?,
  balanceValidityDays: (json['balance_validity_days'] as num?)?.toInt(),
  refillIntervalDaysOverride: (json['refill_interval_days_override'] as num?)
      ?.toInt(),
  ruleSourceUrl: json['rule_source_url'] as String?,
  smsSenderIds: (json['sms_sender_ids'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  smsBalanceRegex: json['sms_balance_regex'] as String?,
  smsExpiryRegex: json['sms_expiry_regex'] as String?,
  smsKeywords: (json['sms_keywords'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  smsLanguage: json['sms_language'] as String? ?? 'auto',
);

Map<String, dynamic> _$CarrierRuleToJson(
  _CarrierRule instance,
) => <String, dynamic>{
  'id': instance.id,
  'carrier_id': instance.carrierId,
  'rule_type': instance.ruleType,
  'inactivity_limit_days': instance.inactivityLimitDays,
  'grace_period_days': instance.gracePeriodDays,
  'minimum_topup_amount': instance.minimumTopupAmount,
  'topup_validity_days': instance.topupValidityDays,
  'inapp_pricing': instance.inappPricing,
  'inapp_pricing_currency': instance.inappPricingCurrency,
  'offer_id': instance.offerId,
  'offer_value': instance.offerValue,
  'activity_requirement': instance.activityRequirement,
  'validity_qualifying_topup_amount': instance.validityQualifyingTopupAmount,
  'activity_requirement_note': instance.activityRequirementNote,
  'balance_validity_days': instance.balanceValidityDays,
  'refill_interval_days_override': instance.refillIntervalDaysOverride,
  'rule_source_url': instance.ruleSourceUrl,
  'sms_sender_ids': instance.smsSenderIds,
  'sms_balance_regex': instance.smsBalanceRegex,
  'sms_expiry_regex': instance.smsExpiryRegex,
  'sms_keywords': instance.smsKeywords,
  'sms_language': instance.smsLanguage,
};
