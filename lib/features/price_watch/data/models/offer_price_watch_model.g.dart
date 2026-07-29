// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offer_price_watch_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OfferPriceWatch _$OfferPriceWatchFromJson(Map<String, dynamic> json) =>
    _OfferPriceWatch(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      source: json['source'] as String,
      countryCode: json['country_code'] as String,
      carrierCode: json['carrier_code'] as String?,
      origin: json['origin'] as String? ?? 'user',
      isActive: json['is_active'] as bool? ?? true,
      thresholdPercent: (json['threshold_percent'] as num?)?.toDouble(),
      lastBestUsd: (json['last_best_usd'] as num?)?.toDouble(),
      lastBaselineUsd: (json['last_baseline_usd'] as num?)?.toDouble(),
      lastAlertedBestUsd: (json['last_alerted_best_usd'] as num?)?.toDouble(),
      lastAlertAt: json['last_alert_at'] == null
          ? null
          : DateTime.parse(json['last_alert_at'] as String),
      lastCheckedAt: json['last_checked_at'] == null
          ? null
          : DateTime.parse(json['last_checked_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$OfferPriceWatchToJson(_OfferPriceWatch instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'source': instance.source,
      'country_code': instance.countryCode,
      'carrier_code': instance.carrierCode,
      'origin': instance.origin,
      'is_active': instance.isActive,
      'threshold_percent': instance.thresholdPercent,
      'last_best_usd': instance.lastBestUsd,
      'last_baseline_usd': instance.lastBaselineUsd,
      'last_alerted_best_usd': instance.lastAlertedBestUsd,
      'last_alert_at': instance.lastAlertAt?.toIso8601String(),
      'last_checked_at': instance.lastCheckedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
