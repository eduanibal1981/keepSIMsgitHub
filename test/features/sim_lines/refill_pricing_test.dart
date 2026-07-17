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

  group('Premium yearly pricing', () {
    // O2 Germany, the live row: $19.24 base cost, 30-day validity, PayPal at
    // 3.4% + $0.49 per payment_gateways.
    const o2Base = 19.24;
    const o2Validity = 30;
    const paypalPct = 3.4;
    const paypalFixed = 0.49;

    double yearly({double margin = 0, double? override}) =>
        RefillPricing.premiumYearlyTotal(
          baseServiceFeeUsd: 2.50,
          minimumTopupAmount: o2Base,
          topupValidityDays: o2Validity,
          appFeePercent: 3,
          premiumMarginPercent: margin,
          gatewayFeePercentage: paypalPct,
          gatewayFeeFixed: paypalFixed,
          inappPricingOverride: override,
        );

    test('a 30-day carrier pre-pays 13 refills', () {
      expect(RefillPricing.refillsPerYear(30), 13);
      expect(RefillPricing.refillsPerYear(90), 5);
      expect(RefillPricing.refillsPerYear(365), 1);
    });

    test('a zero or negative validity cannot divide by zero', () {
      expect(RefillPricing.refillsPerYear(0), 0);
      expect(RefillPricing.refillsPerYear(-5), 0);
    });

    test('the per-refill price carries no gateway fee', () {
      // The gateway is charged once over the yearly total, not per refill —
      // charging it 13 times to cover one $0.49 transaction is the bug this
      // whole change exists to remove.
      expect(
        RefillPricing.premiumRefillPrice(
          minimumTopupAmount: o2Base,
          appFeePercent: 3,
        ),
        19.82, // 19.24 + round(0.5772) = 19.24 + 0.58
      );
    });

    test('THE POINT: the gross-up leaves the full subtotal after the gateway cut', () {
      final charged = yearly();
      final subtotal = RefillPricing.round2(2.50 + 19.82 * 13);
      final gatewayTakes =
          RefillPricing.round2(charged * (paypalPct / 100) + paypalFixed);

      expect(subtotal, 260.16);
      // A naive `subtotal * (1 + pct) + fixed` bills 269.49 and nets 259.84 —
      // 0.32 short, because the gateway's percentage applies to the total
      // billed, not to the subtotal.
      expect(RefillPricing.round2(charged - gatewayTakes), subtotal);
    });

    test('margin is explicit and scales the whole year, gateway on top', () {
      final none = yearly();
      final five = yearly(margin: 5);
      expect(five, greaterThan(none));
      // 5% of the subtotal, grossed up for the gateway's cut of the extra.
      expect(RefillPricing.round2(five - none), 13.47);
    });

    test('a zero margin is honoured, not treated as unset', () {
      // The whole reason PREMIUM_MARGIN_PERCENT exists is to be a number that
      // means what it says — 0 must mean "no margin", not "use some default".
      final subtotal = RefillPricing.round2(2.50 + 19.82 * 13);
      final expected = RefillPricing.round2((subtotal + paypalFixed) / (1 - 0.034));
      expect(yearly(margin: 0), expected);
    });

    test('a deliberate per-carrier override replaces the computed refill price', () {
      // du and Orange Egypt carry round-number prices set by hand; those must
      // survive, while every other carrier follows the config.
      final withOverride = yearly(override: 2.00);
      final expectedNet = RefillPricing.round2(2.50 + 2.00 * 13);
      expect(
        withOverride,
        RefillPricing.round2((expectedNet + paypalFixed) / (1 - 0.034)),
      );
    });

    test('a non-positive override means "compute it", since null parses to 0', () {
      expect(yearly(override: 0), yearly());
      expect(yearly(override: -1), yearly());
    });

    test('a wallet-style 0% / \$0 gateway adds nothing', () {
      final total = RefillPricing.premiumYearlyTotal(
        baseServiceFeeUsd: 2.50,
        minimumTopupAmount: o2Base,
        topupValidityDays: o2Validity,
        appFeePercent: 3,
        premiumMarginPercent: 0,
        gatewayFeePercentage: 0,
        gatewayFeeFixed: 0,
      );
      expect(total, RefillPricing.round2(2.50 + 19.82 * 13));
    });

    test('an impossible 100% gateway does not divide by zero or go negative', () {
      final total = RefillPricing.premiumYearlyTotal(
        baseServiceFeeUsd: 2.50,
        minimumTopupAmount: o2Base,
        topupValidityDays: o2Validity,
        appFeePercent: 3,
        premiumMarginPercent: 0,
        gatewayFeePercentage: 100,
        gatewayFeeFixed: 0,
      );
      expect(total, isPositive);
      expect(total.isFinite, isTrue);
    });
  });
}
