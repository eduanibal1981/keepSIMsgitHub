import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────
              Text(
                'More',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage your profile, SIM lines, alerts, and shared preferences',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 24),

              // ── Profile Glassmorphic Card ──────────────────────────
              if (user != null) ...[
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard.withOpacity(0.6) : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder,
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            (user.fullName ?? user.email)
                                .substring(0, 1)
                                .toUpperCase(),
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.fullName ?? 'SIM Shield User',
                                    style: AppTextStyles.titleMedium.copyWith(
                                      color: context.onSurfaceColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (user.isPowerUser) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFBBF24),
                                          Color(0xFFF59E0B),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (user.homeCountryCode != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '🌍 Home Country: ${user.homeCountryCode!.toUpperCase()}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isDark ? Colors.white.withOpacity(0.8) : context.onSurfaceColor.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getPlanColor(user.subscriptionTier).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _getPlanColor(user.subscriptionTier).withOpacity(0.4),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    '🛡️ ${_getPlanName(user.subscriptionTier).toUpperCase()}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: _getPlanColor(user.subscriptionTier),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    context.push('/settings/subscription');
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Upgrade',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: Colors.purpleAccent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.keyboard_arrow_right_rounded,
                                          color: Colors.purpleAccent,
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // ── Navigation Console Section ─────────────────────────
              Text(
                'Console',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),

              _buildMenuCard(
                context: context,
                icon: Icons.star_border_rounded,
                iconColor: Colors.purpleAccent,
                title: 'Upgrade & Subscription',
                subtitle: 'Manage active protection plans, limits, and billing',
                routePath: '/settings/subscription',
              ),
              const SizedBox(height: 16),

              _buildMenuCard(
                context: context,
                icon: Icons.wifi_off_rounded,
                iconColor: Colors.deepOrangeAccent,
                title: 'Offline Refill (SMS/WA)',
                subtitle: 'Refill SIM balance offline via SMS or WhatsApp',
                routePath: '/settings/offline-recharge',
              ),
              const SizedBox(height: 16),

              _buildMenuCard(
                context: context,
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF14B8A6), // Teal color for Wallet
                title: 'Wallet',
                subtitle: 'Manage your balances and view transaction history',
                routePath: '/wallet',
              ),
              const SizedBox(height: 16),

              // Household feature temporarily hidden
              // _buildMenuCard(
              //   context: context,
              //   icon: Icons.people_outline_rounded,
              //   iconColor: const Color(0xFF3B82F6),
              //   title: 'Household & Family',
              //   subtitle: 'Manage family members, invitations & shared lines',
              //   routePath: '/settings/household',
              // ),
              // const SizedBox(height: 16),

              _buildMenuCard(
                context: context,
                icon: Icons.notifications_none_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Alert Preferences',
                subtitle: 'Toggle push & email settings for renewals/balances',
                routePath: '/notifications/settings',
              ),
              const SizedBox(height: 16),

              _buildMenuCard(
                context: context,
                icon: Icons.card_giftcard_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Refer & Earn',
                subtitle: 'Share SIM Shield, unlock dynamic balance rewards',
                routePath: '/settings/referrals',
                isComingSoon: false,
              ),
              const SizedBox(height: 16),

              _buildMenuCard(
                context: context,
                icon: Icons.credit_card_rounded,
                iconColor: const Color(0xFFEC4899),
                title: 'Payment Methods',
                subtitle: 'Add bank cards or link auto-withdrawal accounts',
                routePath: '/settings/payments',
                isComingSoon: false,
              ),
              const SizedBox(height: 16),

              _buildMenuCard(
                context: context,
                icon: Icons.map_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Travel & Geolocation',
                subtitle: 'Manage home country freeze rules & travel mode',
                routePath: '/settings/geo',
                isComingSoon: false,
              ),
              const SizedBox(height: 16),

              _buildMenuCard(
                context: context,
                icon: Icons.tune_rounded,
                iconColor: const Color(0xFFA855F7),
                title: 'Preferences & Security',
                subtitle: 'Manage theme, language, and biometric lockouts',
                routePath: '/settings/preferences',
                isComingSoon: false,
              ),
              
              if (user != null && user.isPowerUser) ...[
                const SizedBox(height: 16),
                _buildMenuCard(
                  context: context,
                  icon: Icons.developer_board_rounded,
                  iconColor: Colors.amber,
                  title: 'Power User',
                  subtitle: 'Access system simulators and debugging tools',
                  routePath: '/settings/simulators',
                  isComingSoon: false,
                ),
              ],
              
              const SizedBox(height: 36),

              // ── Log Out Button ─────────────────────────────────────
              Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmSignOut(context, ref),
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    label: Text(
                      'Log Out',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Colors.redAccent.withOpacity(0.2),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String routePath,
    bool isComingSoon = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard.withOpacity(0.4) : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : AppColors.lightBorder, width: 1.0),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () {
            if (isComingSoon) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$title feature is coming soon!',
                    style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                  ),
                  backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                ),
              );
            } else {
              context.push(routePath);
            }
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18.0,
              vertical: 16.0,
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: context.onSurfaceColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          if (isComingSoon) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'SOON',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white.withOpacity(0.3) : AppColors.textTertiaryLight,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark ? BorderSide.none : const BorderSide(color: AppColors.lightBorder),
        ),
        title: Text('Log Out', style: TextStyle(color: context.onSurfaceColor)),
        content: Text(
          'Are you sure you want to log out of SIM Shield?',
          style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondaryLight),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authControllerProvider.notifier).signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getPlanColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'basic':
        return Colors.blueAccent;
      case 'standard':
        return AppColors.primary;
      case 'premium':
        return Colors.purpleAccent;
      default:
        return AppColors.primary;
    }
  }

  String _getPlanName(String tier) {
    switch (tier.toLowerCase()) {
      case 'basic':
        return 'Free';
      case 'standard':
        return 'Starter';
      case 'premium':
        return 'Premium';
      default:
        return 'Starter';
    }
  }
}
