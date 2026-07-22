// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'esim_order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EsimOrder _$EsimOrderFromJson(Map<String, dynamic> json) => _EsimOrder(
  id: json['id'] as String,
  userId: json['userId'] as String,
  provider: json['provider'] as String,
  bundleName: json['bundleName'] as String,
  quantity: (json['quantity'] as num).toInt(),
  wholesalePriceUsd: (json['wholesalePriceUsd'] as num).toDouble(),
  retailPriceUsd: (json['retailPriceUsd'] as num).toDouble(),
  markupPercent: (json['markupPercent'] as num).toDouble(),
  status: json['status'] as String,
  providerOrderRef: json['providerOrderRef'] as String?,
  errorMessage: json['errorMessage'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$EsimOrderToJson(_EsimOrder instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'provider': instance.provider,
      'bundleName': instance.bundleName,
      'quantity': instance.quantity,
      'wholesalePriceUsd': instance.wholesalePriceUsd,
      'retailPriceUsd': instance.retailPriceUsd,
      'markupPercent': instance.markupPercent,
      'status': instance.status,
      'providerOrderRef': instance.providerOrderRef,
      'errorMessage': instance.errorMessage,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
