import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/domain/refill_pricing.dart';

/// These numbers are not invented: each expectation below was produced by
/// inserting the same row into `topup_executions` on the live database and
/// reading back what `calculate_topup_fees` wrote. The client quote and the
/// trigger drifted apart once already (3% here vs 5% there, so a $5.00 refill
/// showed $5.15 and debited $5.25); this pins them together.
void main() {
  group('RefillPricing.quote — matches calculate_topup_fees', () {
    test('wallet gateway (0% + \$0.00) at the configured 3% app fee', () {
      // Verified live: base 5.00 -> amount 5.15, app_fee_usd 0.15.
      final q = RefillPricing.quote(baseCostUsd: 5.00, appFeePercent: 3);
      expect(q.gatewayFee, 0.00);
      expect(q.appFee, 0.15);
      expect(q.total, 5.15);
    });

    test('follows the configured rate rather than a constant', () {
      // Verified live after setting APP_FEE_PERCENT=7: base 5.00 -> 5.35.
      final q = RefillPricing.quote(baseCostUsd: 5.00, appFeePercent: 7);
      expect(q.appFee, 0.35);
      expect(q.total, 5.35);
    });

    test('the old 5% behaviour is what 3% must NOT produce', () {
      // Guards the exact regression: quoting 3% while the DB charged 5% is how
      // every refill silently overcharged by a dime on a $5 top-up.
      final atThree = RefillPricing.quote(baseCostUsd: 5.00, appFeePercent: 3);
      final atFive = RefillPricing.quote(baseCostUsd: 5.00, appFeePercent: 5);
      expect(atFive.total, 5.25);
      expect(atThree.total, isNot(atFive.total));
    });

    test('paypal gateway (3.4% + \$0.49) rounds each component before summing', () {
      // base 10.00: gateway = round(0.34 + 0.49) = 0.83, app = round(0.30) =
      // 0.30, total = 11.13. Summing before rounding would also give 11.13
      // here, so the ordering is pinned by the awkward case below instead.
      final q = RefillPricing.quote(
        baseCostUsd: 10.00,
        appFeePercent: 3,
        gatewayFeePercentage: 3.4,
        gatewayFeeFixed: 0.49,
      );
      expect(q.gatewayFee, 0.83);
      expect(q.appFee, 0.30);
      expect(q.total, 11.13);
    });

    test('stripe gateway (4.5% + \$0.30) on an amount with a sub-cent app fee', () {
      // base 7.77: gateway = round(0.34965 + 0.30) = 0.65,
      // app = round(0.2331) = 0.23, total = round(7.77+0.65+0.23) = 8.65.
      // The trigger rounds each component first, so 0.2331 must become 0.23
      // and not survive into the sum at full precision.
      final q = RefillPricing.quote(
        baseCostUsd: 7.77,
        appFeePercent: 3,
        gatewayFeePercentage: 4.5,
        gatewayFeeFixed: 0.30,
      );
      expect(q.gatewayFee, 0.65);
      expect(q.appFee, 0.23);
      expect(q.total, 8.65);
    });

    test('a zero app fee is honoured, not treated as unset', () {
      final q = RefillPricing.quote(baseCostUsd: 5.00, appFeePercent: 0);
      expect(q.appFee, 0.00);
      expect(q.total, 5.00);
    });

    test('rounds half away from zero like Postgres ROUND', () {
      // 2.50 * 3% = 0.075 -> 0.08, not 0.07 (banker's rounding would give .08
      // here too, but 0.125 -> 0.13 distinguishes them).
      expect(RefillPricing.round2(0.075), 0.08);
      expect(RefillPricing.round2(0.125), 0.13);
      expect(RefillPricing.round2(0.135), 0.14);
    });
  });
}
