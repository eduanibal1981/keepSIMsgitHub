import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:keep_sims/features/sim_lines/domain/refill_pricing.dart';

part 'carrier_rule_model.freezed.dart';
part 'carrier_rule_model.g.dart';

/// How a carrier decides a prepaid line is still wanted.
///
/// Everything a subscriber pays us for turns on this: how often we refill, how
/// much each refill has to be, and whether refilling helps at all.
@freezed
abstract class CarrierRule with _$CarrierRule {
  const CarrierRule._();

  const factory CarrierRule({
    required String id,
    @JsonKey(name: 'carrier_id') required String carrierId,
    @JsonKey(name: 'rule_type') required String ruleType,

    /// Days from the last qualifying activity until the line is terminated and
    /// the number can be reissued. The cliff the plan year is built around.
    @JsonKey(name: 'inactivity_limit_days') required int inactivityLimitDays,

    /// Window after the cliff in which the same number can still be recovered.
    /// Deliberately not planned against — it is the margin, not the budget.
    @JsonKey(name: 'grace_period_days') required int gracePeriodDays,
    @JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble)
    required double minimumTopupAmount,

    /// Line validity a top-up of [minimumTopupAmount] buys.
    ///
    /// Informational. This used to drive the refill cadence, which is how a
    /// Saudi line whose carrier terminates at 180 days was sold 13 refills a
    /// year: the column held a 30-day *bundle* cycle, not a deactivation
    /// window. Use [refillIntervalDays] for anything that schedules or prices.
    @JsonKey(name: 'topup_validity_days') required int topupValidityDays,
    @JsonKey(name: 'inapp_pricing', fromJson: _parseDouble)
    required double inappPricing,
    @JsonKey(name: 'inapp_pricing_currency')
    required String inappPricingCurrency,
    @JsonKey(name: 'offer_id') String? offerId,
    @JsonKey(name: 'offer_value') int? offerValue,

    /// One of `recharge_ok`, `min_denomination`, `usage_required` — see
    /// [refillAloneKeepsLineActive].
    @JsonKey(name: 'activity_requirement')
    @Default('recharge_ok')
    String activityRequirement,

    /// On a `min_denomination` carrier, the smallest top-up that actually buys
    /// line validity. A refill below this lands as credit and the number still
    /// churns.
    @JsonKey(
      name: 'validity_qualifying_topup_amount',
      fromJson: _parseNullableDouble,
    )
    double? validityQualifyingTopupAmount,

    /// Operator-sourced English explanation of the requirement. Shown as the
    /// detail line under the localised warning at purchase time.
    @JsonKey(name: 'activity_requirement_note') String? activityRequirementNote,

    /// When unused credit is swept. Costs the subscriber money, not the number,
    /// so it never shortens the cadence.
    @JsonKey(name: 'balance_validity_days') int? balanceValidityDays,
    @JsonKey(name: 'refill_interval_days_override') int? refillIntervalDaysOverride,
    @JsonKey(name: 'rule_source_url') String? ruleSourceUrl,
  }) = _CarrierRule;

  factory CarrierRule.fromJson(Map<String, dynamic> json) =>
      _$CarrierRuleFromJson(json);

  /// Days the scheduler leaves between automated refills.
  int get refillIntervalDays => RefillPricing.refillIntervalDays(
    inactivityLimitDays,
    override: refillIntervalDaysOverride,
  );

  /// Refills a premium year pre-pays for on this carrier.
  int get refillsPerYear => RefillPricing.refillsPerYear(
    inactivityLimitDays,
    override: refillIntervalDaysOverride,
  );

  /// Whether sending a refill is, on its own, enough to hold the line.
  ///
  /// False in two shapes. `usage_required` carriers reset their clock on
  /// *consumption* — an outgoing call, SMS or data session — which no amount of
  /// credit we push can substitute for. `min_denomination` carriers sell
  /// validity by voucher tier, so a refill below
  /// [validityQualifyingTopupAmount] buys none. Either way the subscriber has
  /// to be told before they pay us to protect the line.
  bool get refillAloneKeepsLineActive => activityRequirement == 'recharge_ok';

  /// True when only a large enough refill counts — the amount is in
  /// [validityQualifyingTopupAmount].
  bool get requiresQualifyingDenomination =>
      activityRequirement == 'min_denomination';

  /// True when nothing we can send keeps the line: it needs a human to use it.
  bool get requiresHumanUsage => activityRequirement == 'usage_required';
}

double _parseDouble(dynamic value) {
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  if (value is num) {
    return value.toDouble();
  }
  return 0.0;
}

double? _parseNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is String) return double.tryParse(value);
  if (value is num) return value.toDouble();
  return null;
}
