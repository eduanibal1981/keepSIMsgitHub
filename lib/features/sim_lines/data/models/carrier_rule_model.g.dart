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
);

Map<String, dynamic> _$CarrierRuleToJson(_CarrierRule instance) =>
    <String, dynamic>{
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
    };
