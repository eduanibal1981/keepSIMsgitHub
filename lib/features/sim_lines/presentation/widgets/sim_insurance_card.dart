/// SIM Shield — SIM insurance card (G7)
///
/// The opt-in for auto-rescue: if this line is about to lapse and the user has
/// not acted, spend up to a set amount from their wallet automatically.
///
/// This is the only screen in the product that arms something which spends
/// money with no further confirmation, so the copy carries three things the
/// user must not have to infer:
///
///   * the exact ceiling, in dollars, on a single rescue;
///   * that a warning always comes first, with how long they get to act;
///   * that it is off unless they turn it on, and one tap turns it back off.
///
/// Renders nothing for a paused line — a paused line is a user decision, not a
/// risk to insure — matching [DepletionForecastCard].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_rescue_policy.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/rescue_policy_provider.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';

class SimInsuranceCard extends ConsumerWidget {
  const SimInsuranceCard({super.key, required this.line});

  final SimLine line;

  /// Offered ceilings. Deliberately small — this is a keep-the-line-alive
  /// top-up, not a data bundle, and the server refuses anything the cheapest
  /// offer cannot fit under anyway.
  static const List<double> capChoices = <double>[2, 5, 10, 20];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policyAsync = ref.watch(rescuePolicyForLineProvider(line.id));
    final LineRescuePolicy? policy = policyAsync.value;
    final bool insured = policy?.isInsured ?? false;
    final bool isDark = context.isDarkMode;
    final Color accent = insured ? AppColors.success : AppColors.info;

    // Fetch carrier rules to know exact validity days & cheapest top-up cost
    final carrierRuleAsync =
        (line.carrierId != null && line.carrierId!.isNotEmpty)
        ? ref.watch(carrierRuleProvider(line.carrierId!))
        : null;
    final CarrierRule? rule = carrierRuleAsync?.value;

    final int validityDays = (rule != null && rule.topupValidityDays > 0)
        ? rule.topupValidityDays
        : ((rule != null && rule.inactivityLimitDays > 0)
              ? rule.inactivityLimitDays
              : 90);
    final int warnLeadDays =
        ((policy?.warnLeadDays ?? 3) + (policy?.leadDays ?? 2)).clamp(
          1,
          validityDays,
        );
    final int triggerDays = (validityDays - warnLeadDays).clamp(
      1,
      validityDays,
    );
    final double minCost = (rule != null && rule.inappPricing > 0)
        ? rule.inappPricing
        : ((rule != null && rule.minimumTopupAmount > 0)
              ? rule.minimumTopupAmount
              : 1.0);
    final bool isLimitBelowCheapest =
        insured &&
        policy != null &&
        policy.maxUsd > 0 &&
        policy.maxUsd < minCost;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: insured
                ? accent.withValues(alpha: 0.45)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    Icons.health_and_safety_outlined,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'SIM insurance',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: context.onSurfaceColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        insured
                            ? 'On — up to \$${policy!.maxUsd.toStringAsFixed(2)} per rescue'
                            : 'Off — this line can lapse if you miss it',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: insured
                              ? accent
                              : context.onSurfaceColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: insured,
                  onChanged:
                      (policyAsync.isLoading ||
                          ref.watch(rescuePolicyControllerProvider).isLoading)
                      ? null
                      : (bool on) => on
                            ? _showCapPicker(context, ref, policy)
                            : _save(context, ref, 0),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              insured
                  ? 'If last known recharge is more than $triggerDays days ago, we warn you first. If no top-up is completed within 24 hours, we buy the cheapest top-up to keep your line alive — never more than your limit of \$${policy!.maxUsd.toStringAsFixed(2)}.'
                  : 'If last known recharge is more than $triggerDays days ago, we warn you first. If no top-up is completed within 24 hours, we buy the cheapest top-up to keep your line alive up to your chosen limit.',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '* ',
                  style: AppTextStyles.caption.copyWith(
                    color: isLimitBelowCheapest
                        ? AppColors.warning
                        : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    isLimitBelowCheapest
                        ? 'Note: Your set limit (\$${policy.maxUsd.toStringAsFixed(2)}) is below the cheapest keep-alive top-up for this carrier (\$${minCost.toStringAsFixed(2)}). Please increase your limit so auto-rescue can protect your line.'
                        : 'Note: If the set limit is below the cheapest top-up available for this carrier (\$${minCost.toStringAsFixed(2)}), auto-rescue cannot be executed.',
                    style: AppTextStyles.caption.copyWith(
                      color: isLimitBelowCheapest
                          ? AppColors.warning
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                      fontStyle: FontStyle.italic,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            if (policy != null && policy.hasOutstandingWarning) ...<Widget>[
              const SizedBox(height: 12),
              _pill(
                context,
                AppColors.warning,
                Icons.timer_outlined,
                policy.graceHoursLeft() > 0
                    ? 'Warned — about ${policy.graceHoursLeft()}h left to top up yourself'
                    : 'Warned — a rescue may happen on the next hourly check',
              ),
            ],
            if (policy != null && policy.hasEverRescued) ...<Widget>[
              const SizedBox(height: 8),
              _pill(
                context,
                AppColors.success,
                Icons.verified_outlined,
                policy.rescueCount == 1
                    ? 'Rescued this line once'
                    : 'Rescued this line ${policy.rescueCount} times',
              ),
            ],
            if (insured) ...<Widget>[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _showCapPicker(context, ref, policy),
                  child: const Text('Change the limit'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, Color tint, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(color: tint),
            ),
          ),
        ],
      ),
    );
  }

  void _showCapPicker(
    BuildContext context,
    WidgetRef ref,
    LineRescuePolicy? policy,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                'Most we may spend per rescue',
                style: AppTextStyles.titleMedium.copyWith(
                  color: sheetContext.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'We always buy the cheapest top-up that keeps the line alive. '
                'This is the ceiling, not the price.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: sheetContext.onSurfaceColor.withValues(alpha: 0.65),
                ),
              ),
            ),
            ...capChoices.map(
              (double cap) => ListTile(
                leading: Icon(
                  (policy?.maxUsd ?? 0) == cap
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: AppColors.success,
                ),
                title: Text('Up to \$${cap.toStringAsFixed(2)}'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _save(context, ref, cap);
                },
              ),
            ),
            if ((policy?.isInsured ?? false))
              ListTile(
                leading: const Icon(
                  Icons.block_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text('Turn SIM insurance off'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _save(context, ref, 0);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref, double cap) async {
    await HapticHelper.lightTick();

    final RescuePolicyResult result = await ref
        .read(rescuePolicyControllerProvider.notifier)
        .save(simLineId: line.id, maxUsd: cap);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? (cap > 0
                    ? 'SIM insurance on — up to \$${cap.toStringAsFixed(2)} per rescue.'
                    : 'SIM insurance off. This line will not be topped up automatically.')
              : (result.message ?? 'Could not change SIM insurance.'),
        ),
      ),
    );
  }
}
