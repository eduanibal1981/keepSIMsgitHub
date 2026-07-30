// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fx_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FxContext _$FxContextFromJson(Map<String, dynamic> json) => _FxContext(
  enabled: json['enabled'] as bool? ?? true,
  currency: json['currency'] as String? ?? 'USD',
  requestedCurrency: json['requested_currency'] as String? ?? 'USD',
  rate: (json['rate'] as num?)?.toDouble() ?? 1.0,
  symbol: json['symbol'] as String? ?? r'$',
  decimalDigits: (json['decimal_digits'] as num?)?.toInt() ?? 2,
  asOf: json['as_of'] == null ? null : DateTime.parse(json['as_of'] as String),
  stale: json['stale'] as bool? ?? false,
  fallbackReason: json['fallback_reason'] as String?,
  maxAgeHours: (json['max_age_hours'] as num?)?.toDouble() ?? 72.0,
  available:
      (json['available'] as List<dynamic>?)
          ?.map((e) => FxCurrencyOption.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <FxCurrencyOption>[],
);

Map<String, dynamic> _$FxContextToJson(_FxContext instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'currency': instance.currency,
      'requested_currency': instance.requestedCurrency,
      'rate': instance.rate,
      'symbol': instance.symbol,
      'decimal_digits': instance.decimalDigits,
      'as_of': instance.asOf?.toIso8601String(),
      'stale': instance.stale,
      'fallback_reason': instance.fallbackReason,
      'max_age_hours': instance.maxAgeHours,
      'available': instance.available,
    };

_FxCurrencyOption _$FxCurrencyOptionFromJson(Map<String, dynamic> json) =>
    _FxCurrencyOption(
      code: json['code'] as String,
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      decimalDigits: (json['decimal_digits'] as num?)?.toInt() ?? 2,
    );

Map<String, dynamic> _$FxCurrencyOptionToJson(_FxCurrencyOption instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'symbol': instance.symbol,
      'decimal_digits': instance.decimalDigits,
    };
