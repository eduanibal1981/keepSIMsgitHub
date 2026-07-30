// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'roam_quote_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RoamQuote _$RoamQuoteFromJson(Map<String, dynamic> json) => _RoamQuote(
  destinationCountryCode: json['destination_country_code'] as String,
  destinationCountryName: json['destination_country_name'] as String,
  tripDays: (json['trip_days'] as num).toInt(),
  tripDataMb: (json['trip_data_mb'] as num).toInt(),
  roamingCarrierId: json['roaming_carrier_id'] as String?,
  roamingCarrierName: json['roaming_carrier_name'] as String?,
  roamingHomeCountry: json['roaming_home_country'] as String?,
  roamingProductName: json['roaming_product_name'] as String?,
  roamingProductKind: json['roaming_product_kind'] as String?,
  roamingScope: json['roaming_scope'] as String?,
  roamingUnits: (json['roaming_units'] as num?)?.toInt(),
  roamingTotalUsd: (json['roaming_total_usd'] as num?)?.toDouble(),
  roamingIsEstimate: json['roaming_is_estimate'] as bool? ?? true,
  roamingSourceUrl: json['roaming_source_url'] as String?,
  roamingPricedAsOf: json['roaming_priced_as_of'] == null
      ? null
      : DateTime.parse(json['roaming_priced_as_of'] as String),
  esimOfferId: json['esim_offer_id'] as String?,
  esimBundleName: json['esim_bundle_name'] as String?,
  esimDataMb: (json['esim_data_mb'] as num?)?.toInt(),
  esimDurationDays: (json['esim_duration_days'] as num?)?.toInt(),
  esimQuantity: (json['esim_quantity'] as num?)?.toInt(),
  esimUnitPriceUsd: (json['esim_unit_price_usd'] as num?)?.toDouble(),
  esimTotalUsd: (json['esim_total_usd'] as num?)?.toDouble(),
  esimCoversTrip: json['esim_covers_trip'] as bool? ?? false,
  savingsUsd: (json['savings_usd'] as num?)?.toDouble(),
  verdict: json['verdict'] as String,
);

Map<String, dynamic> _$RoamQuoteToJson(_RoamQuote instance) =>
    <String, dynamic>{
      'destination_country_code': instance.destinationCountryCode,
      'destination_country_name': instance.destinationCountryName,
      'trip_days': instance.tripDays,
      'trip_data_mb': instance.tripDataMb,
      'roaming_carrier_id': instance.roamingCarrierId,
      'roaming_carrier_name': instance.roamingCarrierName,
      'roaming_home_country': instance.roamingHomeCountry,
      'roaming_product_name': instance.roamingProductName,
      'roaming_product_kind': instance.roamingProductKind,
      'roaming_scope': instance.roamingScope,
      'roaming_units': instance.roamingUnits,
      'roaming_total_usd': instance.roamingTotalUsd,
      'roaming_is_estimate': instance.roamingIsEstimate,
      'roaming_source_url': instance.roamingSourceUrl,
      'roaming_priced_as_of': instance.roamingPricedAsOf?.toIso8601String(),
      'esim_offer_id': instance.esimOfferId,
      'esim_bundle_name': instance.esimBundleName,
      'esim_data_mb': instance.esimDataMb,
      'esim_duration_days': instance.esimDurationDays,
      'esim_quantity': instance.esimQuantity,
      'esim_unit_price_usd': instance.esimUnitPriceUsd,
      'esim_total_usd': instance.esimTotalUsd,
      'esim_covers_trip': instance.esimCoversTrip,
      'savings_usd': instance.savingsUsd,
      'verdict': instance.verdict,
    };

_RoamCarrierOption _$RoamCarrierOptionFromJson(Map<String, dynamic> json) =>
    _RoamCarrierOption(
      carrierId: json['carrier_id'] as String,
      carrierName: json['carrier_name'] as String,
      homeIso: json['home_iso'] as String,
      homeCountry: json['home_country'] as String,
      isHome: json['is_home'] as bool? ?? false,
      hasRate: json['has_rate'] as bool? ?? false,
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$RoamCarrierOptionToJson(_RoamCarrierOption instance) =>
    <String, dynamic>{
      'carrier_id': instance.carrierId,
      'carrier_name': instance.carrierName,
      'home_iso': instance.homeIso,
      'home_country': instance.homeCountry,
      'is_home': instance.isHome,
      'has_rate': instance.hasRate,
      'product_count': instance.productCount,
    };
