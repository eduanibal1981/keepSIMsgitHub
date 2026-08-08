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

/// A telecom, and nothing about how a supplier spells it.
///
/// K3 dropped `api_provider` and `reloadly_operator_id` from this table along
/// with the three `zen_`/`dt_`/`ding_` code pairs. Which supplier fulfils a
/// carrier — and what that supplier calls the country and the telecom — lives
/// in `carrier_provider_map`, which is deny-all to clients on purpose: the app
/// has no business dispatching on a supplier name. Ask
/// `list_carrier_offers(carrier_id)` for what can be bought instead.
@freezed
abstract class Carrier with _$Carrier {
  const factory Carrier({
    required String id,
    @JsonKey(name: 'country_id') required String countryId,
    required String name,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'is_supported') required bool isSupported,
    @JsonKey(name: 'fulfillment_gateway') String? fulfillmentGateway,
    @JsonKey(name: 'default_refill_amount', fromJson: _parseDouble)
    @Default(5.00)
    double defaultRefillAmount,
    @JsonKey(name: 'gateway_phone_number') String? gatewayPhoneNumber,
  }) = _Carrier;

  factory Carrier.fromJson(Map<String, dynamic> json) =>
      _$CarrierFromJson(json);
}

