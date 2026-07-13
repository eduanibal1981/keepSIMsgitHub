// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carrier_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Carrier _$CarrierFromJson(Map<String, dynamic> json) => _Carrier(
  id: json['id'] as String,
  countryId: json['country_id'] as String,
  name: json['name'] as String,
  logoUrl: json['logo_url'] as String?,
  reloadlyOperatorId: (json['reloadly_operator_id'] as num?)?.toInt(),
  isSupported: json['is_supported'] as bool,
  fulfillmentGateway: json['fulfillment_gateway'] as String?,
  apiProvider: json['api_provider'] as String?,
);

Map<String, dynamic> _$CarrierToJson(_Carrier instance) => <String, dynamic>{
  'id': instance.id,
  'country_id': instance.countryId,
  'name': instance.name,
  'logo_url': instance.logoUrl,
  'reloadly_operator_id': instance.reloadlyOperatorId,
  'is_supported': instance.isSupported,
  'fulfillment_gateway': instance.fulfillmentGateway,
  'api_provider': instance.apiProvider,
};
