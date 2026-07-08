import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/profile/presentation/controller/profile_controller.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isAnnually = true;
  bool _isUpdating = false;
  int _sliderLinesCount = 2;

  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'basic',
      'title': 'Free Plan',
      'desc': 'Essential manual monitoring for a single SIM card.',
      'color': Colors.blueAccent,
      'features': [
        'Protect 1 SIM line max',
        'Mobile push notifications only',
        'Telegram recharge requests',
        'Manual status & expiry checks',
      ],
    },
    {
      'id': 'standard',
      'title': 'Starter Plan',
      'desc': 'Basic automation and multi-channel validity shields.',
      'color': AppColors.primary,
      'features': [
        '2 SIM lines included in base price',
        'Extra lines: \$0.10/mo (\$1.20/yr) each',
        'Protect up to 5 SIM lines maximum',
        'Push, WhatsApp, Telegram, Email alerts',
        'WhatsApp & Telegram recharge requests',
        'Travel / Home mode active',
        '1× secure line verification check',
      ],
    },
    {
      'id': 'premium',
      'title': 'Premium',
      'desc': 'Unlocks 100% automated protection and intelligent features.',
      'color': Colors.purpleAccent,
      'isPopular': true,
      'features': [
        '2 SIM lines included in base price',
        'Extra lines: \$0.20/mo (\$2.40/yr) each',
        'Protect unlimited SIM lines',
        'All standard notification channels',
        'Fully automated in-app recharge',
        'Smart Geolocation deactivation freeze',
        'Baqa (local calls + data detection)',
        'Unlimited secure line verifications',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final simLines = ref.read(simLinesControllerProvider).value ?? [];
      if (simLines.isNotEmpty) {
        setState(() {
          _sliderLinesCount = simLines.length;
        });
      }
    });
  }

  String _calculatePrice({
    required String planId,
    required int linesCount,
    required bool isAnnually,
  }) {
    if (planId == 'basic') {
      return '0.00';
    }

    if (planId == 'standard') {
      if (linesCount > 5) return '0.00';
      if (isAnnually) {
        // Annually: $0.20/mo base (includes 2 lines) + $0.10/mo per extra line
        double baseRate = 0.20;
        double extraRate = 0.10;
        double monthlyTotal = linesCount <= 2
            ? baseRate
            : baseRate + (linesCount - 2) * extraRate;
        return monthlyTotal.toStringAsFixed(2);
      } else {
        // Monthly: $0.40/mo base (includes 2 lines) + $0.20/mo per extra line
        double baseRate = 0.40;
        double extraRate = 0.20;
        double monthlyTotal = linesCount <= 2
            ? baseRate
            : baseRate + (linesCount - 2) * extraRate;
        return monthlyTotal.toStringAsFixed(2);
      }
    }

    if (planId == 'premium') {
      if (isAnnually) {
        // Annually: $0.40/mo base (includes 2 lines) + $0.20/mo per extra line
        double baseRate = 0.40;
        double extraRate = 0.20;
        double monthlyTotal = linesCount <= 2
            ? baseRate
            : baseRate + (linesCount - 2) * extraRate;
        return monthlyTotal.toStringAsFixed(2);
      } else {
        // Monthly: $0.80/mo base (includes 2 lines) + $0.40/mo per extra line
        double baseRate = 0.80;
        double extraRate = 0.40;
        double monthlyTotal = linesCount <= 2
            ? baseRate
            : baseRate + (linesCount - 2) * extraRate;
        return monthlyTotal.toStringAsFixed(2);
      }
    }

    return '0.00';
  }

  String _calculateOriginalPrice({
    required String planId,
    required int linesCount,
    required bool isAnnually,
  }) {
    if (planId == 'basic') {
      return '0.00';
    }

    if (planId == 'standard') {
      if (linesCount > 5) return '0.00';
      if (isAnnually) {
        // Original Annually base rate: $0.50/mo. Extra line: $0.25/mo.
        double baseRate = 0.50;
        double extraRate = 0.25;
        double monthlyTotal = linesCount <= 2
            ? baseRate
            : baseRate + (linesCount - 2) * extraRate;
        return monthlyTotal.toStringAsFixed(2);
      } else {
        // Original Monthly base rate: $1.00/mo. Extra line: $0.50/mo.
        double baseRate = 1.00;
        double extraRate = 0.50;
        double monthlyTotal = linesCount <= 2
            ? baseRate
            : baseRate + (linesCount - 2) * extraRate;
        return monthlyTotal.toStringAsFixed(2);
      }
    }

    if (planId == 'premium') {
      if (isAnnually) {
        // Original Annually base rate: $1.00/mo. Extra line: $0.50/mo.
        double baseRate = 1.00;
        double extraRate = 0.50;
        double monthlyTotal = linesCount <= 2
            ? baseRate
            : baseRate + (linesCount - 2) * extraRate;
        return monthlyTotal.toStringAsFixed(2);
      } else {
        // Original Monthly base rate: $2.00/mo. Extra line: $1.00/mo.
        double baseRate = 2.00;
        double extraRate = 1.00;
        double monthlyTotal = linesCount <= 2
            ? baseRate
            : baseRate + (linesCount - 2) * extraRate;
        return monthlyTotal.toStringAsFixed(2);
      }
    }

    return '0.00';
  }

  String _getBillingNote({
    required String planId,
    required int linesCount,
    required bool isAnnually,
  }) {
    if (planId == 'basic') {
      return 'Always free';
    }
    if (planId == 'standard' && linesCount > 5) {
      return 'Max 5 lines limit exceeded';
    }

    final priceStr = _calculatePrice(
      planId: planId,
      linesCount: linesCount,
      isAnnually: isAnnually,
    );
    final priceVal = double.tryParse(priceStr) ?? 0.0;

    if (isAnnually) {
      final annualTotal = priceVal * 12;
      return 'Billed annually (\$${annualTotal.toStringAsFixed(2)}/yr)';
    } else {
      return 'Billed monthly';
    }
  }

  Future<void> _updatePlan(String tierId) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;

    if ((user.isPowerUser ? 'premium' : 'standard') == tierId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are already on the ${tierId.toUpperCase()} plan.'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    await HapticHelper.mediumImpact();

    final result = await ref
        .read(profileControllerProvider.notifier)
        .completeOnboarding(
          fullName: user.fullName ?? 'SIM Shield User',
          homeCountryCode: user.homeCountryCode ?? 'EG',
          preferredCurrency: user.preferredCurrency,
          isPowerUser: tierId == 'premium',
          subscriptionTier: tierId,
        );

    setState(() {
      _isUpdating = false;
    });

    if (mounted) {
      switch (result) {
        case Success(data: final _):
          await HapticHelper.successFeedback();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Plan successfully updated to ${_plans.firstWhere((p) => p['id'] == tierId)['title']}!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        case Failure(error: final e):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update plan: ${e.message}'),
              backgroundColor: AppColors.error,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final String currentTier =
        user?.subscriptionTier ??
        (user?.isPowerUser == true ? 'premium' : 'standard');
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.onSurfaceColor,
            size: 20,
          ),
          onPressed: () async {
            await HapticHelper.lightTick();
            context.pop();
          },
        ),
        title: Text(
          'Subscription Plans',
          style: AppTextStyles.titleLarge.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isUpdating
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? AppColors.primary : AppColors.lightPrimary,
              ),
            )
          : Stack(
              children: [
                // Top Light Glow
                Positioned(
                  top: -100,
                  left: MediaQuery.of(context).size.width * 0.2,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isDark
                                      ? AppColors.primary
                                      : AppColors.lightPrimary)
                                  .withValues(alpha: 0.12),
                          blurRadius: 100,
                          spreadRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),

                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 10.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Subtitle Header
                      Text(
                        'Premium Shields & Automation',
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: context.onSurfaceColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep your international SIM cards protected automatically without carrier inactivity deletions.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Billed Toggle Selector
                      _buildBillingToggle(),
                      const SizedBox(height: 28),

                      // Interactive Calculator
                      _buildInteractiveCalculator(),
                      const SizedBox(height: 28),

                      // Active Plan Display Card
                      ..._plans.map((plan) {
                        final bool isCurrent = plan['id'] == currentTier;
                        return Column(
                          children: [
                            _buildPlanItem(plan, isCurrent),
                            const SizedBox(height: 20),
                          ],
                        );
                      }),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBillingToggle() {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFEAEEF1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              await HapticHelper.lightTick();
              setState(() {
                _isAnnually = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: !_isAnnually
                    ? (isDark ? AppColors.darkBorder : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: !_isAnnually && !isDark
                    ? const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'Monthly',
                style: AppTextStyles.labelLarge.copyWith(
                  color: !_isAnnually
                      ? context.onSurfaceColor
                      : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              await HapticHelper.lightTick();
              setState(() {
                _isAnnually = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _isAnnually
                    ? (isDark ? AppColors.darkBorder : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isAnnually && !isDark
                    ? const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Text(
                    'Annually',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: _isAnnually
                          ? context.onSurfaceColor
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'SAVE 50%',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCalculator() {
    final isDark = context.isDarkMode;
    final primaryThemeColor = isDark
        ? AppColors.primary
        : AppColors.lightPrimary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard.withValues(alpha: 0.8) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SIM Lines Calculator',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drag to preview pricing for your active lines',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: primaryThemeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryThemeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$_sliderLinesCount ${_sliderLinesCount == 1 ? 'Line' : 'Lines'}',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: primaryThemeColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryThemeColor,
              inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
              thumbColor: isDark ? Colors.white : primaryThemeColor,
              overlayColor: primaryThemeColor.withValues(alpha: 0.15),
              valueIndicatorColor: primaryThemeColor,
              valueIndicatorTextStyle: const TextStyle(color: Colors.white),
            ),
            child: Slider(
              value: _sliderLinesCount.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_sliderLinesCount lines',
              onChanged: (val) async {
                await HapticHelper.lightTick();
                setState(() {
                  _sliderLinesCount = val.toInt();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1 Line',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                Text(
                  '10+ Lines',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanItem(Map<String, dynamic> plan, bool isCurrent) {
    final String planId = plan['id'];
    final String price = _calculatePrice(
      planId: planId,
      linesCount: _sliderLinesCount,
      isAnnually: _isAnnually,
    );
    final String originalPrice = _calculateOriginalPrice(
      planId: planId,
      linesCount: _sliderLinesCount,
      isAnnually: _isAnnually,
    );
    final String billingNote = _getBillingNote(
      planId: planId,
      linesCount: _sliderLinesCount,
      isAnnually: _isAnnually,
    );
    final bool isFree = planId == 'basic';
    final Color planColor = plan['color'] as Color;
    final bool isPopular = plan['isPopular'] ?? false;
    final isDark = context.isDarkMode;

    // Check if plan is disabled for current line count
    bool isPlanDisabled = false;
    String disabledMessage = '';
    if (planId == 'basic' && _sliderLinesCount > 1) {
      isPlanDisabled = true;
      disabledMessage = 'Free Plan cap is 1 line';
    } else if (planId == 'standard' && _sliderLinesCount > 5) {
      isPlanDisabled = true;
      disabledMessage = 'Starter Plan cap is 5 lines';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard.withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent
              ? planColor
              : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.lightBorder),
          width: isCurrent ? 2.0 : 1.0,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: planColor.withValues(alpha: isDark ? 0.12 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            if (isPopular)
              Positioned(
                right: -12,
                top: -12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: planColor.withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                  child: Text(
                    'MOST POPULAR',
                    style: AppTextStyles.caption.copyWith(
                      color: planColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plan Title and Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        plan['title'],
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: context.onSurfaceColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isPlanDisabled)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (!isFree) ...[
                              Text(
                                '\$$originalPrice',
                                style: AppTextStyles.headlineLarge.copyWith(
                                  color:
                                      (isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight)
                                          .withValues(alpha: 0.6),
                                  fontWeight: FontWeight.normal,
                                  fontSize: 18,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '→',
                                style: TextStyle(
                                  color: planColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              '\$$price',
                              style: AppTextStyles.headlineLarge.copyWith(
                                color: context.onSurfaceColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 32,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFree ? 'Always free' : '/mo',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            'NOT AVAILABLE',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Dynamic Billing Note / Limit Indicator
                  if (!isPlanDisabled && !isFree) ...[
                    Text(
                      billingNote,
                      style: AppTextStyles.caption.copyWith(
                        color: planColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Description
                  Text(
                    plan['desc'],
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      height: 1.3,
                    ),
                  ),
                  Divider(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    height: 28,
                    thickness: 1.2,
                  ),

                  // Feature Checklist
                  ...((plan['features'] as List<String>).map((feature) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: planColor,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              feature,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: context.onSurfaceColor.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  })),
                  const SizedBox(height: 24),

                  // Upgrade / Active Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (isCurrent || isPlanDisabled)
                          ? null
                          : () => _updatePlan(plan['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCurrent
                            ? (isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.04))
                            : planColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: isCurrent
                              ? BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.black.withValues(alpha: 0.1),
                                )
                              : BorderSide.none,
                        ),
                        elevation: isCurrent ? 0 : 5,
                        shadowColor: planColor.withValues(alpha: 0.3),
                      ),
                      child: Text(
                        isCurrent
                            ? 'Your Current Active Plan'
                            : isPlanDisabled
                            ? disabledMessage
                            : 'Select ${plan['title']}',
                        style: TextStyle(
                          color: (isCurrent || isPlanDisabled)
                              ? (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight)
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
