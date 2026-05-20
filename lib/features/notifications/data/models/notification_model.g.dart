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
    };
