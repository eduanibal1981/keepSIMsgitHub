import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/features/sim_lines/domain/line_refill_quote.dart';

void main() {
  group('LineRefillQuote & calculateLineRefillQuote — Tier-Aware Pricing', () {
    const double baseCostUsd = 0.20;

    test('Free / Basic tier on \$0.20 base uses \$0.50 minimum floor -> \$0.70 total', () {
      final quote = calculateLineRefillQuote(
        effectiveTier: 'free',
        baseCostUsd: baseCostUsd,
      );
      expect(quote.effectiveTier, 'free');
      expect(quote.baseCostUsd, 0.20);
      expect(quote.appFeeUsd, 0.50);
      expect(quote.totalUsd, 0.70);
      expect(quote.total, 0.70);
      expect(quote.appFee, 0.50);
      expect(quote.breakdownText, 'Base: \$0.20 | Free fee: \$0.50');
    });

    test('Standard tier on \$0.20 base uses \$0.30 minimum floor -> \$0.50 total', () {
      final quote = calculateLineRefillQuote(
        effectiveTier: 'standard',
        baseCostUsd: baseCostUsd,
      );
      expect(quote.effectiveTier, 'standard');
      expect(quote.baseCostUsd, 0.20);
      expect(quote.appFeeUsd, 0.30);
      expect(quote.totalUsd, 0.50);
      expect(quote.breakdownText, 'Base: \$0.20 | Standard fee: \$0.30');
    });

    test('Premium tier on \$0.20 base uses \$0.10 minimum floor -> \$0.30 total', () {
      final quote = calculateLineRefillQuote(
        effectiveTier: 'premium',
        baseCostUsd: baseCostUsd,
      );
      expect(quote.effectiveTier, 'premium');
      expect(quote.baseCostUsd, 0.20);
      expect(quote.appFeeUsd, 0.10);
      expect(quote.totalUsd, 0.30);
      expect(quote.breakdownText, 'Base: \$0.20 | Premium fee: \$0.10');
    });

    test('Percentage fee applies when it exceeds minimum floor on larger refill amounts', () {
      const double largeBaseCost = 10.00;

      // Free tier: 7% of $10.00 = $0.70 (> $0.50 min)
      final freeQuote = calculateLineRefillQuote(
        effectiveTier: 'free',
        baseCostUsd: largeBaseCost,
      );
      expect(freeQuote.appFeeUsd, 0.70);
      expect(freeQuote.totalUsd, 10.70);

      // Standard tier: 5% of $10.00 = $0.50 (> $0.30 min)
      final standardQuote = calculateLineRefillQuote(
        effectiveTier: 'standard',
        baseCostUsd: largeBaseCost,
      );
      expect(standardQuote.appFeeUsd, 0.50);
      expect(standardQuote.totalUsd, 10.50);

      // Premium tier: 3% of $10.00 = $0.30 (> $0.10 min)
      final premiumQuote = calculateLineRefillQuote(
        effectiveTier: 'premium',
        baseCostUsd: largeBaseCost,
      );
      expect(premiumQuote.appFeeUsd, 0.30);
      expect(premiumQuote.totalUsd, 10.30);
    });

    test('Custom loaded rules map is respected if provided', () {
      final customRules = {
        'free': const RefillTierFeeRule(percentage: 8.0, minimum: 0.60),
      };
      final quote = calculateLineRefillQuote(
        effectiveTier: 'free',
        baseCostUsd: 0.20,
        rules: customRules,
      );
      expect(quote.feePercentage, 8.0);
      expect(quote.feeMinimumUsd, 0.60);
      expect(quote.appFeeUsd, 0.60);
      expect(quote.totalUsd, 0.80);
    });

    test('Unrecognized tier string falls back to free tier safely', () {
      final quote = calculateLineRefillQuote(
        effectiveTier: 'unknown_tier',
        baseCostUsd: 0.20,
      );
      expect(quote.feePercentage, 7.0);
      expect(quote.feeMinimumUsd, 0.50);
      expect(quote.appFeeUsd, 0.50);
      expect(quote.totalUsd, 0.70);
    });
  });
}
