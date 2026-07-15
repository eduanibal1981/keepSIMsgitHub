import 'package:freezed_annotation/freezed_annotation.dart';

part 'carrier_model.freezed.dart';
part 'carrier_model.g.dart';

double _parseDouble(dynamic value) {
  if (value == null) return 5.00;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 5.00;
  return 5.00;
}

@freezed
abstract class Carrier with _$Carrier {
  const factory Carrier({
    required String id,
    @JsonKey(name: 'country_id') required String countryId,
    required String name,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'reloadly_operator_id') int? reloadlyOperatorId,
    @JsonKey(name: 'is_supported') required bool isSupported,
    @JsonKey(name: 'fulfillment_gateway') String? fulfillmentGateway,
    @JsonKey(name: 'api_provider') String? apiProvider,
    @JsonKey(name: 'default_refill_amount', fromJson: _parseDouble)
    @Default(5.00)
    double defaultRefillAmount,
    @JsonKey(name: 'gateway_phone_number') String? gatewayPhoneNumber,
  }) = _Carrier;

  factory Carrier.fromJson(Map<String, dynamic> json) =>
      _$CarrierFromJson(json);
}

