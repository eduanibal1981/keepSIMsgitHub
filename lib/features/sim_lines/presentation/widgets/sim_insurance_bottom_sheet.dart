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

class SimInsuranceBottomSheet extends ConsumerWidget {
  final SimLine line;

  const SimInsuranceBottomSheet({super.key, required this.line});

  static const List<double> capChoices = <double>[2, 5, 10, 20];

  static Future<void> show({
    required BuildContext context,
    required SimLine line,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SimInsuranceBottomSheet(line: line),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policyAsync = ref.watch(rescuePolicyForLineProvider(line.id));
    final LineRescuePolicy? policy = policyAsync.value;
    final bool insured = policy?.isInsured ?? false;
    final bool isDark = context.isDarkMode;
    final Color accent = insured ? AppColors.success : const Color(0xFF0EA5E9);

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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.health_and_safety_outlined,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SIM Insurance',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.onSurfaceColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      insured
                          ? 'Active — up to \$${policy!.maxUsd.toStringAsFixed(2)} per rescue'
                          : 'Off — line may expire if missed',
                      style: AppTextStyles.caption.copyWith(
                        color: insured
                            ? AppColors.success
                            : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: insured,
                activeTrackColor: AppColors.primary,
                onChanged: (policyAsync.isLoading ||
                        ref.watch(rescuePolicyControllerProvider).isLoading)
                    ? null
                    : (bool on) => on
                        ? _showCapPicker(context, ref, policy)
                        : _save(context, ref, 0),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Explanation
          Text(
            insured
                ? 'If last known recharge is more than $triggerDays days ago, we warn you first. If no top-up is completed within 24 hours, we buy the cheapest top-up to keep your line alive — never more than your limit of \$${policy!.maxUsd.toStringAsFixed(2)}.'
                : 'If last known recharge is more than $triggerDays days ago, we warn you first. If no top-up is completed within 24 hours, we buy the cheapest top-up to keep your line alive up to your chosen limit.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.onSurfaceColor.withValues(alpha: 0.8),
              height: 1.45,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 14),

          // Price Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isLimitBelowCheapest ? AppColors.warning : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC))),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLimitBelowCheapest
                    ? AppColors.warning.withValues(alpha: 0.5)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isLimitBelowCheapest ? Icons.warning_amber_rounded : Icons.info_outline,
                  size: 16,
                  color: isLimitBelowCheapest ? Colors.amber.shade900 : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLimitBelowCheapest
                        ? 'Your set limit (\$${policy.maxUsd.toStringAsFixed(2)}) is below the minimum keep-alive top-up for this carrier (\$${minCost.toStringAsFixed(2)}). Please increase your limit so auto-rescue can protect your line.'
                        : 'If the set limit is below the cheapest top-up available for this carrier (\$${minCost.toStringAsFixed(2)}), auto-rescue cannot be executed.',
                    style: AppTextStyles.caption.copyWith(
                      color: isLimitBelowCheapest ? Colors.amber.shade900 : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (policy != null && policy.hasOutstandingWarning) ...[
            const SizedBox(height: 12),
            _buildStatusBadge(
              context,
              AppColors.warning,
              Icons.timer_outlined,
              policy.graceHoursLeft() > 0
                  ? 'Warned — about ${policy.graceHoursLeft()}h left to top up yourself'
                  : 'Warned — a rescue may happen on the next hourly check',
            ),
          ],

          if (policy != null && policy.hasEverRescued) ...[
            const SizedBox(height: 10),
            _buildStatusBadge(
              context,
              AppColors.success,
              Icons.verified_outlined,
              policy.rescueCount == 1
                  ? 'Rescued this line once'
                  : 'Rescued this line ${policy.rescueCount} times',
            ),
          ],

          const SizedBox(height: 20),

          // Actions
          if (insured) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showCapPicker(context, ref, policy),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Change Spending Limit'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _save(context, ref, 0),
                child: const Text(
                  'Turn SIM Insurance Off',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCapPicker(context, ref, policy),
                icon: const Icon(Icons.shield_outlined, size: 18, color: Colors.white),
                label: const Text(
                  'Enable SIM Insurance',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, Color color, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
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
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final isDark = sheetContext.isDarkMode;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Maximum spend per rescue',
                style: AppTextStyles.titleMedium.copyWith(
                  color: sheetContext.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'We always purchase the lowest-cost qualifying refill. This is the ceiling, not the fixed price.',
                style: AppTextStyles.caption.copyWith(
                  color: sheetContext.onSurfaceColor.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 16),
              ...capChoices.map(
                (double cap) => ListTile(
                  leading: Icon(
                    (policy?.maxUsd ?? 0) == cap
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    'Up to \$${cap.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: sheetContext.onSurfaceColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _save(context, ref, cap);
                  },
                ),
              ),
            ],
          ),
        );
      },
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
                  ? 'SIM insurance active — up to \$${cap.toStringAsFixed(2)} per rescue.'
                  : 'SIM insurance off. Other refill schedules are unchanged.')
              : (result.message ?? 'Could not change SIM insurance.'),
        ),
      ),
    );
  }
}
