/// Whether this carrier's rules make a paid plan worth buying — and, when they
/// do not, says so.
///
/// The plan cards have always argued one way. Every carrier got the same
/// "Fully automated top-ups" pitch, priced from its own rule but never judged
/// against it, and a subscriber had no way to see that Telekom DE reclaims a
/// number after **700** days of silence while DITO does it after 90 with **no
/// grace period at all**. Those two lines do not need the same product, and
/// selling them the same one is how a year's fee gets charged for a problem
/// the customer did not have.
///
/// This is the judgement, kept out of the widgets so it can be tested and so
/// the three purchase surfaces cannot drift into three different opinions.
/// Everything here is derived from `carrier_rules` — no invented figures, and
/// no reference to how long the subscriber has been away, which the product
/// does not know.
library;

import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';

/// What we would tell someone standing in front of the plan cards.
enum PlanVerdict {
  /// Nothing KeepSIMs sells can hold this line: the carrier only counts a call,
  /// an SMS or a data session. Buying Premium here takes a year's money for a
  /// promise that cannot be kept — i7 refuses the sale, and this is the reason
  /// shown when it does.
  selfServiceOnly,

  /// The deactivation window is long enough that being *told* is the whole job.
  /// Standard's alerts plus one or two top-ups a year in the operator's own app
  /// costs less than automating it.
  standardIsEnough,

  /// Automation earns its keep, but a diligent person could do this by hand.
  premiumWorthIt,

  /// Short window, or no grace period to catch a mistake. Doing this by hand
  /// means remembering on time, repeatedly, from another country.
  premiumStronglyAdvised,
}

/// One fact behind a [PlanVerdict]. The UI turns these into localised
/// sentences; keeping them as values rather than strings is what lets the same
/// judgement render in nine languages.
enum AdviceReason {
  /// Only real usage restarts the clock; credit does not.
  usageOnlyResetsClock,

  /// A top-up below the qualifying amount buys no validity.
  qualifyingDenomination,

  /// Few enough days between top-ups that hand-managing it will eventually slip.
  shortWindow,

  /// Long enough that a yearly reminder covers it.
  longWindow,

  /// The number is gone the moment the window closes.
  noGracePeriod,

  /// There is a recovery window after the cliff.
  graceCushion,

  /// What the convenience costs on top of the airtime itself.
  automationCostsExtra,
}

/// A verdict plus the facts that produced it.
class CarrierPlanAdvice {
  const CarrierPlanAdvice({
    required this.verdict,
    required this.reasons,
    required this.deactivationWindowDays,
    required this.gracePeriodDays,
    required this.refillIntervalDays,
    required this.refillsPerYear,
    required this.qualifyingAmount,
    required this.currency,
    this.selfServiceYearlyCost,
    this.premiumYearlyTotal,
  });

  final PlanVerdict verdict;
  final List<AdviceReason> reasons;

  final int deactivationWindowDays;
  final int gracePeriodDays;
  final int refillIntervalDays;
  final int refillsPerYear;

  /// The smallest top-up that actually buys validity, in [currency]. Falls back
  /// to the carrier's plain minimum when it sells no voucher ladder.
  final double qualifyingAmount;
  final String currency;

  /// A year of top-ups bought directly from the operator, at the qualifying
  /// amount, at our own cadence. The airtime alone — no service fee, no margin,
  /// no gateway.
  final double? selfServiceYearlyCost;

  /// The single up-front charge for a year of Premium, when the caller has
  /// priced it. Null while the config providers are still loading, in which
  /// case the money comparison is simply not shown rather than guessed.
  final double? premiumYearlyTotal;

  /// What a year of *not having to remember* costs, over and above the airtime.
  ///
  /// Null unless both sides are known. Can be negative in principle — a carrier
  /// whose `inapp_pricing` override undercuts its own minimum — and is reported
  /// as it falls out rather than clamped, because a negative here is a pricing
  /// bug worth seeing.
  double? get automationCost => (premiumYearlyTotal == null ||
          selfServiceYearlyCost == null)
      ? null
      : premiumYearlyTotal! - selfServiceYearlyCost!;

  /// True when the honest answer is "do not buy this from us".
  bool get premiumIsPointless => verdict == PlanVerdict.selfServiceOnly;
}

/// Builds the advice. Pure — no providers, no context, no clock.
class CarrierRuleAdvice {
  const CarrierRuleAdvice._();

  /// Below this many days between qualifying top-ups, doing it by hand from
  /// abroad is a standing chore rather than an annual one.
  static const int shortWindowDays = 60;

  /// At or above this, the carrier is asking for roughly one top-up a year.
  /// Two hundred and seventy days is the point where a single calendar
  /// reminder covers the whole year with margin to spare.
  static const int longWindowDays = 270;

  static CarrierPlanAdvice of(
    CarrierRule rule, {
    double? premiumYearlyTotal,
  }) {
    final reasons = <AdviceReason>[];

    // The qualifying amount is the honest price of one top-up: on a voucher
    // ladder the headline minimum buys credit and no validity, which is the
    // whole trap `validity_qualifying_topup_amount` exists to name.
    final qualifying =
        rule.validityQualifyingTopupAmount ?? rule.minimumTopupAmount;
    final refillsPerYear = rule.refillsPerYear;

    // `usage_required` short-circuits everything below it. There is no window
    // arithmetic that makes an automated refill work on a carrier that does not
    // count refills, so no other reason is worth listing first.
    if (rule.requiresHumanUsage) {
      return CarrierPlanAdvice(
        verdict: PlanVerdict.selfServiceOnly,
        reasons: const [AdviceReason.usageOnlyResetsClock],
        deactivationWindowDays: rule.inactivityLimitDays,
        gracePeriodDays: rule.gracePeriodDays,
        refillIntervalDays: rule.refillIntervalDays,
        refillsPerYear: refillsPerYear,
        qualifyingAmount: qualifying,
        currency: rule.inappPricingCurrency.toUpperCase(),
        // Deliberately no yearly costs: quoting a price for a plan we refuse to
        // sell invites the reader to buy it anyway.
      );
    }

    PlanVerdict verdict;
    if (rule.inactivityLimitDays <= shortWindowDays) {
      verdict = PlanVerdict.premiumStronglyAdvised;
      reasons.add(AdviceReason.shortWindow);
    } else if (rule.inactivityLimitDays >= longWindowDays) {
      verdict = PlanVerdict.standardIsEnough;
      reasons.add(AdviceReason.longWindow);
    } else {
      verdict = PlanVerdict.premiumWorthIt;
    }

    // Grace only ever pushes toward buying, never away from it. A recovery
    // window is a reason to relax about *this* top-up, not a reason to stop
    // topping up — so it is reported, but it cannot downgrade the verdict.
    if (rule.gracePeriodDays <= 0) {
      reasons.add(AdviceReason.noGracePeriod);
      verdict = _escalate(verdict);
    } else {
      reasons.add(AdviceReason.graceCushion);
    }

    if (rule.requiresQualifyingDenomination) {
      reasons.add(AdviceReason.qualifyingDenomination);
    }

    final selfServiceYearly = qualifying * refillsPerYear;
    if (premiumYearlyTotal != null) {
      reasons.add(AdviceReason.automationCostsExtra);
    }

    return CarrierPlanAdvice(
      verdict: verdict,
      reasons: reasons,
      deactivationWindowDays: rule.inactivityLimitDays,
      gracePeriodDays: rule.gracePeriodDays,
      refillIntervalDays: rule.refillIntervalDays,
      refillsPerYear: refillsPerYear,
      qualifyingAmount: qualifying,
      currency: rule.inappPricingCurrency.toUpperCase(),
      selfServiceYearlyCost: selfServiceYearly,
      premiumYearlyTotal: premiumYearlyTotal,
    );
  }

  static PlanVerdict _escalate(PlanVerdict v) => switch (v) {
        PlanVerdict.standardIsEnough => PlanVerdict.premiumWorthIt,
        PlanVerdict.premiumWorthIt => PlanVerdict.premiumStronglyAdvised,
        PlanVerdict.premiumStronglyAdvised => PlanVerdict.premiumStronglyAdvised,
        // Unreachable: selfServiceOnly returns before the grace check, and it
        // must never be escalated into a recommendation to buy.
        PlanVerdict.selfServiceOnly => PlanVerdict.selfServiceOnly,
      };
}
