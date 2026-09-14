/// SIM Shield — Depletion Forecast Model (G1)
///
/// Maps to the `sim_line_usage_forecast` table, which is derived data written
/// nightly by `refresh_usage_forecasts()`. The client can only read it.
///
/// [method] and [confidence] exist so the UI never presents a fallback guess as
/// if it were a measurement: `topup_history` is fitted from the line's own
/// refills, `carrier_rule` is the carrier's published window, and `default` is
/// a configured constant with nothing behind it.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'usage_forecast_model.freezed.dart';
part 'usage_forecast_model.g.dart';

@freezed
abstract class UsageForecast with _$UsageForecast {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory UsageForecast({
    required String id,
    required String userId,
    String? simLineId,
    String? esimId,
    required String subjectKind,
    required String method,
    required String confidence,
    @Default(0) int samplesCount,
    double? observedIntervalDays,
    double? mbPerDay,
    int? effectiveValidityDays,
    DateTime? predictedDepletionAt,
    int? daysRemaining,
    int? suggestedFrequencyDays,
    double? suggestedAmountUsd,
    String? suggestedOfferId,
    @Default(7) int alertLeadDays,
    DateTime? lastAlertAt,
    DateTime? computedAt,
  }) = _UsageForecast;

  const UsageForecast._();

  factory UsageForecast.fromJson(Map<String, dynamic> json) =>
      _$UsageForecastFromJson(json);

  /// True when the number came from this line's own refill history rather than
  /// from a carrier default. Drives the "measured" vs "estimated" wording.
  bool get isMeasured => method == 'topup_history' || method == 'esim_usage';

  /// The prediction is inside the alert window — the line needs attention now.
  bool get isUrgent =>
      daysRemaining != null && daysRemaining! <= alertLeadDays;

  /// The frequency chip to preselect in [ScheduledTopupSheet].
  ///
  /// Returns the exact carrier-derived or calculated cadence (e.g. 76 days).
  int? suggestedChipFor({bool isPremium = false}) {
    return suggestedFrequencyDays;
  }
}
