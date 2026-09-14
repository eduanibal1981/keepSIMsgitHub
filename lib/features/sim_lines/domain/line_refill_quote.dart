import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/features/sim_lines/domain/refill_pricing.dart';

/// A typed, immutable line-refill quote.
///
/// Guarantees that every surface quoting a refill for a specific SIM line
/// (Manual Refill, Depletion Forecast Card, ScheduledTopupSheet) applies
/// the exact fee rule corresponding to the line's effective subscription tier:
/// - Free / Basic: max(7%, $0.50)
/// - Standard:     max(5%, $0.30)
/// - Premium:      max(3%, $0.10)
class LineRefillQuote {
  final String? simLineId;
  final String? offerId;
  final int? offerValue;
  final String effectiveTier;
  final int? feeRuleVersion;
  final double feePercentage;
  final double feeMinimumUsd;
  final double baseCostUsd;
  final double appFeeUsd;
  final double totalUsd;
  final String currency;

  const LineRefillQuote({
    this.simLineId,
    this.offerId,
    this.offerValue,
    required this.effectiveTier,
    this.feeRuleVersion,
    required this.feePercentage,
    required this.feeMinimumUsd,
    required this.baseCostUsd,
    required this.appFeeUsd,
    required this.totalUsd,
    this.currency = 'USD',
  });

  double get appFee => appFeeUsd;
  double get total => totalUsd;

  /// Readable summary for display, e.g. "Base $0.20 · Free fee $0.50"
  String get breakdownText {
    final tierName = switch (effectiveTier.toLowerCase()) {
      'premium' => 'Premium',
      'standard' => 'Standard',
      _ => 'Free',
    };
    return 'Base: \$${baseCostUsd.toStringAsFixed(2)} | $tierName fee: \$${appFeeUsd.toStringAsFixed(2)}';
  }

  /// Compact breakdown for chips and cards, e.g. "Base $0.20 · Fee $0.50"
  String get compactBreakdownText =>
      'Base \$${baseCostUsd.toStringAsFixed(2)} · Fee \$${appFeeUsd.toStringAsFixed(2)}';
}

/// Resolves the fee rule for an effective tier with authoritative fallback constants.
RefillTierFeeRule resolveRefillFeeRule(
  String effectiveTier,
  Map<String, RefillTierFeeRule>? rules,
) {
  final normalizedTier = effectiveTier.toLowerCase().trim();
  if (rules != null && rules.containsKey(normalizedTier)) {
    return rules[normalizedTier]!;
  }
  switch (normalizedTier) {
    case 'standard':
      return const RefillTierFeeRule(percentage: 5.0, minimum: 0.30);
    case 'premium':
      return const RefillTierFeeRule(percentage: 3.0, minimum: 0.10);
    default:
      return const RefillTierFeeRule(percentage: 7.0, minimum: 0.50);
  }
}

/// Computes an authoritative [LineRefillQuote] for a given base cost and line tier.
LineRefillQuote calculateLineRefillQuote({
  String? simLineId,
  String? offerId,
  int? offerValue,
  required String effectiveTier,
  required double baseCostUsd,
  Map<String, RefillTierFeeRule>? rules,
  int? feeRuleVersion,
  String currency = 'USD',
}) {
  final rule = resolveRefillFeeRule(effectiveTier, rules);
  final quote = RefillPricing.quote(
    baseCostUsd: baseCostUsd,
    appFeePercent: rule.percentage,
    minAppFeeUsd: rule.minimum,
  );
  return LineRefillQuote(
    simLineId: simLineId,
    offerId: offerId,
    offerValue: offerValue,
    effectiveTier: effectiveTier,
    feeRuleVersion: feeRuleVersion,
    feePercentage: rule.percentage,
    feeMinimumUsd: rule.minimum,
    baseCostUsd: baseCostUsd,
    appFeeUsd: quote.appFee,
    totalUsd: quote.total,
    currency: currency,
  );
}
