import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/domain/carrier_rule_advice.dart';

/// The carriers named in these tests are the real rows from `carrier_rules`,
/// so a verdict that changes here is a verdict that changed for a live line.
void main() {
  CarrierRule rule({
    required int inactivityLimitDays,
    int gracePeriodDays = 30,
    double minimumTopupAmount = 5.00,
    String activityRequirement = 'recharge_ok',
    double? qualifying,
    int? intervalOverride,
  }) => CarrierRule.fromJson({
    'id': 'rule-1',
    'carrier_id': 'carrier-1',
    'rule_type': 'default',
    'inactivity_limit_days': inactivityLimitDays,
    'grace_period_days': gracePeriodDays,
    'minimum_topup_amount': minimumTopupAmount,
    'topup_validity_days': 30,
    'inapp_pricing': 0,
    'inapp_pricing_currency': 'usd',
    'activity_requirement': activityRequirement,
    'validity_qualifying_topup_amount': qualifying,
    'refill_interval_days_override': intervalOverride,
  });

  group('usage_required is never a sale', () {
    // MTN Syria / Syriatel / Vodafone Germany CallYa: 90-day window, but the
    // clock resets on a call, an SMS or a data session.
    final advice = CarrierRuleAdvice.of(
      rule(inactivityLimitDays: 90, activityRequirement: 'usage_required'),
      premiumYearlyTotal: 40.00,
    );

    test('verdict is self-service, whatever the window says', () {
      expect(advice.verdict, PlanVerdict.selfServiceOnly);
      expect(advice.premiumIsPointless, isTrue);
      expect(advice.reasons, contains(AdviceReason.usageOnlyResetsClock));
    });

    test('no price is quoted for a plan we refuse to sell', () {
      // The purchase surfaces gate on blocksPremium() before charging (i7). A
      // sheet that still printed "$40.00/yr" beside the refusal is an invitation
      // to go and find the buy button anyway.
      expect(advice.premiumYearlyTotal, isNull);
      expect(advice.selfServiceYearlyCost, isNull);
      expect(advice.automationCost, isNull);
    });

    test('a short window does not escalate it into a recommendation', () {
      final short = CarrierRuleAdvice.of(
        rule(
          inactivityLimitDays: 30,
          gracePeriodDays: 0,
          activityRequirement: 'usage_required',
        ),
      );
      expect(short.verdict, PlanVerdict.selfServiceOnly);
    });
  });

  group('the window sets the verdict', () {
    test('T-Mobile US, 30 days: automation is strongly advised', () {
      final a = CarrierRuleAdvice.of(rule(inactivityLimitDays: 30));
      expect(a.verdict, PlanVerdict.premiumStronglyAdvised);
      expect(a.reasons, contains(AdviceReason.shortWindow));
    });

    test('Telekom DE, 700 days: standard is enough', () {
      final a = CarrierRuleAdvice.of(rule(inactivityLimitDays: 700));
      expect(a.verdict, PlanVerdict.standardIsEnough);
      expect(a.reasons, contains(AdviceReason.longWindow));
    });

    test('Etisalat UAE, 90 days with grace: premium is worth it', () {
      final a = CarrierRuleAdvice.of(
        rule(inactivityLimitDays: 90, gracePeriodDays: 365),
      );
      expect(a.verdict, PlanVerdict.premiumWorthIt);
      expect(a.reasons, contains(AdviceReason.graceCushion));
    });
  });

  group('a missing grace period escalates but never de-escalates', () {
    test('Globe PH, 120 days and no grace, moves up a level', () {
      final withGrace =
          CarrierRuleAdvice.of(rule(inactivityLimitDays: 120, gracePeriodDays: 30));
      final without =
          CarrierRuleAdvice.of(rule(inactivityLimitDays: 120, gracePeriodDays: 0));
      expect(withGrace.verdict, PlanVerdict.premiumWorthIt);
      expect(without.verdict, PlanVerdict.premiumStronglyAdvised);
      expect(without.reasons, contains(AdviceReason.noGracePeriod));
    });

    test('a long window with no grace still stops short of "strongly"', () {
      // 330 days is Bangladesh. One escalation, not two: the number of days is
      // still generous, it just has no second chance at the end.
      final a =
          CarrierRuleAdvice.of(rule(inactivityLimitDays: 330, gracePeriodDays: 0));
      expect(a.verdict, PlanVerdict.premiumWorthIt);
    });

    test('a generous grace period cannot argue Premium down', () {
      // Turkcell: 180-day window, 365 days of grace. Grace is a cushion for a
      // missed top-up, not a reason to stop topping up.
      final a =
          CarrierRuleAdvice.of(rule(inactivityLimitDays: 180, gracePeriodDays: 365));
      expect(a.verdict, PlanVerdict.premiumWorthIt);
    });
  });

  group('the money comparison', () {
    test('self-service is priced at the qualifying amount, not the headline', () {
      // Kuwait: the headline minimum buys credit; only 32.70 buys validity.
      // Quoting the cheaper number would make doing it yourself look free.
      final a = CarrierRuleAdvice.of(
        rule(
          inactivityLimitDays: 90,
          gracePeriodDays: 60,
          minimumTopupAmount: 1.00,
          activityRequirement: 'min_denomination',
          qualifying: 32.70,
        ),
        premiumYearlyTotal: 200.00,
      );
      expect(a.qualifyingAmount, 32.70);
      expect(a.reasons, contains(AdviceReason.qualifyingDenomination));
      // 90-day window -> 76-day interval -> 5 refills a year.
      expect(a.refillsPerYear, 5);
      expect(a.selfServiceYearlyCost, closeTo(163.50, 0.001));
      expect(a.automationCost, closeTo(36.50, 0.001));
    });

    test('with no qualifying ladder it falls back to the plain minimum', () {
      final a = CarrierRuleAdvice.of(
        rule(inactivityLimitDays: 180, minimumTopupAmount: 6.25),
        premiumYearlyTotal: 25.06,
      );
      expect(a.qualifyingAmount, 6.25);
      expect(a.refillsPerYear, 3);
      expect(a.selfServiceYearlyCost, closeTo(18.75, 0.001));
      expect(a.automationCost, closeTo(6.31, 0.001));
    });

    test('no premium quote means no money claim at all', () {
      // The config providers load asynchronously; a sheet built before they
      // arrive must show nothing rather than a zero.
      final a = CarrierRuleAdvice.of(rule(inactivityLimitDays: 180));
      expect(a.premiumYearlyTotal, isNull);
      expect(a.automationCost, isNull);
      expect(a.selfServiceYearlyCost, isNotNull);
      expect(a.reasons, isNot(contains(AdviceReason.automationCostsExtra)));
    });
  });

  test('the cadence shown is the one the scheduler actually uses', () {
    // Guards against the i7 regression: reading topup_validity_days as a cycle
    // is what sold a 180-day Saudi carrier 13 refills a year.
    final a = CarrierRuleAdvice.of(rule(inactivityLimitDays: 180));
    expect(a.refillIntervalDays, 153);
    expect(a.refillsPerYear, 3);
  });
}
