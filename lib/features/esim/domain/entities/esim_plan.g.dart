// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'esim_plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EsimPlan _$EsimPlanFromJson(Map<String, dynamic> json) => _EsimPlan(
  id: json['id'] as String,
  name: json['name'] as String,
  dataAmountMB: (json['dataAmountMB'] as num).toInt(),
  durationDays: (json['durationDays'] as num).toInt(),
  priceUsd: (json['priceUsd'] as num).toDouble(),
  providerName: json['providerName'] as String,
  supportedCountries:
      (json['supportedCountries'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  description: json['description'] as String?,
);

Map<String, dynamic> _$EsimPlanToJson(_EsimPlan instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'dataAmountMB': instance.dataAmountMB,
  'durationDays': instance.durationDays,
  'priceUsd': instance.priceUsd,
  'providerName': instance.providerName,
  'supportedCountries': instance.supportedCountries,
  'description': instance.description,
};
