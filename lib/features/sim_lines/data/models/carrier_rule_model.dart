import 'package:freezed_annotation/freezed_annotation.dart';

part 'carrier_rule_model.freezed.dart';
part 'carrier_rule_model.g.dart';

@freezed
abstract class CarrierRule with _$CarrierRule {
  const factory CarrierRule({
    required String id,
    @JsonKey(name: 'carrier_id') required String carrierId,
    @JsonKey(name: 'rule_type') required String ruleType,
    @JsonKey(name: 'inactivity_limit_days') required int inactivityLimitDays,
    @JsonKey(name: 'grace_period_days') required int gracePeriodDays,
    @JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble)
    required double minimumTopupAmount,
    @JsonKey(name: 'topup_validity_days') required int topupValidityDays,
    @JsonKey(name: 'inapp_pricing', fromJson: _parseDouble)
    required double inappPricing,
    @JsonKey(name: 'inapp_pricing_currency')
    required String inappPricingCurrency,
  }) = _CarrierRule;

  factory CarrierRule.fromJson(Map<String, dynamic> json) =>
      _$CarrierRuleFromJson(json);
}

double _parseDouble(dynamic value) {
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  if (value is num) {
    return value.toDouble();
  }
  return 0.0;
}
