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

  /// What one premium refill costs, before the gateway takes its cut.
  ///
  /// No gateway fee here on purpose: premium is billed as a **single** yearly
  /// charge, so the gateway is applied once to the whole total in
  /// [premiumYearlyTotal], not once per refill.
  ///
  /// This replaces the stored `carrier_rules.inapp_pricing`, which was a
  /// *snapshot* of the fees when it was written: it baked in $0.30 + 5%
  /// (Stripe's fixed fee, despite premium billing through PayPal) and an 8%
  /// predating `APP_FEE_PERCENT` being 3, and it charged that fixed fee once per
  /// refill — 13x $0.30 to cover one $0.49 charge. Being stored, a renegotiated
  /// rate meant recomputing every carrier row by hand: the opposite of the
  /// "change it in the database, no app update" goal.
  ///
  /// [inappPricingOverride] keeps deliberate per-carrier prices working: a
  /// positive value wins, anything else (including the 0 a null column parses
  /// to) means "compute it".
  static double premiumRefillPrice({
    required double minimumTopupAmount,
    required double appFeePercent,
    double? inappPricingOverride,
  }) {
    if (inappPricingOverride != null && inappPricingOverride > 0) {
      return inappPricingOverride;
    }
    return quote(baseCostUsd: minimumTopupAmount, appFeePercent: appFeePercent)
        .total;
  }

  /// The single up-front charge for a year of premium.
  ///
  /// [premiumMarginPercent] is the margin, stated rather than hidden inside a
  /// mis-applied gateway fee — it is `system_configs.PREMIUM_MARGIN_PERCENT`, so
  /// it moves in one row with no app update.
  ///
  /// The gateway is grossed up, not marked up. The gateway charges its
  /// percentage on the **total billed**, so `net * (1 + pct) + fixed` quietly
  /// under-recovers (bill $269.45 on a $260.12 subtotal and PayPal's $9.65 cut
  /// leaves $259.80). Solving `charged - (charged*pct + fixed) = net` instead
  /// leaves exactly [premiumMarginPercent]-inclusive net in the account.
  static double premiumYearlyTotal({
    required double baseServiceFeeUsd,
    required double minimumTopupAmount,
    required int topupValidityDays,
    required double appFeePercent,
    required double premiumMarginPercent,
    required double gatewayFeePercentage,
    required double gatewayFeeFixed,
    double? inappPricingOverride,
  }) {
    final perRefill = premiumRefillPrice(
      minimumTopupAmount: minimumTopupAmount,
      appFeePercent: appFeePercent,
      inappPricingOverride: inappPricingOverride,
    );
    final net = round2(
      (baseServiceFeeUsd + perRefill * refillsPerYear(topupValidityDays)) *
          (1 + premiumMarginPercent / 100),
    );

    final pct = gatewayFeePercentage / 100;
    // A gateway taking 100% or more can never be covered; charging the raw net
    // is wrong but at least finite, and such a row is a data error, not a price.
    if (pct >= 1) return net;
    return round2((net + gatewayFeeFixed) / (1 - pct));
  }
}
