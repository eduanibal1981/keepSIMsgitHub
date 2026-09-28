// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    _AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['is_read'] as bool? ?? false,
      actionUrl: json['action_url'] as String?,
      simLineId: json['sim_line_id'] as String?,
      deliveredVia:
          (json['delivered_via'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      eventType: json['event_type'] as String?,
      sourceEventKey: json['source_event_key'] as String?,
      occurredAt: json['occurred_at'] == null
          ? null
          : DateTime.parse(json['occurred_at'] as String),
      scheduledAt: json['scheduled_at'] == null
          ? null
          : DateTime.parse(json['scheduled_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      templateVersion: (json['template_version'] as num?)?.toInt() ?? 1,
      templateData: json['template_data'] as Map<String, dynamic>? ?? const {},
      target: json['target'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$AppNotificationToJson(_AppNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'category': instance.category,
      'title': instance.title,
      'body': instance.body,
      'is_read': instance.isRead,
      'action_url': instance.actionUrl,
      'sim_line_id': instance.simLineId,
      'delivered_via': instance.deliveredVia,
      'created_at': instance.createdAt?.toIso8601String(),
      'schema_version': instance.schemaVersion,
      'event_type': instance.eventType,
      'source_event_key': instance.sourceEventKey,
      'occurred_at': instance.occurredAt?.toIso8601String(),
      'scheduled_at': instance.scheduledAt?.toIso8601String(),
      'expires_at': instance.expiresAt?.toIso8601String(),
      'template_version': instance.templateVersion,
      'template_data': instance.templateData,
      'target': instance.target,
    };
