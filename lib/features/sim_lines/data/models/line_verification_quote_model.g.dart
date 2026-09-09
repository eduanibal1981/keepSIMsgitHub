// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'line_verification_quote_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LineVerificationQuote _$LineVerificationQuoteFromJson(
  Map<String, dynamic> json,
) => _LineVerificationQuote(
  simLineId: json['sim_line_id'] as String,
  phoneNumber: json['phone_number'] as String,
  countryId: json['country_id'] as String?,
  countryName: json['country_name'] as String?,
  smsVerifyCostUsd: json['sms_verify_cost_usd'] == null
      ? 0.0
      : _parseDouble(json['sms_verify_cost_usd']),
  callVerifyCostUsd: json['call_verify_cost_usd'] == null
      ? 0.0
      : _parseDouble(json['call_verify_cost_usd']),
  isPaidPlan: json['is_paid_plan'] as bool? ?? false,
  hasAnnualAllowance: json['has_annual_allowance'] as bool? ?? false,
  allowancePeriodEnd: json['allowance_period_end'] == null
      ? null
      : DateTime.parse(json['allowance_period_end'] as String),
  walletBalanceUsd: json['wallet_balance_usd'] == null
      ? 0.0
      : _parseDouble(json['wallet_balance_usd']),
  walletAvailableUsd: json['wallet_available_usd'] == null
      ? 0.0
      : _parseDouble(json['wallet_available_usd']),
  priceVersion: (json['price_version'] as num?)?.toInt() ?? 1,
  inFlightAttemptId: json['in_flight_attempt_id'] as String?,
);

Map<String, dynamic> _$LineVerificationQuoteToJson(
  _LineVerificationQuote instance,
) => <String, dynamic>{
  'sim_line_id': instance.simLineId,
  'phone_number': instance.phoneNumber,
  'country_id': instance.countryId,
  'country_name': instance.countryName,
  'sms_verify_cost_usd': instance.smsVerifyCostUsd,
  'call_verify_cost_usd': instance.callVerifyCostUsd,
  'is_paid_plan': instance.isPaidPlan,
  'has_annual_allowance': instance.hasAnnualAllowance,
  'allowance_period_end': instance.allowancePeriodEnd?.toIso8601String(),
  'wallet_balance_usd': instance.walletBalanceUsd,
  'wallet_available_usd': instance.walletAvailableUsd,
  'price_version': instance.priceVersion,
  'in_flight_attempt_id': instance.inFlightAttemptId,
};
