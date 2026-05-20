// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_setting_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AlertSetting _$AlertSettingFromJson(Map<String, dynamic> json) =>
    _AlertSetting(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: json['category'] as String,
      isEnabled: json['is_enabled'] as bool? ?? true,
      channels:
          (json['channels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['push'],
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$AlertSettingToJson(_AlertSetting instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'category': instance.category,
      'is_enabled': instance.isEnabled,
      'channels': instance.channels,
      'created_at': instance.createdAt?.toIso8601String(),
    };
