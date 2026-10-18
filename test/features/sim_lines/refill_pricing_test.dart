import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/domain/refill_pricing.dart';

/// Advisory USD arithmetic and server quote validation; no production writes.
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

    test('wallet refill does not add a deposit gateway charge', () {
      final q = RefillPricing.quote(baseCostUsd: 10.00, appFeePercent: 3);
      expect(q.gatewayFee, 0);
      expect(q.appFee, 0.30);
      expect(q.total, 10.30);
    });

    test('wallet refill rounds its app fee before summing', () {
      final q = RefillPricing.quote(baseCostUsd: 7.77, appFeePercent: 3);
      expect(q.gatewayFee, 0);
      expect(q.appFee, 0.23);
      expect(q.total, 8);
    });

    test('enforces MIN_APP_FEE_USD floor (\$0.03) on micro-topups', () {
      // Base cost 0.20: 3% of 0.20 is 0.006 (0.01 rounded).
      // Floor lifts it to $0.03, resulting in total $0.23.
      final q = RefillPricing.quote(
        baseCostUsd: 0.20,
        appFeePercent: 3,
        minAppFeeUsd: 0.03,
      );
      expect(q.appFee, 0.03);
      expect(q.total, 0.23);
    });

    test('a zero app fee is honoured, not treated as unset', () {
      final q = RefillPricing.quote(
        baseCostUsd: 5.00,
        appFeePercent: 0,
        minAppFeeUsd: 0,
      );
      expect(q.appFee, 0.00);
      expect(q.total, 5.00);
    });

    test('rounds half away from zero like Postgres ROUND', () {
      // 2.50 * 3% = 0.075 -> 0.08, not 0.07 (banker's rounding would give .08
      // here too, but 0.125 -> 0.13 distinguishes them).
      expect(RefillPricing.round2(0.075), 0.08);
      expect(RefillPricing.round2(0.125), 0.13);
      expect(RefillPricing.round2(0.135), 0.14);
      expect(RefillPricing.round2(0.285), 0.29);
      expect(RefillPricing.round2(-0.285), -0.29);
    });
  });

  group('grossUpTotal — the Standard fee PayPal fallback (C3c)', () {
    // payment_gateways live row: paypal 3.4% + $0.49.
    const paypalPct = 3.4;
    const paypalFixed = 0.49;

    test('THE POINT: billing the grossed-up total nets exactly the fee', () {
      // A standalone $2.50 Standard charge through PayPal must bill ~$3.10 so
      // that after PayPal takes 3.4% of the TOTAL plus $0.49, exactly $2.50
      // survives. Billing $2.50 flat nets $1.93 — a 23% loss.
      final charged = RefillPricing.grossUpTotal(
        net: 2.50,
        gatewayFeePercentage: paypalPct,
        gatewayFeeFixed: paypalFixed,
      );
      expect(charged, 3.10); // (2.50 + 0.49) / (1 - 0.034) = 3.0952 -> 3.10
      final gatewayTakes = RefillPricing.round2(
        charged * (paypalPct / 100) + paypalFixed,
      );
      expect(RefillPricing.round2(charged - gatewayTakes), closeTo(2.50, 0.01));
    });

    test('a wallet-style 0% / \$0 gateway grosses up to the net itself', () {
      expect(
        RefillPricing.grossUpTotal(
          net: 2.50,
          gatewayFeePercentage: 0,
          gatewayFeeFixed: 0,
        ),
        2.50,
      );
    });

    test(
      'invalid gateway policy blocks a price instead of returning the net',
      () {
        expect(
          () => RefillPricing.grossUpTotal(
            net: 2.5,
            gatewayFeePercentage: 100,
            gatewayFeeFixed: 0,
          ),
          throwsArgumentError,
        );
        expect(
          () => RefillPricing.grossUpTotal(
            net: 2.5,
            gatewayFeePercentage: -1,
            gatewayFeeFixed: 0,
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('retail server Premium quote', () {
    Map<String, dynamic> quote() => {
      'currency': 'USD',
      'annual_fee_usd': 3.75,
      'first_refill_cost_usd': 1.10,
      'total_charge_usd': 4.85,
      'full_annual_fee_usd': 5.0,
      'upgrade_credit_usd': 1.25,
      'is_upgrade': true,
      'refill_interval_days': 76,
    };
    test('uses settled discounted upgrade credit and one first refill', () {
      final result = PremiumInitialBreakdown.fromJson(quote());
      expect(result.totalDueNowUsd, 4.85);
      expect(result.annualFeeUsd, 3.75);
      expect(result.upgradeCreditUsd, 1.25);
    });
    for (final field in [
      'annual_fee_usd',
      'total_charge_usd',
      'full_annual_fee_usd',
      'upgrade_credit_usd',
      'currency',
      'refill_interval_days',
    ]) {
      test('missing $field cannot invent a fallback checkout', () {
        final value = quote()..remove(field);
        expect(
          () => PremiumInitialBreakdown.fromJson(value),
          throwsFormatException,
        );
      });
    }
    test(
      'changed total, invalid amount, cadence or foreign currency are refused',
      () {
        for (final patch in [
          {'total_charge_usd': 2.5},
          {'annual_fee_usd': double.nan},
          {'annual_fee_usd': -1},
          {'currency': 'OMR'},
          {'refill_interval_days': 0},
          {'upgrade_credit_usd': 2.5},
        ]) {
          expect(
            () => PremiumInitialBreakdown.fromJson({...quote(), ...patch}),
            throwsFormatException,
          );
        }
      },
    );
    test('a published zero membership charge is preserved', () {
      final result = PremiumInitialBreakdown.fromJson({
        ...quote(),
        'annual_fee_usd': 0,
        'full_annual_fee_usd': 0,
        'upgrade_credit_usd': 0,
        'is_upgrade': false,
        'total_charge_usd': 1.1,
      });
      expect(result.annualFeeUsd, 0);
      expect(result.totalUsd, 1.1);
    });
  });
  test('zero percentage still honors a published positive minimum', () {
    expect(
      RefillPricing.quote(
        baseCostUsd: .2,
        appFeePercent: 0,
        minAppFeeUsd: .3,
      ).total,
      .5,
    );
  });
  test('cadence follows the termination window and explicit override', () {
    expect(RefillPricing.refillIntervalDays(90), 76);
    expect(RefillPricing.refillIntervalDays(180), 153);
    expect(RefillPricing.refillIntervalDays(30), 23);
    expect(RefillPricing.refillIntervalDays(365, override: 14), 14);
    expect(RefillPricing.refillIntervalDays(0), 0);
    expect(RefillPricing.refillsPerYear(90), 5);
  });
}
