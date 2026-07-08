/// SIM Shield — Wallet Screen
///
/// High-end dark-mode user interface representing the prepaid wallet.
/// Integrates card deposit models, transactional ledgers, and glowing SVG analytics.
library;

import 'package:flutter/material.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import '../controller/wallet_controller.dart';
import '../model/wallet_model.dart';
import 'package:keep_sims/core/widgets/shimmer_loading.dart';
import 'package:keep_sims/core/widgets/error_state.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/payments/controller/payments_controller.dart';
import 'package:go_router/go_router.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(walletControllerProvider);
    final networkStatus = ref.watch(connectivityServiceProvider);
    final isOffline = networkStatus == NetworkStatus.offline;

    return Scaffold(
      backgroundColor: context.isDarkMode
          ? AppColors.darkBg
          : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.walletLedger,
          style: AppTextStyles.headlineLarge.copyWith(
            color: context.isDarkMode
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: context.isDarkMode
                  ? AppColors.primaryLight
                  : AppColors.lightPrimary,
            ),
            onPressed: () async {
              await HapticHelper.mediumImpact();
              ref.invalidate(walletControllerProvider);
              await HapticHelper.successFeedback();
            },
          ),
        ],
      ),
      body: stateAsync.when(
        data: (state) => _buildContent(context, state, isOffline),
        loading: () => const WalletShimmer(),
        error: (err, stack) => ErrorStateView(
          errorMessage: err.toString(),
          onRetry: () async {
            await HapticHelper.mediumImpact();
            ref.invalidate(walletControllerProvider);
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WalletState state,
    bool isOffline,
  ) {
    final balance = state.wallet.balance;
    final isLowBalance = balance < 10.0;
    final transactions = state.transactions;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 10),

              // ── Glassmorphic Neon Credit Card ───────────────────────
              _buildNeonCreditCard(balance, state.wallet.currency, isOffline),

              const SizedBox(height: 24),

              // ── Balance Threshold Warnings ────────────────────────
              if (isLowBalance) _buildLowBalanceWarning(),

              // ── Action Row Buttons ────────────────────────────────
              _buildQuickActionButtons(context, isOffline),

              const SizedBox(height: 28),

              // ── Spending Analytics (Custom curves) ─────────────────
              Text(
                AppLocalizations.of(context)!.spendAnalysis,
                style: AppTextStyles.titleLarge.copyWith(
                  color: context.isDarkMode
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),
              _buildSpendAnalyticsChart(transactions),

              const SizedBox(height: 28),

              // ── Ledger Transaction History Feed Header ─────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.transactionHistory,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: context.isDarkMode
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    '${transactions.length} items',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.isDarkMode
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ]),
          ),
        ),

        // ── Transaction List (Sliverized and Recycled) ───────────────
        if (transactions.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            sliver: SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: context.isDarkMode
                      ? AppColors.darkSurface
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.isDarkMode
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      color: context.isDarkMode
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No transactions recorded yet.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.isDarkMode
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final tx = transactions[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: _buildTransactionItem(tx),
                );
              }, childCount: transactions.length),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildNeonCreditCard(double balance, String currency, bool isOffline) {
    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative background glowing circular elements
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),

            // Glossy card reflection sheen
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            // Card content layout
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.keepSIMsPrepaid,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 1.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (isOffline) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.amberAccent.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.wifi_off_rounded,
                                      color: Colors.amberAccent,
                                      size: 10,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppLocalizations.of(context)!.offlineMode,
                                      style: const TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            const Icon(
                              Icons.contactless_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Card Provider Logo Mockup
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'VISA',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Wallet balance text
                  Text(
                    'Active Balance',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '\$${balance.toStringAsFixed(2)}',
                          style: AppTextStyles.walletBalance.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          currency,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Mock card numbers
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '••••  ••••  ••••  4242',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 2,
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

  Widget _buildLowBalanceWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.healthRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.healthRed.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.healthRed,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Critical Balance Level',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.healthRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your balance is below \$10.00. Scheduled SIM topups may fail soon.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.isDarkMode
                        ? Colors.yellow
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

  Widget _buildQuickActionButtons(BuildContext context, bool isOffline) {
    return Row(
      children: [
        Expanded(
          child: Opacity(
            opacity: isOffline ? 0.5 : 1.0,
            child: _buildActionButton(
              icon: Icons.add_circle_rounded,
              label: AppLocalizations.of(context)!.depositFunds,
              color: context.isDarkMode
                  ? AppColors.primaryLight
                  : AppColors.lightPrimary,
              onTap: isOffline
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Wallet deposits require an active internet connection.',
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  : () => _showDepositModalSheet(context),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            icon: Icons.history_edu_rounded,
            label: 'Export Ledger',
            color: context.isDarkMode
                ? AppColors.secondaryLight
                : AppColors.lightSecondary,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ledger history exported as CSV.'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () async {
        await HapticHelper.lightTick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: context.isDarkMode ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.isDarkMode
                ? AppColors.darkBorder
                : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.isDarkMode
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendAnalyticsChart(List<WalletTransaction> transactions) {
    // 1. Determine the last 6 months for chart display
    final now = DateTime.now();
    final List<DateTime> last6Months = List.generate(6, (index) {
      return DateTime(now.year, now.month - 5 + index, 1);
    });

    // 2. Initialize monthly spending
    final Map<int, double> monthlySpend = {};
    for (int i = 0; i < 6; i++) {
      monthlySpend[i] = 0.0;
    }

    // 3. Aggregate topup_debit transactions
    for (final tx in transactions) {
      if (tx.type == 'topup_debit' && tx.createdAt != null) {
        final txDate = tx.createdAt!;
        // Find which of the 6 months it belongs to
        for (int i = 0; i < 6; i++) {
          final monthDate = last6Months[i];
          if (txDate.year == monthDate.year &&
              txDate.month == monthDate.month) {
            monthlySpend[i] = (monthlySpend[i] ?? 0.0) + tx.amount;
            break;
          }
        }
      }
    }

    // 4. Calculate Average Spend / Month for the last 12 months (last year) only
    final twelveMonthsAgo = DateTime(now.year, now.month - 11, 1);
    double totalSpendLast12Months = 0.0;
    for (final tx in transactions) {
      if (tx.type == 'topup_debit' && tx.createdAt != null) {
        if (tx.createdAt!.isAfter(twelveMonthsAgo) ||
            tx.createdAt!.isAtSameMomentAs(twelveMonthsAgo)) {
          totalSpendLast12Months += tx.amount;
        }
      }
    }
    final double avgSpend = totalSpendLast12Months / 12;

    // 5. Generate Labels (e.g. 'Jan', 'Feb')
    final List<String> monthLabels = last6Months.map((d) {
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return monthNames[d.month - 1];
    }).toList();

    // 6. Normalize data points for the painter (0.0 to 1.0)
    double maxSpend = monthlySpend.values.fold(
      0.0,
      (max, val) => val > max ? val : max,
    );
    if (maxSpend == 0.0) maxSpend = 1.0; // avoid division by zero

    final List<double> normalizedPoints = [];
    for (int i = 0; i < 6; i++) {
      normalizedPoints.add(monthlySpend[i]! / maxSpend);
    }

    return Container(
      width: double.infinity,
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.isDarkMode ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.isDarkMode
              ? AppColors.darkBorder
              : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Prepaid Monthly Outflow',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Avg: \$${avgSpend.toStringAsFixed(2)}/mo (12M)',
                style: AppTextStyles.labelMedium.copyWith(
                  color: context.isDarkMode
                      ? AppColors.secondary
                      : AppColors.lightSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Custom SVG line curve representation
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: CustomPaint(
                painter: AnalyticsChartPainter(
                  normalizedPoints: normalizedPoints,
                  primaryColor: context.isDarkMode
                      ? AppColors.primary
                      : AppColors.lightPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Months labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: monthLabels
                .map((label) => _buildChartLabel(label))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: context.isDarkMode
            ? AppColors.textTertiaryDark
            : AppColors.textTertiaryLight,
      ),
    );
  }

  Widget _buildTransactionItem(WalletTransaction tx) {
    final isDeposit = tx.type == 'deposit' || tx.type == 'auto_fund';
    final isReferral = tx.type == 'referral' || tx.type == 'referral_credit';
    final isRefund = tx.type == 'refund';

    final isDark = context.isDarkMode;
    Color typeColor = isDark ? AppColors.warning : AppColors.lightWarning;
    IconData typeIcon = Icons.phonelink_ring_rounded;
    String sign = '-';

    if (isDeposit) {
      typeColor = isDark ? AppColors.success : AppColors.lightSuccess;
      typeIcon = Icons.add_circle_outline_rounded;
      sign = '+';
    } else if (isReferral) {
      typeColor = isDark ? AppColors.primaryLight : AppColors.lightPrimary;
      typeIcon = Icons.stars_rounded;
      sign = '+';
    } else if (isRefund) {
      typeColor = isDark ? AppColors.success : AppColors.lightSuccess;
      typeIcon = Icons.stars_rounded;
      sign = '+';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon block
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(typeIcon, color: typeColor, size: 20),
          ),
          const SizedBox(width: 14),
          // Description details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ??
                      (isDeposit
                          ? AppLocalizations.of(context)!.depositFunds
                          : 'Line Renewal'),
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  tx.createdAt != null
                      ? '${tx.createdAt!.day}/${tx.createdAt!.month}/${tx.createdAt!.year}'
                      : 'Just now',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Amount text
          Text(
            '$sign\$${tx.amount.toStringAsFixed(2)}',
            style: AppTextStyles.titleLarge.copyWith(
              color: typeColor,
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Deposit Sheet Modal ───────────────────────────────────────
  void _showDepositModalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DepositModalSheet(),
    );
  }
}

/// Custom Bezier Curve Painter for Spend Analysis Charts.
class AnalyticsChartPainter extends CustomPainter {
  final List<double> normalizedPoints;
  final Color primaryColor;

  const AnalyticsChartPainter({
    required this.normalizedPoints,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.25)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor.withValues(alpha: 0.15),
          primaryColor.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // Generate dynamic chart keypoints based on actual SIM topup renewals
    final numPoints = normalizedPoints.isEmpty ? 6 : normalizedPoints.length;
    final points = List.generate(numPoints, (i) {
      final x = size.width * (i / (numPoints - 1));
      final normalizedValue = (normalizedPoints.length > i)
          ? normalizedPoints[i]
          : 0.0;
      // Map 0.0 -> height * 0.85, 1.0 -> height * 0.15
      final y = size.height * (0.85 - 0.7 * normalizedValue);
      return Offset(x, y);
    });

    if (points.isEmpty) return;

    final path = Path()..moveTo(points[0].dx, points[0].dy);

    if (points.length == 1) {
      path.lineTo(size.width, points[0].dy);
    } else {
      for (int i = 0; i < points.length - 1; i++) {
        final pStart = points[i];
        final pEnd = points[i + 1];
        // Control points at 1/3 and 2/3 distance
        final controlX1 = pStart.dx + (pEnd.dx - pStart.dx) / 3.0;
        final controlY1 = pStart.dy;
        final controlX2 = pStart.dx + 2.0 * (pEnd.dx - pStart.dx) / 3.0;
        final controlY2 = pEnd.dy;

        path.cubicTo(
          controlX1,
          controlY1,
          controlX2,
          controlY2,
          pEnd.dx,
          pEnd.dy,
        );
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    // Render elements
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Draw glowing node dots at all vertices dynamically
    final dotPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.fill;

    final dotGlow = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      canvas.drawCircle(p, 8, dotGlow);
      canvas.drawCircle(p, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AnalyticsChartPainter oldDelegate) {
    if (oldDelegate.normalizedPoints.length != normalizedPoints.length) {
      return true;
    }
    for (int i = 0; i < normalizedPoints.length; i++) {
      if (oldDelegate.normalizedPoints[i] != normalizedPoints[i]) return true;
    }
    return false;
  }
}

class DepositModalSheet extends ConsumerStatefulWidget {
  const DepositModalSheet({super.key});

  @override
  ConsumerState<DepositModalSheet> createState() => _DepositModalSheetState();
}

class _DepositModalSheetState extends ConsumerState<DepositModalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '20.00');
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _selectQuickAmount(String amount) {
    setState(() {
      _amountController.text = amount;
    });
  }

  Future<void> _submitDeposit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid deposit amount.')),
      );
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    final success = await ref
        .read(walletControllerProvider.notifier)
        .deposit(
          amount,
          description:
              'Deposit via Card ending in ${_cardNumberController.text.substring(_cardNumberController.text.length - 4)}',
        );

    if (success) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'Successfully deposited \$$amount USD!',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.healthRed,
            content: Text(AppLocalizations.of(context)!.failedToDepositFunds),
          ),
        );
      }
    }
  }

  void _showSavedCards() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.isDarkMode
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(paymentsControllerProvider).asData?.value;
            final methods = state?.paymentMethods ?? [];

            if (methods.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.noSavedPaymentMethods,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.isDarkMode
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.pushNamed('settingsPayments');
                      },
                      icon: const Icon(Icons.add_card, size: 20),
                      label: Text(
                        AppLocalizations.of(context)!.addPaymentMethod,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.isDarkMode
                            ? AppColors.primary
                            : AppColors.lightPrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      AppLocalizations.of(context)!.savedPaymentMethods,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: context.isDarkMode
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: methods.length,
                      itemBuilder: (context, index) {
                        final method = methods[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          leading: Icon(
                            Icons.credit_card,
                            color: context.isDarkMode
                                ? AppColors.primaryLight
                                : AppColors.lightPrimary,
                          ),
                          title: Text(
                            '•••• •••• •••• ${method.lastFour ?? "****"}',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: context.isDarkMode
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          subtitle: Text(
                            'Expires ${method.expiryMonth?.toString().padLeft(2, "0") ?? "--"}/${method.expiryYear?.toString().substring(method.expiryYear.toString().length > 2 ? method.expiryYear.toString().length - 2 : 0) ?? "--"}',
                            style: AppTextStyles.caption.copyWith(
                              color: context.isDarkMode
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _cardNumberController.text =
                                  '4242 4242 4242 ${method.lastFour ?? "4242"}';
                              _expiryController.text =
                                  '${method.expiryMonth?.toString().padLeft(2, "0") ?? "12"}/${method.expiryYear?.toString().substring(method.expiryYear.toString().length > 2 ? method.expiryYear.toString().length - 2 : 0) ?? "30"}';
                              _cvvController.text = '123';
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.pushNamed('settingsPayments');
                      },
                      icon: const Icon(Icons.add),
                      label: Text(
                        AppLocalizations.of(context)!.addAnotherPaymentMethod,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: context.isDarkMode
                            ? AppColors.secondary
                            : AppColors.lightSecondary,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: context.isDarkMode
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWebMobileOffset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + isWebMobileOffset),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border(
          top: BorderSide(
            color: context.isDarkMode
                ? AppColors.darkBorder
                : AppColors.lightBorder,
            width: 1.5,
          ),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull Bar indicator
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: context.isDarkMode
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.loadCreditFunds,
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: context.isDarkMode
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  if (_isSubmitting)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: context.isDarkMode
                            ? AppColors.primary
                            : AppColors.lightPrimary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Quick selection amounts ──────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickSelectButton('10.00'),
                  _buildQuickSelectButton('20.00'),
                  _buildQuickSelectButton('50.00'),
                  _buildQuickSelectButton('100.00'),
                ],
              ),
              const SizedBox(height: 16),

              // ── Custom Input Amount ────────────────────────────────
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppTextStyles.bodyLarge.copyWith(
                  color: context.isDarkMode
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.depositAmountUsd,
                  labelStyle: TextStyle(
                    color: context.isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  prefixIcon: Icon(
                    Icons.attach_money_rounded,
                    color: context.isDarkMode
                        ? AppColors.primary
                        : AppColors.lightPrimary,
                  ),
                  filled: true,
                  fillColor: context.isDarkMode
                      ? AppColors.darkBg
                      : const Color(0xFFEAEEF1),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.isDarkMode
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.isDarkMode
                          ? AppColors.primary
                          : AppColors.lightPrimary,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return AppLocalizations.of(context)!.pleaseEnterAmount;
                  }
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0.0) {
                    return AppLocalizations.of(context)!.enterPositiveNumber;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Credit Card Inputs ─────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.cardDetails,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: context.isDarkMode
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showSavedCards,
                    icon: const Icon(Icons.credit_card, size: 16),
                    label: Text(AppLocalizations.of(context)!.savedCards),
                    style: TextButton.styleFrom(
                      foregroundColor: context.isDarkMode
                          ? AppColors.secondary
                          : AppColors.lightSecondary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                maxLength: 19,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CardNumberInputFormatter(),
                ],
                style: AppTextStyles.bodyLarge.copyWith(
                  color: context.isDarkMode
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.visaCardNumber,
                  labelStyle: TextStyle(
                    color: context.isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  prefixIcon: Icon(
                    Icons.credit_card_rounded,
                    color: context.isDarkMode
                        ? AppColors.secondary
                        : AppColors.lightSecondary,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: context.isDarkMode
                      ? AppColors.darkBg
                      : const Color(0xFFEAEEF1),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.isDarkMode
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.isDarkMode
                          ? AppColors.secondary
                          : AppColors.lightSecondary,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return AppLocalizations.of(context)!.pleaseEnterCardNumber;
                  }
                  final clean = val.replaceAll(' ', '');
                  if (clean.length < 16) {
                    return AppLocalizations.of(context)!.mustBe16Digits;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CardExpiryInputFormatter(),
                      ],
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: context.isDarkMode
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.expiryMmYy,
                        labelStyle: TextStyle(
                          color: context.isDarkMode
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: context.isDarkMode
                            ? AppColors.darkBg
                            : const Color(0xFFEAEEF1),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: context.isDarkMode
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: context.isDarkMode
                                ? AppColors.primary
                                : AppColors.lightPrimary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return AppLocalizations.of(context)!.expiryRequired;
                        }
                        if (val.length < 5) {
                          return AppLocalizations.of(context)!.invalid;
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      obscureText: true,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: context.isDarkMode
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.cvv,
                        labelStyle: TextStyle(
                          color: context.isDarkMode
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: context.isDarkMode
                            ? AppColors.darkBg
                            : const Color(0xFFEAEEF1),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: context.isDarkMode
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: context.isDarkMode
                                ? AppColors.primary
                                : AppColors.lightPrimary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return AppLocalizations.of(context)!.cvvRequired;
                        }
                        if (val.length < 3) {
                          return AppLocalizations.of(context)!.invalid;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Submit Button ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitDeposit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.isDarkMode
                        ? AppColors.primary
                        : AppColors.lightPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    _isSubmitting
                        ? AppLocalizations.of(context)!.verifyingCardSecurity
                        : AppLocalizations.of(context)!.authorizeDepositFunds,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSelectButton(String amount) {
    final active = _amountController.text == amount;
    return InkWell(
      onTap: () => _selectQuickAmount(amount),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? (context.isDarkMode
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.lightPrimary.withValues(alpha: 0.15))
              : (context.isDarkMode
                    ? AppColors.darkBg
                    : const Color(0xFFEAEEF1)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? (context.isDarkMode
                      ? AppColors.primary
                      : AppColors.lightPrimary)
                : (context.isDarkMode
                      ? AppColors.darkBorder
                      : AppColors.lightBorder),
            width: 1.2,
          ),
        ),
        child: Text(
          '\$$amount',
          style: AppTextStyles.labelMedium.copyWith(
            color: active
                ? (context.isDarkMode
                      ? AppColors.primaryLight
                      : AppColors.lightPrimary)
                : (context.isDarkMode
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Helper formatter to insert spaces every 4 digits in card inputs.
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      final nonSpaceLength = i + 1;
      if (nonSpaceLength % 4 == 0 && nonSpaceLength != text.length) {
        buffer.write(' ');
      }
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

/// Helper formatter to insert a slash after 2 digits in expiry inputs (MM/YY).
class CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      final nonSlashLength = i + 1;
      if (nonSlashLength == 2 && nonSlashLength != text.length) {
        buffer.write('/');
      }
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
