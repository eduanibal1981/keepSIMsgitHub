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
      final gatewayTakes =
          RefillPricing.round2(charged * (paypalPct / 100) + paypalFixed);
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

    test('an impossible 100% gateway stays finite', () {
      final total = RefillPricing.grossUpTotal(
        net: 2.50,
        gatewayFeePercentage: 100,
        gatewayFeeFixed: 0,
      );
      expect(total, isPositive);
      expect(total.isFinite, isTrue);
    });
  });

  group('Premium yearly pricing', () {
    // O2 Germany, the live row: $19.24 base cost, 30-day validity, PayPal at
    // 3.4% + $0.49 per payment_gateways.
    const o2Base = 19.24;
    // O2 Germany terminates a prepaid line after six months without a top-up.
    // refillIntervalDays(180) = 153, so a plan year pre-pays 3 refills — not the
    // 13 the old bundle-cycle cadence billed for.
    const o2InactivityDays = 180;
    const o2Refills = 3;
    const paypalPct = 3.4;
    const paypalFixed = 0.49;

    // The live config: margin is 5% of cost + $0.324 flat per refill.
    const marginPct = 5.0;
    const marginFlat = 0.324;

    double yearly({
      double margin = 0,
      double flat = 0,
      double? override,
    }) => RefillPricing.premiumYearlyTotal(
      baseServiceFeeUsd: 2.50,
      minimumTopupAmount: o2Base,
      inactivityLimitDays: o2InactivityDays,
      appFeePercent: 3,
      premiumMarginPercent: margin,
      premiumMarginPerRefillUsd: flat,
      gatewayFeePercentage: paypalPct,
      gatewayFeeFixed: paypalFixed,
      inappPricingOverride: override,
    );

    test('cadence comes off the deactivation window, with a safety margin', () {
      // 15% of the window, floored at a week, so a failed refill still has room
      // for the retry sweep before the carrier reclaims the number.
      expect(RefillPricing.refillIntervalDays(90), 76); // 90 - 14
      expect(RefillPricing.refillIntervalDays(180), 153); // 180 - 27
      expect(RefillPricing.refillIntervalDays(330), 280); // 330 - 50
      // Short windows get the 7-day floor rather than a proportional sliver.
      expect(RefillPricing.refillIntervalDays(30), 23);
    });

    test('STC Saudi Arabia: 3 refills a year, not 13', () {
      // The regression this phase exists to fix. stc extends SIM validity 180
      // days from the last paid activity; the rule row previously carried a
      // 30-day bundle cycle, so the plan sold 13 refills at $7.07 for a line
      // that needs 3.
      expect(RefillPricing.refillsPerYear(180), 3);
      // What the old cadence produced, for contrast.
      expect(RefillPricing.refillsPerYear(37), 13);
    });

    test('an explicit override wins and is clamped to a year', () {
      expect(RefillPricing.refillIntervalDays(90, override: 45), 45);
      expect(RefillPricing.refillIntervalDays(90, override: 900), 365);
      // Non-positive means "no override", not "interval zero".
      expect(RefillPricing.refillIntervalDays(90, override: 0), 76);
    });

    test('a zero or negative window cannot divide by zero', () {
      expect(RefillPricing.refillsPerYear(0), 0);
      expect(RefillPricing.refillsPerYear(-5), 0);
      expect(RefillPricing.refillIntervalDays(0), 0);
    });

    test('a derived interval is never mistaken for a schedule chip label', () {
      // RefillScheduleMath.safetyAdjustedDelayDays maps the chip labels 90/30/14
      // to their execution days 85/28/13, because a chip means "the carrier's
      // window". A derived interval already has the margin taken out, so if one
      // ever lands exactly on a chip label it would be adjusted a second time —
      // the schedule would then fire days apart from the pre-paid executions
      // queue_premium_refill_executions lays down at the un-remapped interval.
      //
      // No carrier rule in the table hits this today — the windows in use are
      // 30, 90, 95, 120, 150, 180, 184, 330, 365 and 700. This test is the
      // tripwire for the admin RPC letting someone set one of the six windows
      // below, which derive exactly onto a chip label.
      const chipLabels = {90, 30, 14, 85};
      final offenders = <int>[];
      for (var window = 1; window <= 730; window++) {
        final interval = RefillPricing.refillIntervalDays(window);
        if (chipLabels.contains(interval)) offenders.add(window);
      }
      expect(
        offenders,
        // 21→14, 37→30, 100/101→85, 106/107→90.
        [21, 37, 100, 101, 106, 107],
        reason:
            'These windows derive an interval that collides with a chip label. '
            'They are unreachable from current carrier data; if a rule ever '
            'uses one, either give it refill_interval_days_override or teach '
            'the sheet to stop re-adjusting carrier-derived intervals.',
      );
    });

    test('the per-refill price carries no gateway fee', () {
      // The gateway is charged once over the yearly total, not per refill —
      // collecting it 13 times against one $0.49 transaction is the surplus
      // this whole change exists to expose as margin.
      expect(
        RefillPricing.premiumRefillPrice(
          minimumTopupAmount: o2Base,
          appFeePercent: 3,
          premiumMarginPercent: 0,
          premiumMarginPerRefillUsd: 0,
        ),
        closeTo(19.8172, 0.0001), // 19.24 * 1.03, unrounded
      );
    });

    test('THE POINT: margin 5% + \$0.324 reproduces the old stored price exactly', () {
      // carrier_rules.inapp_pricing held 21.1032 for O2 Germany, derived as
      // (19.24 + 0.30) * 1.08. Decomposed honestly that is
      // cost + 3% app fee + (5% cost + 0.324) margin — same number, but now
      // every term is named and lives in a config row.
      expect(
        RefillPricing.premiumRefillPrice(
          minimumTopupAmount: o2Base,
          appFeePercent: 3,
          premiumMarginPercent: marginPct,
          premiumMarginPerRefillUsd: marginFlat,
        ),
        closeTo(21.1032, 0.0001),
      );
    });

    test('THE POINT: the gross-up leaves the full subtotal after the gateway cut', () {
      final charged = yearly(margin: marginPct, flat: marginFlat);
      const subtotal = 2.50 + 21.1032 * o2Refills;
      final gatewayTakes =
          RefillPricing.round2(charged * (paypalPct / 100) + paypalFixed);

      // A naive `subtotal * (1 + pct) + fixed` under-recovers, because the
      // gateway's percentage applies to the total billed, not to the subtotal.
      expect(
        RefillPricing.round2(charged - gatewayTakes),
        closeTo(RefillPricing.round2(subtotal), 0.01),
      );
    });

    test('both margin parts are needed: the flat part does not scale', () {
      // A cheap carrier and an expensive one get the same flat margin but very
      // different percentage margins — which is exactly why one knob could not
      // express this and the old "PayPal fee" looked like 2.6% here and 41%
      // there.
      double perRefill(double cost) => RefillPricing.premiumRefillPrice(
        minimumTopupAmount: cost,
        appFeePercent: 3,
        premiumMarginPercent: marginPct,
        premiumMarginPerRefillUsd: marginFlat,
      );
      expect(perRefill(19.24) - 19.24 * 1.08, closeTo(marginFlat, 0.0001));
      expect(perRefill(0.48) - 0.48 * 1.08, closeTo(marginFlat, 0.0001));
    });

    test('a zero margin is honoured, not treated as unset', () {
      // The whole reason these configs exist is to be numbers that mean what
      // they say — 0 must mean "no margin", not "use some default".
      const subtotal = 2.50 + 19.24 * 1.03 * o2Refills;
      expect(
        yearly(margin: 0, flat: 0),
        RefillPricing.round2((subtotal + paypalFixed) / (1 - 0.034)),
      );
    });

    test('a deliberate per-carrier override replaces the computed refill price', () {
      // du and Orange Egypt carry round-number prices set by hand; those must
      // survive, while every other carrier follows the config.
      final withOverride = yearly(margin: marginPct, flat: marginFlat, override: 2.00);
      const expectedNet = 2.50 + 2.00 * o2Refills;
      expect(
        withOverride,
        RefillPricing.round2((expectedNet + paypalFixed) / (1 - 0.034)),
      );
    });

    test('a non-positive override means "compute it", since null parses to 0', () {
      expect(yearly(margin: marginPct, flat: marginFlat, override: 0),
          yearly(margin: marginPct, flat: marginFlat));
      expect(yearly(margin: marginPct, flat: marginFlat, override: -1),
          yearly(margin: marginPct, flat: marginFlat));
    });

    test('a wallet-style 0% / \$0 gateway adds nothing', () {
      final total = RefillPricing.premiumYearlyTotal(
        baseServiceFeeUsd: 2.50,
        minimumTopupAmount: o2Base,
        inactivityLimitDays: o2InactivityDays,
        appFeePercent: 3,
        premiumMarginPercent: 0,
        premiumMarginPerRefillUsd: 0,
        gatewayFeePercentage: 0,
        gatewayFeeFixed: 0,
      );
      expect(total, RefillPricing.round2(2.50 + 19.24 * 1.03 * o2Refills));
    });

    test('an impossible 100% gateway does not divide by zero or go negative', () {
      final total = RefillPricing.premiumYearlyTotal(
        baseServiceFeeUsd: 2.50,
        minimumTopupAmount: o2Base,
        inactivityLimitDays: o2InactivityDays,
        appFeePercent: 3,
        premiumMarginPercent: 0,
        premiumMarginPerRefillUsd: 0,
        gatewayFeePercentage: 100,
        gatewayFeeFixed: 0,
      );
      expect(total, isPositive);
      expect(total.isFinite, isTrue);
    });
  });

  // J8. The two rails a Premium year can be bought on, pinned to the live Zain
  // KSA rule (min top-up $1.00, 90-day inactivity window) and to what
  // `public.plan_price_net` / `public.quote_plan_price` return for it. If one
  // of these fails, the app and the database disagree about a price, which is
  // the class of bug that charged $21.99 for a $10.36 plan.
  group('premium: the wallet rail and the PayPal rail (Zain KSA)', () {
    const baseFee = 2.50;
    const minTopup = 1.00; // carrier_rules.minimum_topup_amount
    const window = 90; // carrier_rules.inactivity_limit_days
    const appFeePct = 3.0; // APP_FEE_PERCENT
    const marginPct = 5.0; // PREMIUM_MARGIN_PERCENT
    const marginFlat = 0.324; // PREMIUM_MARGIN_PER_REFILL_USD
    const paypalPct = 3.4;
    const paypalFixed = 0.49;

    double total({required double gwPct, required double gwFixed}) =>
        RefillPricing.premiumYearlyTotal(
          baseServiceFeeUsd: baseFee,
          minimumTopupAmount: minTopup,
          inactivityLimitDays: window,
          appFeePercent: appFeePct,
          premiumMarginPercent: marginPct,
          premiumMarginPerRefillUsd: marginFlat,
          gatewayFeePercentage: gwPct,
          gatewayFeeFixed: gwFixed,
        );

    test('five refills a year, not the thirteen the bundle cycle implied', () {
      // The rule's topup_validity_days is 30, which is what quote_plan_price
      // divided 365 by until J8 — 13 refills against a 90-day deactivation
      // window that only needs 5.
      expect(RefillPricing.refillIntervalDays(window), 76);
      expect(RefillPricing.refillsPerYear(window), 5);
    });

    test('the wallet debits the net: \$9.52, matching plan_price_net', () {
      // Verified against the live database on 2026-08-08:
      //   SELECT public.plan_price_net('premium', NULL, '997ca983-…') → 9.52
      expect(total(gwPct: 0, gwFixed: 0), 9.52);
    });

    test('PayPal is grossed up to \$10.36, matching quote_plan_price', () {
      //   SELECT public.quote_plan_price(NULL,'premium','paypal','997ca983-…')
      //     → 10.36   (was 21.99 before J8)
      expect(total(gwPct: paypalPct, gwFixed: paypalFixed), 10.36);
    });

    test('buying from the wallet is cheaper than buying through PayPal', () {
      // Not a rounding accident: it is the reason both tiers bill wallet-first.
      expect(
        total(gwPct: 0, gwFixed: 0),
        lessThan(total(gwPct: paypalPct, gwFixed: paypalFixed)),
      );
    });

    test('the PayPal charge covers the gateway fee, it does not absorb it', () {
      // The bug this pins: the add-line sheet computed the grossed-up total,
      // printed it on the button, and then opened checkout for the *net* — so
      // PayPal billed $9.52 against a button that said $10.36, and KeepSIMs
      // paid the $0.81 cut. Whatever is charged must leave the plan price
      // behind after the gateway takes its percentage and fixed fee.
      final charged = total(gwPct: paypalPct, gwFixed: paypalFixed);
      final keptAfterPayPal = charged - (charged * paypalPct / 100 + paypalFixed);
      expect(RefillPricing.round2(keptAfterPayPal), 9.52);

      // And the net alone does NOT survive its own fee — the shape of the bug.
      final undercharged = total(gwPct: 0, gwFixed: 0);
      final wouldKeep =
          undercharged - (undercharged * paypalPct / 100 + paypalFixed);
      expect(RefillPricing.round2(wouldKeep), lessThan(9.52));
    });

    test('Standard through PayPal is \$3.10, matching quote_plan_price', () {
      // SELECT public.quote_plan_price(NULL,'standard','paypal') → 3.10
      expect(
        RefillPricing.grossUpTotal(
          net: baseFee,
          gatewayFeePercentage: paypalPct,
          gatewayFeeFixed: paypalFixed,
        ),
        3.10,
      );
    });
  });
}
