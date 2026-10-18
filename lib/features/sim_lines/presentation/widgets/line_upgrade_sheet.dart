import 'package:flutter/material.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/payments/presentation/screens/paypal_checkout_screen.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/domain/plan_payment.dart';
import 'package:keep_sims/features/sim_lines/domain/refill_pricing.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/carrier_activity_notice.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/carrier_rules_sheet.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_liveness_result.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/carrier_liveness_badge.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_line_detail_controller.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

/// A professional bottom sheet for upgrading a SIM line's protection tier.
/// Shows available upgrade plans (Standard / Premium) with features and pricing,
/// and navigates to payment on confirmation.
class LineUpgradeSheet extends ConsumerStatefulWidget {
  final SimLine simLine;
  final String? initialPlan;

  const LineUpgradeSheet({super.key, required this.simLine, this.initialPlan});

  /// Convenience method to show this sheet.
  static Future<void> show({
    required BuildContext context,
    required SimLine simLine,
    String? initialPlan,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          LineUpgradeSheet(simLine: simLine, initialPlan: initialPlan),
    );
  }

  @override
  ConsumerState<LineUpgradeSheet> createState() => _LineUpgradeSheetState();
}

class _LineUpgradeSheetState extends ConsumerState<LineUpgradeSheet> {
  String? _selectedPlan;
  PremiumInitialBreakdown? _serverBreakdown;

  bool get _isStandardUpgrade => _serverBreakdown?.isUpgrade ?? false;

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.initialPlan;
    _loadBreakdown();
  }

  Future<void> _loadBreakdown() async {
    final carrierId = widget.simLine.carrierId;
    if (carrierId == null) return;
    try {
      final rule = await ref.read(carrierRuleProvider(carrierId).future);
      if (rule != null && mounted) {
        final b = await PlanPayment.fetchPremiumBreakdown(
          carrierRuleId: rule.id,
          simLineId: widget.simLine.id,
        );
        if (mounted && b != null) {
          setState(() => _serverBreakdown = b);
        }
      }
    } catch (_) {}
  }

  // Plan definitions. Prices are NOT stored here: this sheet used to carry a
  // third rival price list (Standard $1.99/mo, Premium $3.99/mo, charged as a
  // one-off) — the canonical model is the per-line yearly fee from
  // `system_configs.BASE_SERVICE_FEE_USD` plus, for premium, the computed
  // first refill; later occurrences are wallet-funded when due.
  static const _plans = {
    'standard': _PlanInfo(
      name: 'Standard',
      icon: Icons.verified_outlined,
      color: Color(0xFF1565C0),
      darkColor: Color(0xFF64B5F6),
      features: [
        'Push, Email, WhatsApp & Telegram alerts',
        'Telegram recharge requests',
        'Manual status & expiry checks',
        'Up to 5 SIM lines',
      ],
    ),
    'premium': _PlanInfo(
      name: 'Premium',
      icon: Icons.workspace_premium,
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

  /// The yearly base service fee, from `system_configs` (display fallback).
  double? get _baseServiceFeeUsd => ref.watch(baseServiceFeeUsdProvider).value;

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

    final livenessAsync = ref.watch(
      simLivenessValidationProvider(phoneNumber: widget.simLine.phoneNumber),
    );
    final livenessResult =
        livenessAsync.value ??
        (widget.simLine.isCarrierVerified
            ? SimLivenessResult(
                isActive: widget.simLine.carrierStatus == 'active',
                carrierStatus: widget.simLine.carrierStatus,
                detectedOperatorName: widget.simLine.detectedOperatorName,
                verifiedAt: widget.simLine.carrierVerifiedAt,
              )
            : null);

    // Determine which plans to show (only upgrades)
    final availablePlans = <String>[];
    if (currentTier == 'free' ||
        currentTier == 'basic' ||
        currentPlan == 'free' ||
        currentPlan == 'basic') {
      availablePlans.addAll(['standard', 'premium']);
    } else if (currentTier == 'standard' || currentPlan == 'standard') {
      availablePlans.add('premium');
    }

    final double? displayedWalletChargeUsd = _selectedPlan == 'standard'
        ? _baseServiceFeeUsd
        : _selectedPlan == 'premium' &&
              carrierRule != null &&
              !isRuleLoading &&
              !CarrierActivityNotice.blocksPremium(carrierRule)
        ? (_serverBreakdown?.totalDueNowUsd ??
              PlanPayment.premiumWalletTotalSync(
                ref,
                carrierRule,
                simLineId: widget.simLine.id,
              ))
        : null;

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
              // Drag handle and Close button
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 24),
                      color: context.onSurfaceColor.withValues(alpha: 0.75),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Close',
                      onPressed: () {
                        HapticHelper.lightTick();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

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
                  color: isDark
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF2E7D32),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
              const SizedBox(height: 12),

              // Live carrier BSS liveness badge
              CarrierLivenessBadge(
                result: livenessResult,
                isLoading: livenessAsync.isLoading,
                onRetry: () => ref.invalidate(
                  simLivenessValidationProvider(
                    phoneNumber: widget.simLine.phoneNumber,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // i7: before the prices, say whether refilling this carrier can
              // work at all.
              // SimLine carries only carrier_id, so the notice falls back to
              // its generic "This carrier" phrasing here.
              if (carrierRule != null) CarrierActivityNotice(rule: carrierRule),

              // i8: the third purchase surface gets the same link as the form
              // and onboarding. SimLine carries carrier_id but no carrier or
              // country name, so the sheet falls back to its generic phrasing
              // rather than this widget inventing one.
              if (carrierRule != null && widget.simLine.carrierId != null)
                _buildCarrierRulesLink(carrierRule, widget.simLine.carrierId!),

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
                  child: ElevatedButton(
                    onPressed:
                        _selectedPlan != null &&
                            displayedWalletChargeUsd != null
                        ? () async {
                            await HapticHelper.mediumImpact();
                            if (!context.mounted) return;
                            final plan = _plans[_selectedPlan]!;
                            final planName = plan.name;
                            final lineNickname =
                                widget.simLine.nickname ?? 'SIM';
                            final tier = _selectedPlan!;

                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);
                            final container = ProviderScope.containerOf(
                              context,
                            );
                            final l = AppLocalizations.of(context)!;

                            if (livenessResult?.carrierStatus == 'inactive') {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    livenessResult!.message.isNotEmpty
                                        ? livenessResult.message
                                        : 'This SIM number is inactive or expired at the carrier. Cannot upgrade.',
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }

                            if (tier == 'premium' && carrierRule == null) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Premium auto-refill is not yet supported for this carrier.',
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }

                            // i7: refuse before charging. The server raises
                            // KS422 when it tries to queue refills for a
                            // carrier that only counts real usage, and by then
                            // the year has been paid for.
                            if (tier == 'premium' &&
                                CarrierActivityNotice.blocksPremium(
                                  carrierRule,
                                )) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This carrier only resets its inactivity clock on a call, '
                                    'SMS or data session, so automatic refills cannot keep the '
                                    'line active. Standard protection still alerts you in time.',
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }

                            // A paid year starts now — the old code upgraded
                            // the tier without ever setting an expiry.
                            final updatedLine = widget.simLine.copyWith(
                              protectionTier: tier,
                              planType: tier,
                              planExpiresAt: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              isCarrierVerified:
                                  livenessResult?.isActive ??
                                  widget.simLine.isCarrierVerified,
                              carrierStatus:
                                  livenessResult?.carrierStatus ??
                                  widget.simLine.carrierStatus,
                              detectedOperatorName:
                                  livenessResult?.detectedOperatorName ??
                                  widget.simLine.detectedOperatorName,
                              carrierVerifiedAt: livenessResult != null
                                  ? DateTime.now()
                                  : widget.simLine.carrierVerifiedAt,
                            );

                            Future<void> commitUpgrade() async {
                              try {
                                await container
                                    .read(simLinesControllerProvider.notifier)
                                    .updateSimLine(updatedLine);
                                container.invalidate(
                                  simLineDetailControllerProvider(
                                    widget.simLine.id,
                                  ),
                                );
                              } on ScheduleInitializationException catch (e) {
                                // The saved plan must not be charged again during schedule review.
                                container.invalidate(
                                  simLineDetailControllerProvider(
                                    widget.simLine.id,
                                  ),
                                );
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Your payment went through and the plan '
                                      'was saved, but the refill settings need review: $e\n'
                                      'Do not pay for the plan again.',
                                    ),
                                    backgroundColor: AppColors.warning,
                                    duration: const Duration(seconds: 12),
                                  ),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to save upgrade: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }

                            // The canonical price (C3c): Standard is the yearly
                            // service fee, billed wallet-first; premium is the
                            // fee plus the first refill in one reviewed
                            // charge, same math as onboarding.
                            late final double planFee;
                            try {
                              planFee = double.parse(
                                (tier == 'standard'
                                        ? await ref.read(
                                            baseServiceFeeUsdProvider.future,
                                          )
                                        : await PlanPayment.premiumWalletTotal(
                                            ref,
                                            carrierRule!,
                                            simLineId: widget.simLine.id,
                                          ))
                                    .toStringAsFixed(2),
                              );

                              if (await PlanPayment.tryPlanFromWallet(
                                ref,
                                plan: tier,
                                rule: carrierRule,
                                simLineId: widget.simLine.id,
                              )) {
                                await commitUpgrade();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(l.planFeePaidFromWallet),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                                navigator.pop();
                                return;
                              }
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Payment failed: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }

                            // Read available wallet balance
                            double walletBalance = 0.0;
                            final walletRead = await ref
                                .read(walletRepositoryProvider)
                                .getWallet();
                            if (walletRead case Success(data: final w)) {
                              walletBalance = w.balance;
                            }

                            final shortfall = PlanPayment.calculateShortfall(
                              fee: planFee,
                              availableBalance: walletBalance,
                            );

                            if (!context.mounted) return;
                            final authGuard = ref.read(
                              paymentAuthGuardProvider,
                            );
                            final authOk = await authGuard
                                .confirmPaymentInteractive(
                                  context,
                                  reason:
                                      'Authenticate to deposit \$${shortfall.toStringAsFixed(2)} for plan upgrade',
                                  amountPreview: ApproxLocalText(shortfall),
                                );
                            if (!authOk) {
                              return;
                            }

                            navigator.pop();
                            // Navigate directly to PayPal deposit
                            navigator.push(
                              MaterialPageRoute(
                                builder: (_) => PayPalCheckoutScreen(
                                  initialAmount: shortfall,
                                  paymentReason:
                                      'Wallet deposit for $planName plan upgrade ($lineNickname)',
                                  paymentKind: 'deposit',
                                  plan: tier,
                                  simLineId: widget.simLine.id,
                                  carrierRuleId: carrierRule?.id,
                                  onSuccess: () async {
                                    try {
                                      await PlanPayment.waitForWalletCredit(
                                        ref,
                                        atLeast: planFee,
                                      );

                                      final paid =
                                          await PlanPayment.tryPlanFromWallet(
                                            ref,
                                            plan: tier,
                                            rule: carrierRule,
                                            simLineId: widget.simLine.id,
                                          );

                                      if (paid) {
                                        await commitUpgrade();
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              l.planFeePaidFromWallet,
                                            ),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                      } else {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Deposit received! Please try upgrading again from your wallet balance.',
                                            ),
                                            backgroundColor: AppColors.warning,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Plan upgrade failed: $e',
                                          ),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: _selectedPlan == 'premium'
                          ? (isDark
                                ? const Color(0xFFFFD700)
                                : const Color(0xFF2E7D32))
                          : (isDark
                                ? const Color(0xFF64B5F6)
                                : const Color(0xFF1565C0)),
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
                        Flexible(
                          child: Text(
                            _selectedPlan != null
                                ? displayedWalletChargeUsd == null
                                      ? 'Continue to Payment'
                                      : 'Continue to Payment • ${Money.usd(displayedWalletChargeUsd)} USD'
                                : 'Select a plan to continue',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _selectedPlan == 'premium' && isDark
                                  ? Colors.black
                                  : (_selectedPlan != null
                                        ? Colors.white
                                        : context.onSurfaceColor.withValues(
                                            alpha: 0.3,
                                          )),
                            ),
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

  /// Takes the rule as a non-nullable parameter rather than reading the
  /// nullable local: a `carrierRule!` inside the button's closure reads as a
  /// crash waiting for a rebuild, even where the analyzer can prove it is not.
  Widget _buildCarrierRulesLink(CarrierRule rule, String carrierId) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: () => CarrierRulesSheet.show(
          context: context,
          rule: rule,
          carrierId: carrierId,
          // Withheld for a carrier we refuse to sell Premium on: a price beside
          // a refusal reads as an offer.
          premiumYearlyTotal: CarrierActivityNotice.blocksPremium(rule)
              ? null
              : PlanPayment.premiumYearlyTotalSync(
                  ref,
                  rule,
                  simLineId: widget.simLine.id,
                ),
        ),
        icon: const Icon(Icons.menu_book_rounded, size: 16),
        label: Text(
          AppLocalizations.of(context)!.carrierRulesLinkLabel,
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
        ),
        style: TextButton.styleFrom(
          foregroundColor: context.primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
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

                // Price column — canonical model: premium shows initial due today
                // (annual fee delta + 1st refill), standard shows bare service fee.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          planKey == 'premium' && carrierRule != null
                              ? '\$${(_serverBreakdown?.totalDueNowUsd ?? PlanPayment.premiumYearlyTotalSync(ref, carrierRule, simLineId: widget.simLine.id))?.toStringAsFixed(2) ?? '…'}'
                              : '\$${_baseServiceFeeUsd?.toStringAsFixed(2) ?? '…'}',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if ((planKey == 'premium'
                                ? _serverBreakdown?.totalDueNowUsd
                                : _baseServiceFeeUsd)
                            case final price?)
                          ApproxLocalText(price, textAlign: TextAlign.end),
                      ],
                    ),
                    Text(
                      _isStandardUpgrade && planKey == 'premium'
                          ? 'upgrade total today'
                          : '/yr per line',
                      style: AppTextStyles.caption.copyWith(
                        color: context.onSurfaceColor.withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                    ),
                    // Show "+ Refill" for premium if carrier rule exists
                    if (planKey == 'premium' && carrierRule != null)
                      Text(
                        'incl. first refill + USD ${_serverBreakdown?.annualFeeUsd.toStringAsFixed(2) ?? '…'} membership',
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
                                  color: context.onSurfaceColor.withValues(
                                    alpha: 0.75,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Auto-refill cost info for Premium
                    if (planKey == 'premium') ...[
                      const SizedBox(height: 10),
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
                                color: context.onSurfaceColor.withValues(
                                  alpha: 0.5,
                                ),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        )
                      else if (carrierRule != null) ...[
                        if (_isStandardUpgrade)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0x22FFD700)
                                  : const Color(0x182E7D32),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.card_giftcard_rounded,
                                  size: 18,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Upgrade Reward: 1 Full Year (365 days) protection granted starting today!',
                                    style: AppTextStyles.caption.copyWith(
                                      color: context.onSurfaceColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _buildBreakdownCard(
                          context: context,
                          carrierRule: carrierRule,
                          accentColor: accentColor,
                          isDark: isDark,
                        ),
                      ] else
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

  Widget _buildBreakdownCard({
    required BuildContext context,
    required CarrierRule carrierRule,
    required Color accentColor,
    required bool isDark,
  }) {
    final breakdown =
        _serverBreakdown ??
        PlanPayment.premiumBreakdownSync(
          ref,
          carrierRule,
          simLineId: widget.simLine.id,
        );

    if (breakdown == null) {
      return const Text('Current pricing is unavailable. Please try again.');
    }

    final refillIntervalDays = breakdown.recurringRefillDays > 0
        ? breakdown.recurringRefillDays
        : carrierRule.refillIntervalDays;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Text(
                'Initial Payment Breakdown',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.onSurfaceColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: accentColor.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 8),

          if (_isStandardUpgrade) ...[
            _buildBreakdownRow(
              'Premium Annual Fee',
              '\$${breakdown.fullAnnualFeeUsd.toStringAsFixed(2)}',
              context: context,
            ),
            _buildBreakdownRow(
              'Standard Credit (already paid)',
              '-\$${breakdown.upgradeCreditUsd.toStringAsFixed(2)}',
              context: context,
              color: Colors.green,
            ),
            _buildBreakdownRow(
              'Net Upgrade Fee',
              '\$${breakdown.serviceFeeUsd.toStringAsFixed(2)}',
              context: context,
              isBold: true,
            ),
          ] else
            _buildBreakdownRow(
              'Annual Protection Fee',
              '\$${breakdown.serviceFeeUsd.toStringAsFixed(2)}',
              context: context,
            ),

          const SizedBox(height: 4),
          _buildBreakdownRow(
            '1st SIM Recharge (current rate)',
            '\$${breakdown.firstRefillUsd.toStringAsFixed(2)}',
            context: context,
          ),
          const SizedBox(height: 6),
          Divider(color: accentColor.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 6),
          _buildBreakdownRow(
            'Total Due Today',
            '\$${breakdown.totalDueNowUsd.toStringAsFixed(2)}',
            context: context,
            isBold: true,
            color: accentColor,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.autorenew_rounded,
                size: 14,
                color: context.onSurfaceColor.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Future refills: Pay-per-refill from wallet balance (~every $refillIntervalDays days, subject to carrier rate).',
                  style: AppTextStyles.caption.copyWith(
                    color: context.onSurfaceColor.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    String amount, {
    required BuildContext context,
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: context.onSurfaceColor.withValues(
                alpha: isBold ? 0.9 : 0.7,
              ),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            amount,
            style: AppTextStyles.caption.copyWith(
              color:
                  color ??
                  context.onSurfaceColor.withValues(alpha: isBold ? 1.0 : 0.8),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal data class for plan info. Deliberately price-free — prices come
/// from the DB via [PlanPayment], never from widget constants.
class _PlanInfo {
  final String name;
  final IconData icon;
  final Color color;
  final Color darkColor;
  final List<String> features;

  const _PlanInfo({
    required this.name,
    required this.icon,
    required this.color,
    required this.darkColor,
    required this.features,
  });
}
