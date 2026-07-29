// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'usage_forecast_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UsageForecast _$UsageForecastFromJson(
  Map<String, dynamic> json,
) => _UsageForecast(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  simLineId: json['sim_line_id'] as String?,
  esimId: json['esim_id'] as String?,
  subjectKind: json['subject_kind'] as String,
  method: json['method'] as String,
  confidence: json['confidence'] as String,
  samplesCount: (json['samples_count'] as num?)?.toInt() ?? 0,
  observedIntervalDays: (json['observed_interval_days'] as num?)?.toDouble(),
  mbPerDay: (json['mb_per_day'] as num?)?.toDouble(),
  effectiveValidityDays: (json['effective_validity_days'] as num?)?.toInt(),
  predictedDepletionAt: json['predicted_depletion_at'] == null
      ? null
      : DateTime.parse(json['predicted_depletion_at'] as String),
  daysRemaining: (json['days_remaining'] as num?)?.toInt(),
  suggestedFrequencyDays: (json['suggested_frequency_days'] as num?)?.toInt(),
  suggestedAmountUsd: (json['suggested_amount_usd'] as num?)?.toDouble(),
  suggestedOfferId: json['suggested_offer_id'] as String?,
  alertLeadDays: (json['alert_lead_days'] as num?)?.toInt() ?? 7,
  lastAlertAt: json['last_alert_at'] == null
      ? null
      : DateTime.parse(json['last_alert_at'] as String),
  computedAt: json['computed_at'] == null
      ? null
      : DateTime.parse(json['computed_at'] as String),
);

Map<String, dynamic> _$UsageForecastToJson(
  _UsageForecast instance,
) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'sim_line_id': instance.simLineId,
  'esim_id': instance.esimId,
  'subject_kind': instance.subjectKind,
  'method': instance.method,
  'confidence': instance.confidence,
  'samples_count': instance.samplesCount,
  'observed_interval_days': instance.observedIntervalDays,
  'mb_per_day': instance.mbPerDay,
  'effective_validity_days': instance.effectiveValidityDays,
  'predicted_depletion_at': instance.predictedDepletionAt?.toIso8601String(),
  'days_remaining': instance.daysRemaining,
  'suggested_frequency_days': instance.suggestedFrequencyDays,
  'suggested_amount_usd': instance.suggestedAmountUsd,
  'suggested_offer_id': instance.suggestedOfferId,
  'alert_lead_days': instance.alertLeadDays,
  'last_alert_at': instance.lastAlertAt?.toIso8601String(),
  'computed_at': instance.computedAt?.toIso8601String(),
};
