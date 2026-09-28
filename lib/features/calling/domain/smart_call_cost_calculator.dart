/// KeepSIMs — Smart Call Cost & Savings Calculator
///
/// Pure calculation engine for Smart Call tariff calculations and comparisons.
/// Strictly implements the backend per-second billing policy:
///   cost = ROUND(seconds * ratePerMinute / 60, 4)
/// Avoids arbitrary clamping of negative savings or fabricated carrier rates.
library;

class SavingsCalculationResult {
  final int durationSeconds;
  final double keepSimsRatePerMinute;
  final double keepSimsCost;
  final double? comparisonRatePerMinute;
  final double? comparisonCost;
  final double? savingsAmount;
  final double? savingsPercentage;

  const SavingsCalculationResult({
    required this.durationSeconds,
    required this.keepSimsRatePerMinute,
    required this.keepSimsCost,
    this.comparisonRatePerMinute,
    this.comparisonCost,
    this.savingsAmount,
    this.savingsPercentage,
  });

  bool get hasComparison =>
      comparisonCost != null && comparisonRatePerMinute != null;

  bool get isPositiveSavings => (savingsAmount ?? 0.0) > 0.0001;

  bool get isEqualCost =>
      hasComparison && (savingsAmount ?? 0.0).abs() <= 0.0001;

  bool get isHigherCost => (savingsAmount ?? 0.0) < -0.0001;
}

class SmartCallCostCalculator {
  const SmartCallCostCalculator._();

  /// Computes call cost using per-second billing: (seconds * ratePerMinute) / 60.
  /// Rounds to 4 decimal places matching Supabase billing function.
  static double calculateCost({
    required int seconds,
    required double ratePerMinute,
    double connectionFee = 0.0,
    int billingIncrementSeconds = 1,
  }) {
    if (seconds <= 0 || ratePerMinute <= 0) return 0.0;

    // Apply billing increment if specified (e.g. 60-second minimum or 6-second block)
    final int billedSeconds;
    if (billingIncrementSeconds > 1) {
      billedSeconds =
          ((seconds + billingIncrementSeconds - 1) ~/ billingIncrementSeconds) *
          billingIncrementSeconds;
    } else {
      billedSeconds = seconds;
    }

    final rawCost = (billedSeconds * ratePerMinute / 60.0) + connectionFee;
    return double.parse(rawCost.toStringAsFixed(4));
  }

  /// Evaluates savings compared to a reference roaming rate.
  /// If [comparisonRatePerMinute] is null, only KeepSIMs cost is computed.
  /// Negative savings are preserved honestly and never clamped to 0%.
  static SavingsCalculationResult calculateSavings({
    required int durationSeconds,
    required double keepSimsRatePerMinute,
    double? comparisonRatePerMinute,
    double connectionFee = 0.0,
    int billingIncrementSeconds = 1,
  }) {
    final keepSimsCost = calculateCost(
      seconds: durationSeconds,
      ratePerMinute: keepSimsRatePerMinute,
      connectionFee: connectionFee,
      billingIncrementSeconds: billingIncrementSeconds,
    );

    if (comparisonRatePerMinute == null || comparisonRatePerMinute <= 0) {
      return SavingsCalculationResult(
        durationSeconds: durationSeconds,
        keepSimsRatePerMinute: keepSimsRatePerMinute,
        keepSimsCost: keepSimsCost,
      );
    }

    final comparisonCost = calculateCost(
      seconds: durationSeconds,
      ratePerMinute: comparisonRatePerMinute,
    );

    final savingsAmount = double.parse(
      (comparisonCost - keepSimsCost).toStringAsFixed(4),
    );

    final double savingsPercentage;
    if (comparisonCost > 0) {
      savingsPercentage = (savingsAmount / comparisonCost) * 100.0;
    } else {
      savingsPercentage = 0.0;
    }

    return SavingsCalculationResult(
      durationSeconds: durationSeconds,
      keepSimsRatePerMinute: keepSimsRatePerMinute,
      keepSimsCost: keepSimsCost,
      comparisonRatePerMinute: comparisonRatePerMinute,
      comparisonCost: comparisonCost,
      savingsAmount: savingsAmount,
      savingsPercentage: savingsPercentage,
    );
  }
}
