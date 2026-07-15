// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'esim_go_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EsimGoBundleDto _$EsimGoBundleDtoFromJson(Map<String, dynamic> json) =>
    _EsimGoBundleDto(
      name: json['name'] as String,
      description: json['description'] as String,
      dataAmount: (json['dataAmount'] as num).toInt(),
      duration: (json['duration'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
      countries:
          (json['countries'] as List<dynamic>?)
              ?.map((e) => EsimGoCountryDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      roamingEnabled:
          (json['roamingEnabled'] as List<dynamic>?)
              ?.map((e) => EsimGoCountryDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$EsimGoBundleDtoToJson(_EsimGoBundleDto instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'dataAmount': instance.dataAmount,
      'duration': instance.duration,
      'price': instance.price,
      'countries': instance.countries,
      'roamingEnabled': instance.roamingEnabled,
    };

_EsimGoCountryDto _$EsimGoCountryDtoFromJson(Map<String, dynamic> json) =>
    _EsimGoCountryDto(
      iso: json['iso'] as String,
      name: json['name'] as String?,
    );

Map<String, dynamic> _$EsimGoCountryDtoToJson(_EsimGoCountryDto instance) =>
    <String, dynamic>{'iso': instance.iso, 'name': instance.name};

_EsimGoOrderRequestDto _$EsimGoOrderRequestDtoFromJson(
  Map<String, dynamic> json,
) => _EsimGoOrderRequestDto(
  type: json['type'] as String,
  assign: json['assign'] as bool,
  order: (json['Order'] as List<dynamic>)
      .map((e) => EsimGoOrderItemDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$EsimGoOrderRequestDtoToJson(
  _EsimGoOrderRequestDto instance,
) => <String, dynamic>{
  'type': instance.type,
  'assign': instance.assign,
  'Order': instance.order.map((e) => e.toJson()).toList(),
};

_EsimGoOrderItemDto _$EsimGoOrderItemDtoFromJson(Map<String, dynamic> json) =>
    _EsimGoOrderItemDto(
      type: json['type'] as String,
      item: json['item'] as String,
      quantity: (json['quantity'] as num).toInt(),
    );

Map<String, dynamic> _$EsimGoOrderItemDtoToJson(_EsimGoOrderItemDto instance) =>
    <String, dynamic>{
      'type': instance.type,
      'item': instance.item,
      'quantity': instance.quantity,
    };

_EsimGoOrderResponseDto _$EsimGoOrderResponseDtoFromJson(
  Map<String, dynamic> json,
) => _EsimGoOrderResponseDto(
  orderReference: json['orderReference'] as String?,
  total: (json['total'] as num?)?.toDouble(),
  currency: json['currency'] as String?,
);

Map<String, dynamic> _$EsimGoOrderResponseDtoToJson(
  _EsimGoOrderResponseDto instance,
) => <String, dynamic>{
  'orderReference': instance.orderReference,
  'total': instance.total,
  'currency': instance.currency,
};
