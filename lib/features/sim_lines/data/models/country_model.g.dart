// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'country_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Country _$CountryFromJson(Map<String, dynamic> json) => _Country(
  id: json['id'] as String,
  name: json['name'] as String,
  isoCode: json['iso_code'] as String,
  dialingCode: json['dialing_code'] as String,
  flagEmoji: json['flag_emoji'] == null
      ? '🌐'
      : _parseFlagEmoji(json['flag_emoji']),
  currencyCode: json['currency_code'] as String,
  avgSimReplacementCost: _parseDoubleNullable(json['avg_sim_replacement_cost']),
  isSupported: json['is_supported'] == null
      ? true
      : _parseBoolDefaultTrue(json['is_supported']),
  smsVerifyCost: json['sms_verify_cost'] == null
      ? 0.0
      : _parseDoubleNullable(json['sms_verify_cost']),
  callVerifyCost: json['call_verify_cost'] == null
      ? 0.0
      : _parseDoubleNullable(json['call_verify_cost']),
  verificationPriceVersion:
      (json['verification_price_version'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$CountryToJson(_Country instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'iso_code': instance.isoCode,
  'dialing_code': instance.dialingCode,
  'flag_emoji': instance.flagEmoji,
  'currency_code': instance.currencyCode,
  'avg_sim_replacement_cost': instance.avgSimReplacementCost,
  'is_supported': instance.isSupported,
  'sms_verify_cost': instance.smsVerifyCost,
  'call_verify_cost': instance.callVerifyCost,
  'verification_price_version': instance.verificationPriceVersion,
};
