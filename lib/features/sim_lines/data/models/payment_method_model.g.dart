// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_method_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaymentMethod _$PaymentMethodFromJson(Map<String, dynamic> json) =>
    _PaymentMethod(
      code: json['code'] as String,
      name: json['name'] as String,
      feePercentage: (json['fee_percentage'] as num).toDouble(),
      feeFixed: (json['fee_fixed'] as num).toDouble(),
      isActive: json['is_active'] as bool,
    );

Map<String, dynamic> _$PaymentMethodToJson(_PaymentMethod instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'fee_percentage': instance.feePercentage,
      'fee_fixed': instance.feeFixed,
      'is_active': instance.isActive,
    };
