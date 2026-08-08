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
  isSupported: json['is_supported'] as bool,
  fulfillmentGateway: json['fulfillment_gateway'] as String?,
  defaultRefillAmount: json['default_refill_amount'] == null
      ? 5.00
      : _parseDouble(json['default_refill_amount']),
  gatewayPhoneNumber: json['gateway_phone_number'] as String?,
);

Map<String, dynamic> _$CarrierToJson(_Carrier instance) => <String, dynamic>{
  'id': instance.id,
  'country_id': instance.countryId,
  'name': instance.name,
  'logo_url': instance.logoUrl,
  'is_supported': instance.isSupported,
  'fulfillment_gateway': instance.fulfillmentGateway,
  'default_refill_amount': instance.defaultRefillAmount,
  'gateway_phone_number': instance.gatewayPhoneNumber,
};
