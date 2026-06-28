import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/settings/presentation/screens/paypal_simulator_screen.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_line_detail_controller.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';

/// A professional bottom sheet for upgrading a SIM line's protection tier.
/// Shows available upgrade plans (Standard / Premium) with features and pricing,
/// and navigates to payment on confirmation.
class LineUpgradeSheet extends ConsumerStatefulWidget {
  final SimLine simLine;

  const LineUpgradeSheet({super.key, required this.simLine});

  /// Convenience method to show this sheet.
  static Future<void> show({
    required BuildContext context,
    required SimLine simLine,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => LineUpgradeSheet(simLine: simLine),
    );
  }

  @override
  ConsumerState<LineUpgradeSheet> createState() => _LineUpgradeSheetState();
}

class _LineUpgradeSheetState extends ConsumerState<LineUpgradeSheet> {
  String? _selectedPlan;

  // Plan definitions
  static const _plans = {
    'standard': _PlanInfo(
      name: 'Standard',
      icon: Icons.verified_outlined,
      monthlyPrice: 1.99,
      annualPrice: 19.99,
      color: Color(0xFF1565C0),
      darkColor: Color(0xFF64B5F6),
      features: [
        'Push notification alerts',
        'Telegram recharge requests',
        'Manual status & expiry checks',
        'Up to 5 SIM lines',
      ],
    ),
    'premium': _PlanInfo(
      name: 'Premium',
      icon: Icons.workspace_premium,
      monthlyPrice: 3.99,
      annualPrice: 39.99,
      color: Color(0xFF2E7D32),
      darkColor: Color(0xFFFFD700),
      features: [
        'Everything in Standard',
        'Automated Keep-Alive auto-refill',
        'Custom auto-refill scheduling',
        'Real-time balance monitoring',
        'Unlimited SIM lines',
        'Priority support',
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final currentTier = widget.simLine.protectionTier.trim().toLowerCase();
    final currentPlan = widget.simLine.planType.trim().toLowerCase();

    // Fetch carrier rule for auto-refill cost
    CarrierRule? carrierRule;
    bool isRuleLoading = false;
    if (widget.simLine.carrierId != null) {
      final ruleAsync = ref.watch(
        carrierRuleProvider(widget.simLine.carrierId!),
      );
      carrierRule = ruleAsync.value;
      isRuleLoading = ruleAsync.isLoading;
    }

    // Determine which plans to show (only upgrades)
    final availablePlans = <String>[];
    if (currentTier == 'free' || currentTier == 'basic' || currentPlan == 'free' || currentPlan == 'basic') {
      availablePlans.addAll(['standard', 'premium']);
    } else if (currentTier == 'standard' || currentPlan == 'standard') {
      availablePlans.add('premium');
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0x33FFD700), const Color(0x11FF8C00)]
                        : [const Color(0x22388E3C), const Color(0x11388E3C)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  color: isDark ? const Color(0xFFFFD700) : const Color(0xFF2E7D32),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Upgrade Protection',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),

              // Line identifier
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sim_card_outlined,
                      size: 14,
                      color: context.onSurfaceColor.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.simLine.nickname ?? 'SIM'} • ${widget.simLine.phoneNumber}',
                      style: AppTextStyles.caption.copyWith(
                        color: context.onSurfaceColor.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Current plan indicator
              Text(
                'Current: ${currentTier[0].toUpperCase()}${currentTier.substring(1)} Plan',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.onSurfaceColor.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 24),

              // Plan selection cards
              ...availablePlans.map((planKey) {
                final plan = _plans[planKey]!;
                final isSelected = _selectedPlan == planKey;
                final accentColor = isDark ? plan.darkColor : plan.color;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPlanCard(
                    planKey: planKey,
                    plan: plan,
                    isSelected: isSelected,
                    accentColor: accentColor,
                    isDark: isDark,
                    carrierRule: planKey == 'premium' ? carrierRule : null,
                    isRuleLoading: planKey == 'premium' ? isRuleLoading : false,
                  ),
                );
              }),

              const SizedBox(height: 8),

              // CTA Button
              AnimatedOpacity(
                opacity: _selectedPlan != null ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _selectedPlan != null
                        ? () async {
                            await HapticHelper.mediumImpact();
                            if (!context.mounted) return;
                            final plan = _plans[_selectedPlan]!;
                            final planName = plan.name;
                            final lineNickname = widget.simLine.nickname ?? 'SIM';

                            // Calculate total: plan price + refill cost for premium
                            double totalAmount = plan.monthlyPrice;
                            String reason = '$planName Plan upgrade for $lineNickname (${widget.simLine.phoneNumber})';
                            if (_selectedPlan == 'premium' && carrierRule != null) {
                              totalAmount += carrierRule.inappPricing;
                              reason = '$planName Plan (\$${plan.monthlyPrice}/mo + ${carrierRule.inappPricing} ${carrierRule.inappPricingCurrency.toUpperCase()} refill every ${carrierRule.topupValidityDays} days) for $lineNickname';
                            }

                            final container = ProviderScope.containerOf(context);
                            final updatedLine = widget.simLine.copyWith(
                              protectionTier: _selectedPlan!,
                              planType: _selectedPlan!,
                            );

                            Navigator.pop(context);
                            // Navigate directly to PayPal payment
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PaypalSimulatorScreen(
                                  initialAmount: totalAmount,
                                  paymentReason: reason,
                                  depositToWallet: false,
                                  onSuccess: () async {
                                    try {
                                      await container
                                          .read(simLinesControllerProvider.notifier)
                                          .updateSimLine(updatedLine);
                                      container.invalidate(
                                        simLineDetailControllerProvider(widget.simLine.id),
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to save upgrade: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPlan == 'premium'
                          ? (isDark ? const Color(0xFFFFD700) : const Color(0xFF2E7D32))
                          : (isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0)),
                      foregroundColor: _selectedPlan == 'premium' && isDark
                          ? Colors.black
                          : Colors.white,
                      disabledBackgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: _selectedPlan != null ? 4 : 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedPlan != null
                              ? Icons.payment_rounded
                              : Icons.touch_app_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedPlan != null
                              ? 'Continue to Payment'
                              : 'Select a plan to continue',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _selectedPlan == 'premium' && isDark
                                ? Colors.black
                                : (_selectedPlan != null
                                    ? Colors.white
                                    : context.onSurfaceColor.withValues(alpha: 0.3)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Cancel
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Maybe Later',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.onSurfaceColor.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String planKey,
    required _PlanInfo plan,
    required bool isSelected,
    required Color accentColor,
    required bool isDark,
    CarrierRule? carrierRule,
    bool isRuleLoading = false,
  }) {
    return GestureDetector(
      onTap: () async {
        await HapticHelper.lightTick();
        setState(() => _selectedPlan = planKey);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: isDark ? 0.12 : 0.06)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan header row
            Row(
              children: [
                // Radio indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? accentColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? accentColor
                          : context.onSurfaceColor.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),

                // Plan icon
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(plan.icon, size: 18, color: accentColor),
                ),
                const SizedBox(width: 10),

                // Plan name
                Expanded(
                  child: Text(
                    '${plan.name} Plan',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Price column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${plan.monthlyPrice.toStringAsFixed(2)}',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '/mo per line',
                      style: AppTextStyles.caption.copyWith(
                        color: context.onSurfaceColor.withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                    ),
                    // Show "+ Refill" for premium if carrier rule exists
                    if (planKey == 'premium' && carrierRule != null)
                      Text(
                        '+ ${carrierRule.inappPricing} ${carrierRule.inappPricingCurrency.toUpperCase()} refill',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: accentColor.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Feature list (shown when selected)
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 14, left: 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(
                      color: accentColor.withValues(alpha: 0.2),
                      height: 1,
                    ),
                    const SizedBox(height: 12),
                    ...plan.features.map(
                      (feat) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: accentColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feat,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: context.onSurfaceColor.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Auto-refill cost info for Premium
                    if (planKey == 'premium') ...[
                      const SizedBox(height: 8),
                      if (isRuleLoading)
                        Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Loading auto-refill pricing...',
                              style: AppTextStyles.caption.copyWith(
                                color: context.onSurfaceColor.withValues(alpha: 0.5),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        )
                      else if (carrierRule != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.autorenew_rounded,
                                size: 16,
                                color: accentColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Auto-refill: ${carrierRule.inappPricing} ${carrierRule.inappPricingCurrency.toUpperCase()} every ${carrierRule.topupValidityDays} days (telecom, VAT included)',
                                  style: AppTextStyles.caption.copyWith(
                                    color: context.onSurfaceColor.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Auto-refill pricing not available for this carrier yet.',
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],

                    const SizedBox(height: 4),
                    if (planKey == 'premium')
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '✨ Most Popular',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              crossFadeState: isSelected
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal data class for plan info.
class _PlanInfo {
  final String name;
  final IconData icon;
  final double monthlyPrice;
  final double annualPrice;
  final Color color;
  final Color darkColor;
  final List<String> features;

  const _PlanInfo({
    required this.name,
    required this.icon,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.color,
    required this.darkColor,
    required this.features,
  });
}
