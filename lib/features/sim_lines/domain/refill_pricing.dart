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
}
