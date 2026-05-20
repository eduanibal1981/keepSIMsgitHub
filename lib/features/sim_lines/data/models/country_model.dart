import 'package:freezed_annotation/freezed_annotation.dart';

part 'country_model.freezed.dart';
part 'country_model.g.dart';

@freezed
abstract class Country with _$Country {
  const factory Country({
    required String id,
    required String name,
    @JsonKey(name: 'iso_code') required String isoCode,
    @JsonKey(name: 'dialing_code') required String dialingCode,
    @JsonKey(name: 'flag_emoji') required String flagEmoji,
    @JsonKey(name: 'currency_code') required String currencyCode,
    @JsonKey(name: 'avg_sim_replacement_cost') required double avgSimReplacementCost,
    @JsonKey(name: 'is_supported') required bool isSupported,
  }) = _Country;

  factory Country.fromJson(Map<String, dynamic> json) => _$CountryFromJson(json);
}
