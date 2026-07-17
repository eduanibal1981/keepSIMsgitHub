/// Refill price quoting, mirroring the `calculate_topup_fees` trigger.
///
/// The price shown before a user confirms and the amount actually debited come
/// from two different machines: this quote runs on the device, while the DB
/// trigger computes the real `topup_executions.amount`. They previously drifted
/// — the client used a hardcoded 3% app fee while the trigger used 5%, so a
/// $5.00 refill displayed "Confirm $5.15" and debited $5.25.
///
/// Keeping them equal needs three things to match, not just the rate:
///   * the rate itself (both now read `system_configs.APP_FEE_PERCENT`),
///   * the order of operations (gateway fee, then app fee, then sum),
///   * the rounding (each component rounded to cents *before* summing).
///
/// The trigger is always the authority on what is charged; this decides only
/// what the user is shown. If the two ever disagree, this class is wrong.
library;

class RefillQuote {
  final double gatewayFee;
  final double appFee;
  final double total;

  const RefillQuote({
    required this.gatewayFee,
    required this.appFee,
    required this.total,
  });
}

class RefillPricing {
  const RefillPricing._();

  /// Rounds half away from zero, matching Postgres `ROUND(numeric, 2)`.
  ///
  /// Dart's `roundToDouble` also rounds half away from zero, but binary
  /// floating point can land a true .005 a hair below the midpoint, so the
  /// scaled value is nudged onto the nearest representable cent first.
  static double round2(double v) {
    final scaled = v * 100;
    final nearest = scaled.roundToDouble();
    if ((scaled - nearest).abs() < 1e-9) return nearest / 100;
    return scaled.roundToDouble() / 100;
  }

  /// [appFeePercent] and [gatewayFeePercentage] are percentages (3 means 3%).
  static RefillQuote quote({
    required double baseCostUsd,
    required double appFeePercent,
    double gatewayFeePercentage = 0,
    double gatewayFeeFixed = 0,
  }) {
    final gatewayFee = round2(
      baseCostUsd * (gatewayFeePercentage / 100) + gatewayFeeFixed,
    );
    final appFee = round2(baseCostUsd * (appFeePercent / 100));
    return RefillQuote(
      gatewayFee: gatewayFee,
      appFee: appFee,
      total: round2(baseCostUsd + gatewayFee + appFee),
    );
  }

  /// Refills a premium subscription pre-pays for in a year.
  static int refillsPerYear(int topupValidityDays) =>
      topupValidityDays <= 0 ? 0 : (365 / topupValidityDays).ceil();

  /// What one premium refill costs the subscriber, before the gateway's cut.
  ///
  ///     cost * (1 + appFee% + margin%) + marginPerRefill
  ///
  /// **No gateway fee here on purpose.** Premium is billed as a *single* yearly
  /// charge, so the gateway is applied once to the whole total in
  /// [premiumYearlyTotal]. The stored `carrier_rules.inapp_pricing` this
  /// replaces did charge it per refill — collecting 13 x $0.324 "for PayPal"
  /// against a bill PayPal only issues once. That surplus was never a fee; it
  /// was margin, which is why it is now named rather than disguised.
  ///
  /// The margin has two parts because one number cannot describe it: it is
  /// worth ~2.6% of a $277 plan but ~41% of a $13 one, since the flat component
  /// does not scale. Hence both [premiumMarginPercent]
  /// (`system_configs.PREMIUM_MARGIN_PERCENT`) and [premiumMarginPerRefillUsd]
  /// (`PREMIUM_MARGIN_PER_REFILL_USD`) — set to 5 and 0.324 they reproduce the
  /// old per-refill price exactly, and either moves in one row with no app
  /// update.
  ///
  /// Returned unrounded: rounding each of ~13 refills before summing would
  /// drift from the yearly total the subscriber is actually charged. Round at
  /// the point of display or payment.
  ///
  /// [inappPricingOverride] keeps deliberate per-carrier prices working: a
  /// positive value wins, anything else (including the 0 a null column parses
  /// to) means "compute it".
  static double premiumRefillPrice({
    required double minimumTopupAmount,
    required double appFeePercent,
    required double premiumMarginPercent,
    required double premiumMarginPerRefillUsd,
    double? inappPricingOverride,
  }) {
    if (inappPricingOverride != null && inappPricingOverride > 0) {
      return inappPricingOverride;
    }
    return minimumTopupAmount *
            (1 + (appFeePercent + premiumMarginPercent) / 100) +
        premiumMarginPerRefillUsd;
  }

  /// The single up-front charge for a year of premium.
  ///
  /// The gateway is **grossed up, not marked up**. It charges its percentage on
  /// the *total billed*, so `net * (1 + pct) + fixed` quietly under-recovers —
  /// bill $269.45 on a $260.12 subtotal and PayPal's $9.65 cut leaves $259.80.
  /// Solving `charged - (charged*pct + fixed) = net` leaves exactly [net]
  /// behind, so the margin above survives contact with the gateway instead of
  /// being eaten by it.
  static double premiumYearlyTotal({
    required double baseServiceFeeUsd,
    required double minimumTopupAmount,
    required int topupValidityDays,
    required double appFeePercent,
    required double premiumMarginPercent,
    required double premiumMarginPerRefillUsd,
    required double gatewayFeePercentage,
    required double gatewayFeeFixed,
    double? inappPricingOverride,
  }) {
    final perRefill = premiumRefillPrice(
      minimumTopupAmount: minimumTopupAmount,
      appFeePercent: appFeePercent,
      premiumMarginPercent: premiumMarginPercent,
      premiumMarginPerRefillUsd: premiumMarginPerRefillUsd,
      inappPricingOverride: inappPricingOverride,
    );
    final net = baseServiceFeeUsd + perRefill * refillsPerYear(topupValidityDays);

    final pct = gatewayFeePercentage / 100;
    // A gateway taking 100% or more can never be covered; charging the raw net
    // is wrong but at least finite, and such a row is a data error, not a price.
    if (pct >= 1) return round2(net);
    return round2((net + gatewayFeeFixed) / (1 - pct));
  }
}
