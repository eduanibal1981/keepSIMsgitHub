// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_topup_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ScheduledTopup _$ScheduledTopupFromJson(Map<String, dynamic> json) =>
    _ScheduledTopup(
      id: json['id'] as String,
      simLineId: json['sim_line_id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      frequencyDays: (json['frequency_days'] as num).toInt(),
      nextExecutionAt: DateTime.parse(json['next_execution_at'] as String),
      lastExecutionAt: json['last_execution_at'] == null
          ? null
          : DateTime.parse(json['last_execution_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      maxRetries: (json['max_retries'] as num?)?.toInt() ?? 4,
      status: json['status'] as String? ?? 'active',
      scheduleType: json['schedule_type'] as String? ?? 'notify',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      offerId: json['offer_id'] as String?,
      offerValue: (json['offer_value'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ScheduledTopupToJson(_ScheduledTopup instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sim_line_id': instance.simLineId,
      'user_id': instance.userId,
      'amount': instance.amount,
      'currency': instance.currency,
      'frequency_days': instance.frequencyDays,
      'next_execution_at': instance.nextExecutionAt.toIso8601String(),
      'last_execution_at': instance.lastExecutionAt?.toIso8601String(),
      'is_active': instance.isActive,
      'retry_count': instance.retryCount,
      'max_retries': instance.maxRetries,
      'status': instance.status,
      'schedule_type': instance.scheduleType,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'offer_id': instance.offerId,
      'offer_value': instance.offerValue,
    };
