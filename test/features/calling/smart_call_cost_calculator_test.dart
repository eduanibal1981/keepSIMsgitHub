import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/calling/domain/smart_call_cost_calculator.dart';

void main() {
  group('SmartCallCostCalculator', () {
    test('computes exact per-second cost for 1, 59, 60, 61, and 720 seconds', () {
      const rate = 0.60; // $0.60/min = $0.01/sec

      expect(
        SmartCallCostCalculator.calculateCost(seconds: 1, ratePerMinute: rate),
        0.01,
      );
      expect(
        SmartCallCostCalculator.calculateCost(seconds: 59, ratePerMinute: rate),
        0.59,
      );
      expect(
        SmartCallCostCalculator.calculateCost(seconds: 60, ratePerMinute: rate),
        0.60,
      );
      expect(
        SmartCallCostCalculator.calculateCost(seconds: 61, ratePerMinute: rate),
        0.61,
      );
      expect(
        SmartCallCostCalculator.calculateCost(
          seconds: 720,
          ratePerMinute: rate,
        ), // 12 minutes
        7.20,
      );
    });

    test('handles zero or negative duration and rates gracefully', () {
      expect(
        SmartCallCostCalculator.calculateCost(seconds: 0, ratePerMinute: 0.15),
        0.0,
      );
      expect(
        SmartCallCostCalculator.calculateCost(seconds: -10, ratePerMinute: 0.15),
        0.0,
      );
      expect(
        SmartCallCostCalculator.calculateCost(seconds: 60, ratePerMinute: 0.0),
        0.0,
      );
    });

    test('honors billing increments when configured', () {
      const rate = 0.60; // $0.01/sec
      // With 60-second billing increment:
      // 1 second rounds to 60 seconds
      expect(
        SmartCallCostCalculator.calculateCost(
          seconds: 1,
          ratePerMinute: rate,
          billingIncrementSeconds: 60,
        ),
        0.60,
      );
      // 61 seconds rounds to 120 seconds
      expect(
        SmartCallCostCalculator.calculateCost(
          seconds: 61,
          ratePerMinute: rate,
          billingIncrementSeconds: 60,
        ),
        1.20,
      );
    });

    test('calculates positive savings against higher roaming reference', () {
      final result = SmartCallCostCalculator.calculateSavings(
        durationSeconds: 720, // 12 mins
        keepSimsRatePerMinute: 0.548,
        comparisonRatePerMinute: 1.00,
      );

      // KeepSIMs: 720 * 0.548 / 60 = 6.5760
      expect(result.keepSimsCost, 6.576);
      // Comparison: 720 * 1.00 / 60 = 12.0000
      expect(result.comparisonCost, 12.0);
      expect(result.savingsAmount, 5.424);
      expect(result.isPositiveSavings, isTrue);
      expect(result.isHigherCost, isFalse);
      expect(result.savingsPercentage, closeTo(45.2, 0.1));
    });

    test('preserves negative savings honestly without clamping to 0%', () {
      final result = SmartCallCostCalculator.calculateSavings(
        durationSeconds: 300, // 5 mins
        keepSimsRatePerMinute: 0.50,
        comparisonRatePerMinute: 0.20,
      );

      expect(result.keepSimsCost, 2.50);
      expect(result.comparisonCost, 1.00);
      expect(result.savingsAmount, -1.50);
      expect(result.isPositiveSavings, isFalse);
      expect(result.isHigherCost, isTrue);
      expect(result.savingsPercentage, -150.0);
    });

    test('handles absent comparison rate without error', () {
      final result = SmartCallCostCalculator.calculateSavings(
        durationSeconds: 600,
        keepSimsRatePerMinute: 0.15,
        comparisonRatePerMinute: null,
      );

      expect(result.keepSimsCost, 1.50);
      expect(result.hasComparison, isFalse);
      expect(result.comparisonCost, isNull);
      expect(result.savingsAmount, isNull);
    });
  });
}
