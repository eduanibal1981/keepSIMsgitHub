/// Advisory USD arithmetic and validation for server-priced purchases.
/// Published server quotes authorize checkout; device estimates do not.
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

class PremiumInitialBreakdown {
  final double annualFeeUsd;
  final double firstRefillUsd;
  final double totalUsd;
  final int refillIntervalDays;
  final bool isUpgrade;
  final double upgradeCreditUsd;
  final double fullAnnualFeeUsd;

  const PremiumInitialBreakdown({
    required this.annualFeeUsd,
    required this.firstRefillUsd,
    required this.totalUsd,
    required this.refillIntervalDays,
    this.isUpgrade = false,
    this.upgradeCreditUsd = 0.0,
    required this.fullAnnualFeeUsd,
  });

  factory PremiumInitialBreakdown.fromJson(Map<String, dynamic> json) {
    double amount(String key) {
      final value = json[key];
      if (value is! num ||
          !value.isFinite ||
          value < 0 ||
          RefillPricing.round2(value.toDouble()) != value) {
        throw FormatException('Invalid server price: $key');
      }
      return value.toDouble();
    }

    if (json['currency'] != 'USD') {
      throw const FormatException('Unsupported quote currency');
    }
    final fee = amount('annual_fee_usd');
    final refill = amount('first_refill_cost_usd');
    final total = amount('total_charge_usd');
    final credit = amount('upgrade_credit_usd');
    final full = amount('full_annual_fee_usd');
    final interval = json['refill_interval_days'];
    if (interval is! int ||
        interval < 1 ||
        interval > 365 ||
        RefillPricing.round2(fee + refill) != total ||
        RefillPricing.round2(fee + credit) != full ||
        (json['is_upgrade'] == true) != (credit > 0)) {
      throw const FormatException('Inconsistent server price');
    }
    return PremiumInitialBreakdown(
      annualFeeUsd: fee,
      firstRefillUsd: refill,
      totalUsd: total,
      refillIntervalDays: interval,
      isUpgrade: credit > 0,
      upgradeCreditUsd: credit,
      fullAnnualFeeUsd: full,
    );
  }

  double get totalDueNowUsd => totalUsd;
  double get serviceFeeUsd => annualFeeUsd;
  int get recurringRefillDays => refillIntervalDays;
}

class RefillPricing {
  const RefillPricing._();

  /// Rounds half away from zero, matching Postgres `ROUND(numeric, 2)`.
  ///
  /// Dart's `roundToDouble` also rounds half away from zero, but binary
  /// floating point can land a true .005 a hair below the midpoint, so the
  /// scaled value is nudged onto the nearest representable cent first.
  static double round2(double v) {
    if (!v.isFinite) throw ArgumentError('Invalid monetary amount');
    final scaled = v * 100;
    final absolute = scaled.abs();
    final whole = absolute.floorToDouble();
    if ((absolute - whole - .5).abs() < 1e-9) {
      return (scaled < 0 ? -1 : 1) * (whole + 1) / 100;
    }
    return scaled.roundToDouble() / 100;
  }

  /// Advisory wallet-refill arithmetic; percentages use 3 to mean 3%.
  /// [minAppFeeUsd] establishes a minimum floor for the app fee (default $0.03).
  static RefillQuote quote({
    required double baseCostUsd,
    required double appFeePercent,
    double minAppFeeUsd = 0.03,
  }) {
    if (![
      baseCostUsd,
      appFeePercent,
      minAppFeeUsd,
    ].every((v) => v.isFinite && v >= 0)) {
      throw ArgumentError('Invalid USD price inputs');
    }
    // A wallet-funded refill has no second deposit-gateway charge.
    const gatewayFee = 0.0;
    final percentageFee = baseCostUsd * appFeePercent / 100;
    final appFee = round2(
      percentageFee < minAppFeeUsd ? minAppFeeUsd : percentageFee,
    );
    return RefillQuote(
      gatewayFee: gatewayFee,
      appFee: appFee,
      total: round2(baseCostUsd + gatewayFee + appFee),
    );
  }

  /// Days to leave between automated refills on a carrier that terminates a
  /// line after [inactivityLimitDays] without qualifying activity.
  ///
  /// **Mirrors `public.refill_interval_days(integer, integer)`.** The subscriber
  /// is quoted from this function and the scheduler queues from that one; if
  /// they disagree the plan year either runs out early or is overcharged, so
  /// the two must be changed together.
  ///
  /// The margin exists because a refill is not instantaneous or certain: the
  /// worker can fail, the supplier can be down, and the retry sweep needs room
  /// before the carrier reclaims the number. 15% of the window, never less than
  /// a week.
  ///
  /// What this deliberately does *not* consider is `topup_validity_days`. That
  /// is a bundle cycle — how long the credit a refill buys stays spendable — and
  /// letting it set the cadence is what sold a Saudi STC line 13 refills a year
  /// against a carrier that terminates at 180 days. Credit expiring costs the
  /// subscriber money; only the inactivity limit costs them the number.
  static int refillIntervalDays(int inactivityLimitDays, {int? override}) {
    if (override != null && override > 0) {
      return override > 365 ? 365 : override;
    }
    if (inactivityLimitDays < 1) return 0;
    final margin = (inactivityLimitDays * 0.15).ceil();
    final interval = inactivityLimitDays - (margin < 7 ? 7 : margin);
    if (interval < 1) return 1;
    return interval > 365 ? 365 : interval;
  }

  /// Number of due refill occurrences in a 365-day forecast.
  static int refillsPerYear(int inactivityLimitDays, {int? override}) {
    final interval = refillIntervalDays(
      inactivityLimitDays,
      override: override,
    );
    return interval <= 0 ? 0 : (365 / interval).ceil();
  }

  /// What to bill through a gateway so that exactly [net] survives its cut.
  ///
  /// **Grossed up, not marked up.** A gateway charges its percentage on the
  /// *total billed*, so `net * (1 + pct) + fixed` quietly under-recovers —
  /// bill $269.45 on a $260.12 subtotal and PayPal's $9.65 cut leaves $259.80.
  /// Solving `charged - (charged*pct + fixed) = net` leaves exactly [net]
  /// behind. Used for the premium yearly charge and for the Standard service
  /// fee when it falls back from the wallet to PayPal.
  static double grossUpTotal({
    required double net,
    required double gatewayFeePercentage,
    required double gatewayFeeFixed,
  }) {
    if (![
          net,
          gatewayFeePercentage,
          gatewayFeeFixed,
        ].every((v) => v.isFinite && v >= 0) ||
        gatewayFeePercentage >= 100) {
      throw ArgumentError('Invalid gateway price policy');
    }
    if (net == 0) return 0;
    final pct = gatewayFeePercentage / 100;
    return round2((net + gatewayFeeFixed) / (1 - pct));
  }
}
