// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'line_activity_log_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LineActivityLog _$LineActivityLogFromJson(Map<String, dynamic> json) =>
    _LineActivityLog(
      id: json['id'] as String,
      simLineId: json['sim_line_id'] as String,
      userId: json['user_id'] as String,
      eventType: json['event_type'] as String,
      description: json['description'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$LineActivityLogToJson(_LineActivityLog instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sim_line_id': instance.simLineId,
      'user_id': instance.userId,
      'event_type': instance.eventType,
      'description': instance.description,
      'metadata': instance.metadata,
      'created_at': instance.createdAt.toIso8601String(),
    };
