// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sim_liveness_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SimLivenessResult _$SimLivenessResultFromJson(Map<String, dynamic> json) =>
    _SimLivenessResult(
      isActive: json['is_active'] as bool? ?? false,
      carrierStatus: json['carrier_status'] as String? ?? 'pending',
      detectedOperatorName: json['detected_operator_name'] as String?,
      countryCode: json['country_code'] as String?,
      reason: json['reason'] as String?,
      message: json['message'] as String? ?? '',
      provider: json['provider'] as String? ?? 'none',
      verifiedAt: json['verified_at'] == null
          ? null
          : DateTime.parse(json['verified_at'] as String),
    );

Map<String, dynamic> _$SimLivenessResultToJson(_SimLivenessResult instance) =>
    <String, dynamic>{
      'is_active': instance.isActive,
      'carrier_status': instance.carrierStatus,
      'detected_operator_name': instance.detectedOperatorName,
      'country_code': instance.countryCode,
      'reason': instance.reason,
      'message': instance.message,
      'provider': instance.provider,
      'verified_at': instance.verifiedAt?.toIso8601String(),
    };
