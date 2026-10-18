/// SIM Shield — Wallet Screen
///
/// High-end dark-mode user interface representing the prepaid wallet.
/// Integrates card deposit models, transactional ledgers, and glowing SVG analytics.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import '../controller/wallet_controller.dart';
import '../model/wallet_model.dart';
import '../model/gift_transfer_model.dart';
import 'gift_credit_sheet.dart';
import 'refund_funds_sheet.dart';
import 'package:keep_sims/core/widgets/shimmer_loading.dart';
import 'package:keep_sims/core/widgets/error_state.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/payments/presentation/screens/paypal_checkout_screen.dart';

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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.isDarkMode
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            size: 20,
          ),
          tooltip: 'Back',
          onPressed: () {
            HapticHelper.lightTick();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
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

                  // G11 — the same balance in the user's own currency. Renders
                  // nothing at all for a USD user, so the card is unchanged for
                  // everyone who has not chosen otherwise. The dollar figure
                  // above stays the balance; this is only an aid to reading it.
                  ApproxLocalText(
                    balance,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your balance is below \$10.00. Scheduled SIM topups may fail soon.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.isDarkMode
                            ? Colors.yellow
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const ApproxLocalText(10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons(BuildContext context, bool isOffline) {
    return Column(
      children: [
        Row(
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
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: isOffline ? 0.5 : 1.0,
                child: _buildActionButton(
                  icon: Icons.undo_rounded,
                  label: 'Refund Funds',
                  color: Colors.orangeAccent,
                  onTap: isOffline
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Refunds require an active internet connection.',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      : () => _showRefundSheet(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: isOffline ? 0.5 : 1.0,
                child: _buildActionButton(
                  icon: Icons.card_giftcard_rounded,
                  label: 'Send Credit',
                  color: context.isDarkMode
                      ? AppColors.primaryLight
                      : AppColors.lightPrimary,
                  onTap: isOffline
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Sending credit requires an active internet connection.',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      : () => _showGiftSheet(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
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
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            await HapticHelper.lightTick();
            if (context.mounted) {
              context.push('/settings/payments');
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.credit_card_rounded,
                    color: Color(0xFFEC4899),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Methods & Cards',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.isDarkMode
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage credit/debit cards & auto-pay funding',
                        style: AppTextStyles.caption.copyWith(
                          color: context.isDarkMode
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: context.isDarkMode ? Colors.white38 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Refund Funds ─────────────────────────────────────────────
  void _showRefundSheet(BuildContext context) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RefundFundsSheet(),
    );
  }

  // ── Send Credit ──────────────────────────────────────────────
  // The sheet drives `transfer_wallet_credit` and confirms in place; the
  // biometric prompt lives in the controller, on the same guard as a deposit.
  void _showGiftSheet(BuildContext context) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GiftCreditSheet(),
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
    final isRefund = tx.isPurchaseRefund;
    final isSetupRefill =
        tx.metadata?['order_type'] == 'setup_refill' ||
        (tx.description != null &&
            tx.description!.toLowerCase().contains('setup refill'));

    final isDark = context.isDarkMode;
    Color typeColor = isDark ? AppColors.warning : AppColors.lightWarning;
    IconData typeIcon = Icons.phonelink_ring_rounded;
    final sign = tx.amountSign;

    if (isDeposit) {
      typeColor = isDark ? AppColors.success : AppColors.lightSuccess;
      typeIcon = Icons.add_circle_outline_rounded;
    } else if (isReferral) {
      typeColor = isDark ? AppColors.primaryLight : AppColors.lightPrimary;
      typeIcon = Icons.stars_rounded;
    } else if (isRefund) {
      typeColor = isDark ? AppColors.success : AppColors.lightSuccess;
      typeIcon = Icons.stars_rounded;
    } else if (tx.isGiftReceived) {
      typeColor = isDark ? AppColors.success : AppColors.lightSuccess;
      typeIcon = Icons.card_giftcard_rounded;
    } else if (tx.isGiftSent) {
      // Money out, like any debit — but its own icon, because "Gift to Sara"
      // sitting under a top-up icon reads as a charge the user did not make.
      typeColor = isDark ? AppColors.primaryLight : AppColors.lightPrimary;
      typeIcon = Icons.card_giftcard_rounded;
    } else if (isSetupRefill) {
      typeColor = isDark ? AppColors.primaryLight : AppColors.lightPrimary;
      typeIcon = Icons.settings_phone_rounded;
    } else if (tx.isCredit) {
      typeColor = isDark ? AppColors.success : AppColors.lightSuccess;
      typeIcon = Icons.add_circle_outline_rounded;
    }

    // A gift's metadata is the counterparty block, not a PayPal receipt.
    final hasReceipt =
        !tx.isGift && tx.metadata != null && tx.metadata!.isNotEmpty;
    final giftNote = tx.giftNote;

    return GestureDetector(
      onTap: hasReceipt ? () => _showReceiptSheet(tx) : null,
      child: Container(
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
                            : (isSetupRefill
                                  ? (AppLocalizations.of(
                                          context,
                                        )?.setupRefill ??
                                        'Setup Refill')
                                  : 'Line Renewal')),
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
                  if (giftNote != null && giftNote.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '"$giftNote"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
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
            if (hasReceipt) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.receipt_long_rounded,
                size: 16,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Receipt Detail Sheet ─────────────────────────────────────
  // Shows the receipt payload the paypal-webhook stored with the deposit:
  // gross, gateway fee, net payout, method, and the external PayPal ids.
  void _showReceiptSheet(WalletTransaction tx) {
    final meta = tx.metadata!;
    final isDark = context.isDarkMode;

    String money(dynamic v) {
      final parsed = v is num ? v.toDouble() : double.tryParse('$v');
      return parsed != null ? '\$${parsed.toStringAsFixed(2)}' : '—';
    }

    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  color: isDark
                      ? AppColors.primaryLight
                      : AppColors.lightPrimary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Receipt',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            row(
              tx.type == 'deposit' || tx.type == 'auto_fund'
                  ? 'Amount credited'
                  : 'Amount',
              money(tx.amount),
              bold: true,
            ),
            if (meta['order_type'] == 'setup_refill')
              row(
                'Order Type',
                AppLocalizations.of(context)?.setupRefill ?? 'Setup Refill',
              ),
            if (meta['order_type'] != null &&
                meta['order_type'] != 'setup_refill')
              row('Order Type', '${meta['order_type']}'),
            if (meta['gross'] != null)
              row('Gross payment', money(meta['gross'])),
            if (meta['paypal_fee'] != null)
              row('Gateway fee', money(meta['paypal_fee'])),
            if (meta['net'] != null) row('Net payout', money(meta['net'])),
            const Divider(height: 20),
            if (meta['method'] != null)
              row('Method', '${meta['method']}'.toUpperCase()),
            if (meta['paypal_order_id'] != null)
              row('Order ID', '${meta['paypal_order_id']}'),
            if (meta['paypal_capture_id'] != null)
              row('Transaction ID', '${meta['paypal_capture_id']}'),
            if (meta['execution_id'] != null)
              row('Execution ID', '${meta['execution_id']}'),
            if (tx.createdAt != null)
              row(
                'Date',
                '${tx.createdAt!.day}/${tx.createdAt!.month}/${tx.createdAt!.year} '
                    '${tx.createdAt!.hour.toString().padLeft(2, '0')}:${tx.createdAt!.minute.toString().padLeft(2, '0')}',
              ),
          ],
        ),
      ),
    );
  }

  // ── Add Funds ────────────────────────────────────────────────
  // Deposits go through the real PayPal flow; the wallet is credited
  // server-side by the paypal-webhook once PayPal confirms the capture.
  // (The old in-app card form credited a client-chosen amount with no real
  // payment behind it — removed in B3.)
  void _showDepositModalSheet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PayPalCheckoutScreen(
          paymentReason: 'KeepSIMs Wallet Top-up',
          paymentKind: 'deposit',
        ),
      ),
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
