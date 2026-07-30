// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'line_rescue_policy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LineRescuePolicy _$LineRescuePolicyFromJson(Map<String, dynamic> json) =>
    _LineRescuePolicy(
      simLineId: json['sim_line_id'] as String,
      userId: json['user_id'] as String,
      maxUsd: (json['max_usd'] as num?)?.toDouble() ?? 0.0,
      leadDays: (json['lead_days'] as num?)?.toInt() ?? 2,
      warnLeadDays: (json['warn_lead_days'] as num?)?.toInt() ?? 3,
      lastWarnedAt: json['last_warned_at'] == null
          ? null
          : DateTime.parse(json['last_warned_at'] as String),
      lastRescueAt: json['last_rescue_at'] == null
          ? null
          : DateTime.parse(json['last_rescue_at'] as String),
      lastRescueExecutionId: json['last_rescue_execution_id'] as String?,
      rescueCount: (json['rescue_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$LineRescuePolicyToJson(_LineRescuePolicy instance) =>
    <String, dynamic>{
      'sim_line_id': instance.simLineId,
      'user_id': instance.userId,
      'max_usd': instance.maxUsd,
      'lead_days': instance.leadDays,
      'warn_lead_days': instance.warnLeadDays,
      'last_warned_at': instance.lastWarnedAt?.toIso8601String(),
      'last_rescue_at': instance.lastRescueAt?.toIso8601String(),
      'last_rescue_execution_id': instance.lastRescueExecutionId,
      'rescue_count': instance.rescueCount,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
