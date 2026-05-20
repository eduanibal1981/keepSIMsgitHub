// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_method_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaymentMethod _$PaymentMethodFromJson(Map<String, dynamic> json) =>
    _PaymentMethod(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      type: json['type'] as String? ?? 'card',
      provider: json['provider'] as String?,
      label: json['label'] as String?,
      token: json['token'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      lastFour: json['last_four'] as String?,
      expiryMonth: (json['expiry_month'] as num?)?.toInt(),
      expiryYear: (json['expiry_year'] as num?)?.toInt(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$PaymentMethodToJson(_PaymentMethod instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'type': instance.type,
      'provider': instance.provider,
      'label': instance.label,
      'token': instance.token,
      'is_default': instance.isDefault,
      'last_four': instance.lastFour,
      'expiry_month': instance.expiryMonth,
      'expiry_year': instance.expiryYear,
      'created_at': instance.createdAt?.toIso8601String(),
    };
