import 'package:freezed_annotation/freezed_annotation.dart';

part 'line_verification_quote_model.freezed.dart';
part 'line_verification_quote_model.g.dart';

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

@freezed
abstract class LineVerificationQuote with _$LineVerificationQuote {
  const factory LineVerificationQuote({
    @JsonKey(name: 'sim_line_id') required String simLineId,
    @JsonKey(name: 'phone_number') required String phoneNumber,
    @JsonKey(name: 'country_id') String? countryId,
    @JsonKey(name: 'country_name') String? countryName,
    @JsonKey(name: 'sms_verify_cost_usd', fromJson: _parseDouble)
    @Default(0.0)
    double smsVerifyCostUsd,
    @JsonKey(name: 'call_verify_cost_usd', fromJson: _parseDouble)
    @Default(0.0)
    double callVerifyCostUsd,
    @JsonKey(name: 'is_paid_plan') @Default(false) bool isPaidPlan,
    @JsonKey(name: 'has_annual_allowance') @Default(false) bool hasAnnualAllowance,
    @JsonKey(name: 'allowance_period_end') DateTime? allowancePeriodEnd,
    @JsonKey(name: 'wallet_balance_usd', fromJson: _parseDouble)
    @Default(0.0)
    double walletBalanceUsd,
    @JsonKey(name: 'wallet_available_usd', fromJson: _parseDouble)
    @Default(0.0)
    double walletAvailableUsd,
    @JsonKey(name: 'price_version') @Default(1) int priceVersion,
    @JsonKey(name: 'in_flight_attempt_id') String? inFlightAttemptId,
  }) = _LineVerificationQuote;

  factory LineVerificationQuote.fromJson(Map<String, dynamic> json) =>
      _$LineVerificationQuoteFromJson(json);
}
