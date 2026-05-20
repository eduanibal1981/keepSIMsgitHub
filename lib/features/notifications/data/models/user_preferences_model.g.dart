// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserPreferences _$UserPreferencesFromJson(Map<String, dynamic> json) =>
    _UserPreferences(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      quietHoursStart: json['quiet_hours_start'] as String?,
      quietHoursEnd: json['quiet_hours_end'] as String?,
      weeklyDigestEnabled: json['weekly_digest_enabled'] as bool? ?? true,
      travelModeEnabled: json['travel_mode_enabled'] as bool? ?? false,
      biometricEnabled: json['biometric_enabled'] as bool? ?? false,
      transactionPinHash: json['transaction_pin_hash'] as String?,
      theme: json['theme'] as String? ?? 'system',
      language: json['language'] as String? ?? 'en',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$UserPreferencesToJson(_UserPreferences instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'quiet_hours_start': instance.quietHoursStart,
      'quiet_hours_end': instance.quietHoursEnd,
      'weekly_digest_enabled': instance.weeklyDigestEnabled,
      'travel_mode_enabled': instance.travelModeEnabled,
      'biometric_enabled': instance.biometricEnabled,
      'transaction_pin_hash': instance.transactionPinHash,
      'theme': instance.theme,
      'language': instance.language,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
