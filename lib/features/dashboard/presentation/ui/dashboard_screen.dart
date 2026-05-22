/// SIM Shield — Dashboard Screen
///
/// A highly premium, glowing dark-mode home dashboard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/dashboard/presentation/controller/dashboard_controller.dart';
import 'package:keep_sims/core/widgets/shimmer_loading.dart';
import 'package:keep_sims/core/widgets/error_state.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/wallet/ui/wallet_screen.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/sim_line_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authProfileState = ref.watch(authControllerProvider);
    final dashboardState = ref.watch(dashboardControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: authProfileState.when(
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text(
                'Access Denied. Please sign in.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: KeyedSubtree(
              key: ValueKey(dashboardState.isLoading),
              child: dashboardState.when(
                data: (data) => _buildDashboardContent(context, ref, profile, data),
                loading: () => const DashboardShimmer(),
                error: (err, stack) => ErrorStateView(
                  errorMessage: 'Failed to load dashboard data',
                  errorDetails: err.toString(),
                  onRetry: () => ref.invalidate(dashboardControllerProvider),
                ),
              ),
            ),
          );
        },
        loading: () => const Scaffold(
          backgroundColor: AppColors.darkBg,
          body: DashboardShimmer(),
        ),
        error: (err, stack) => Scaffold(
          backgroundColor: AppColors.darkBg,
          body: ErrorStateView(
            errorMessage: 'Authentication checkpoint failed',
            errorDetails: err.toString(),
            onRetry: () => ref.invalidate(authControllerProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    dynamic profile,
    DashboardState data,
  ) {
    final String welcomeName = profile.fullName ?? 'User';
    final bool isPowerUser = profile.isPowerUser;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.darkSurface,
      onRefresh: () async {
        await HapticHelper.mediumImpact();
        await ref.read(dashboardControllerProvider.notifier).refreshDashboard();
        await HapticHelper.successFeedback();
      },
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ──────────────────────────────────────────
              _buildHeader(welcomeName, isPowerUser),
              const SizedBox(height: 24),

              // ── "At a Glance" Glassmorphic Hero Card ──────────────────
              _buildHeroCard(context, profile.preferredCurrency, data),
              const SizedBox(height: 28),

              // ── Protected SIM Line Health Cards ─────────────────────
              _buildHealthSection(context, ref, profile.id),
              const SizedBox(height: 28),

              // ── Recent Activity timeline ────────────────────────────
              _buildActivityTimeline(data.recentActivities),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header Widget ───────────────────────────────────────────────
  Widget _buildHeader(String name, bool isPowerUser) {
    return Row(
      children: [
        // Glowing Avatar placeholder
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              name.substring(0, name.isNotEmpty ? 1 : 0).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome Back',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
              ),
              Text(
                name,
                style: AppTextStyles.headlineLarge.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
        // Power User Badge
        if (isPowerUser)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, color: AppColors.textPrimaryLight, size: 14),
                const SizedBox(width: 4),
                Text(
                  'POWER USER',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Hero Card Widget ────────────────────────────────────────────
  Widget _buildHeroCard(BuildContext context, String currency, DashboardState data) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Glass overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            
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

            // Splash & InkWell tap area
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    await HapticHelper.mediumImpact();
                    if (!context.mounted) return;
                    _showDepositModalSheet(context);
                  },
                  splashColor: Colors.white.withValues(alpha: 0.1),
                  highlightColor: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

            // Card content layout
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SHIELD WALLET BALANCE',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        // Sleek interactive indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'LOAD',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.add_circle_outline_rounded,
                              color: AppColors.secondary,
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$${data.walletBalance.toStringAsFixed(2)} $currency',
                      style: AppTextStyles.walletBalance.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    // Sub metrics grid
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHeroStat('Lines Active', '${data.totalLines} Protected'),
                        _buildHeroStat('Monthly Spend', '\$${data.monthlySpend.toStringAsFixed(2)}'),
                        _buildHeroStat('Next Top-Up', '${data.nextTopUpDays} Days Left'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Expiry Progress bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Renewal Schedule Health',
                              style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.7)),
                            ),
                            Text(
                              '${((data.nextTopUpTotalDays - data.nextTopUpDays) / data.nextTopUpTotalDays * 100).toInt()}% Elapsed',
                              style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (data.nextTopUpTotalDays - data.nextTopUpDays) / data.nextTopUpTotalDays,
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Last Auto Charge',
                          style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        Text(
                          data.lastChargeDate != null && data.lastChargePhone != null
                              ? '${data.lastChargeDate} • ${data.lastChargePhone}'
                              : 'None Recorded',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDepositModalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DepositModalSheet(),
    );
  }

  Widget _buildHeroStat(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  // ── SIM Protection Health Widget ────────────────────────────────
  Widget _buildHealthSection(BuildContext context, WidgetRef ref, String currentUserId) {
    final simLinesState = ref.watch(simLinesControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Protected Lines',
              style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              onPressed: () async {
                await HapticHelper.lightTick();
                if (context.mounted) {
                  context.push('/sim-lines/add');
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        simLinesState.when(
          data: (lines) {
            final myLines = lines.where((line) => line.userId == currentUserId).toList();

            if (myLines.isEmpty) {
              return _buildEmptyCTA(context);
            }

            return Column(
              children: myLines
                  .map((line) => SimLineCard(
                        line: line,
                        showActions: false,
                      ))
                  .toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Failed to load protected lines: $err',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCTA(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Protected SIM Lines',
            style: AppTextStyles.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep your active mobile numbers protected from deactivation. Secure your first SIM card now.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              await HapticHelper.lightTick();
              if (context.mounted) {
                context.go(AppRoutes.simLines);
              }
            },
            icon: const Icon(Icons.add_moderator_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Protect Your First SIM',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent Activity timeline Widget ─────────────────────────────
  Widget _buildActivityTimeline(List<DashboardActivity> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity Log',
          style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 16),
        if (activities.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No recent activity records',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiaryDark),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final act = activities[index];
              Color iconBgColor = AppColors.primary.withValues(alpha: 0.1);
              Color iconColor = AppColors.primary;
              IconData timelineIcon = Icons.info_outline;

              switch (act.type) {
                case 'topup':
                  iconBgColor = AppColors.success.withValues(alpha: 0.15);
                  iconColor = AppColors.success;
                  timelineIcon = Icons.check_circle_outline_rounded;
                case 'deposit':
                  iconBgColor = AppColors.secondary.withValues(alpha: 0.15);
                  iconColor = AppColors.secondary;
                  timelineIcon = Icons.account_balance_wallet_outlined;
                case 'alert':
                  iconBgColor = AppColors.error.withValues(alpha: 0.15);
                  iconColor = AppColors.error;
                  timelineIcon = Icons.warning_amber_rounded;
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Timeline dots & lines
                    Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(timelineIcon, color: iconColor, size: 16),
                          ),
                        ),
                        if (index < activities.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: AppColors.darkBorder,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Description column
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    act.title,
                                    style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  act.timeAgo,
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiaryDark),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              act.subtitle,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
