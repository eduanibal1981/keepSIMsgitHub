import 'package:freezed_annotation/freezed_annotation.dart';

part 'carrier_model.freezed.dart';
part 'carrier_model.g.dart';

@freezed
abstract class Carrier with _$Carrier {
  const factory Carrier({
    required String id,
    @JsonKey(name: 'country_id') required String countryId,
    required String name,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'reloadly_operator_id') int? reloadlyOperatorId,
    @JsonKey(name: 'is_supported') required bool isSupported,
  }) = _Carrier;

  factory Carrier.fromJson(Map<String, dynamic> json) => _$CarrierFromJson(json);
}
