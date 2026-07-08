// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SystemConfig _$SystemConfigFromJson(Map<String, dynamic> json) =>
    _SystemConfig(
      configKey: json['config_key'] as String,
      configValue: json['config_value'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$SystemConfigToJson(_SystemConfig instance) =>
    <String, dynamic>{
      'config_key': instance.configKey,
      'config_value': instance.configValue,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
