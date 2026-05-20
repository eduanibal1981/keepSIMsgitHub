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
  flagEmoji: json['flag_emoji'] as String,
  currencyCode: json['currency_code'] as String,
  avgSimReplacementCost: (json['avg_sim_replacement_cost'] as num).toDouble(),
  isSupported: json['is_supported'] as bool,
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
};
