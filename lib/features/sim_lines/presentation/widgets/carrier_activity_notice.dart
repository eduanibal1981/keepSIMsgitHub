import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

/// Says out loud, before money changes hands, when an automated refill is not
/// by itself enough to keep a line alive.
///
/// Two carriers in every three are ordinary: push credit, the inactivity clock
/// resets, the number survives. The rest are not, and the difference is
/// invisible from the outside:
///
///  * **`usage_required`** — MTN Syria, Vodafone Germany's CallYa. The clock
///    resets on *consumption*: an outgoing call, an SMS, a data session. Credit
///    arriving is not consumption. Nothing KeepSIMs can send saves the line, so
///    Premium is refused outright rather than sold and quietly failed.
///  * **`min_denomination`** — the Gulf voucher ladders, Alfa Lebanon, AT&T. A
///    top-up below a threshold lands as spendable credit and adds no line
///    validity at all. A 1 KD Kuwaiti voucher buys seven days; a BD 3 Bahraini
///    one buys nothing. Premium works, but only at the qualifying amount, which
///    is why the price is higher than the carrier's headline minimum.
///
/// Deliberately silent about `last_verified_at`. Whether *we* have read the
/// operator's terms is an operations problem, visible in the admin app; telling
/// a subscriber "we think this is 90 days" would be noise they cannot act on.
class CarrierActivityNotice extends StatelessWidget {
  const CarrierActivityNotice({
    super.key,
    required this.rule,
    this.carrierName,
    this.dense = false,
  });

  final CarrierRule rule;

  /// Used in the copy so the warning names the operator the user just picked.
  /// Falls back to a generic phrasing when the caller has not resolved it.
  final String? carrierName;

  /// Tighter padding for use inside an already-boxed plan card.
  final bool dense;

  /// Whether a Premium plan can be honestly sold for this carrier at all.
  ///
  /// The server refuses to queue refills for `usage_required` carriers
  /// (KS422 in `queue_premium_refill_executions`). Charging first and
  /// discovering that afterwards is the charged-but-no-line failure this
  /// codebase has already paid for once, so callers must gate the purchase on
  /// this rather than let the RPC be the thing that says no.
  static bool blocksPremium(CarrierRule? rule) =>
      rule != null && rule.requiresHumanUsage;

  @override
  Widget build(BuildContext context) {
    if (rule.refillAloneKeepsLineActive) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blocking = rule.requiresHumanUsage;
    final operator = carrierName ?? l10n.carrierActivityFallbackOperator;

    final Color accent = blocking
        ? (isDark ? AppColors.error : Colors.redAccent)
        : (isDark ? Colors.amberAccent : Colors.orange);

    final String title = blocking
        ? l10n.carrierUsageRequiredTitle
        : l10n.carrierMinDenominationTitle;

    final String body = blocking
        ? l10n.carrierUsageRequiredBody(operator)
        : l10n.carrierMinDenominationBody(
            operator,
            _formatAmount(rule.validityQualifyingTopupAmount),
            rule.inappPricingCurrency.toUpperCase(),
          );

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: dense ? 8 : 12),
      padding: EdgeInsets.all(dense ? 10 : 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            blocking ? Icons.block : Icons.info_outline,
            color: accent,
            size: dense ? 18 : 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.85),
                    height: 1.35,
                  ),
                ),
                // The operator's own wording, in English, under the localised
                // summary. Carrier terms are not translatable content we can
                // own, and paraphrasing them is how the 13-refill claim
                // survived as long as it did.
                if (rule.activityRequirementNote != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    rule.activityRequirementNote!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatAmount(double? amount) =>
      amount == null ? '—' : amount.toStringAsFixed(2);
}
