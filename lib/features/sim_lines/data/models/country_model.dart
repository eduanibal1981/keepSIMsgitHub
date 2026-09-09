import 'package:freezed_annotation/freezed_annotation.dart';

part 'country_model.freezed.dart';
part 'country_model.g.dart';

double? _parseDoubleNullable(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    return double.tryParse(value);
  }
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

String _parseFlagEmoji(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  return '🌐';
}

bool _parseBoolDefaultTrue(dynamic value) {
  if (value is bool) return value;
  return true;
}

@freezed
abstract class Country with _$Country {
  const factory Country({
    required String id,
    required String name,
    @JsonKey(name: 'iso_code') required String isoCode,
    @JsonKey(name: 'dialing_code') required String dialingCode,
    @JsonKey(name: 'flag_emoji', fromJson: _parseFlagEmoji)
    @Default('🌐')
    String flagEmoji,
    @JsonKey(name: 'currency_code') required String currencyCode,
    @JsonKey(name: 'avg_sim_replacement_cost', fromJson: _parseDoubleNullable)
    double? avgSimReplacementCost,
    @JsonKey(name: 'is_supported', fromJson: _parseBoolDefaultTrue)
    @Default(true)
    bool isSupported,
    @JsonKey(name: 'sms_verify_cost', fromJson: _parseDoubleNullable)
    @Default(0.0)
    double? smsVerifyCost,
    @JsonKey(name: 'call_verify_cost', fromJson: _parseDoubleNullable)
    @Default(0.0)
    double? callVerifyCost,
    @JsonKey(name: 'verification_price_version')
    @Default(1)
    int verificationPriceVersion,
  }) = _Country;

  factory Country.fromJson(Map<String, dynamic> json) =>
      _$CountryFromJson(json);
}
