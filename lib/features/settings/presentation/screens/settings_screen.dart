import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header with Back Button ────────────────────────────
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                      ),
                      color: context.onSurfaceColor,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Back to Home',
                      onPressed: () {
                        HapticHelper.lightTick();
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go(AppRoutes.home);
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Settings',
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'App appearance, security, preferences, and device settings',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Profile Glassmorphic Card (Tappable to View Profile) ──
                if (user != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCard.withValues(alpha: 0.6)
                          : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.lightBorder,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.04,
                          ),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        onTap: () {
                          HapticHelper.lightTick();
                          context.push(AppRoutes.profile);
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6366F1),
                                      Color(0xFFA855F7),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF6366F1,
                                      ).withValues(alpha: 0.4),
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
                                    style: AppTextStyles.headlineMedium
                                        .copyWith(
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            user.fullName ??
                                                AppLocalizations.of(
                                                  context,
                                                )!.keepSIMsUser,
                                            style: AppTextStyles.titleMedium
                                                .copyWith(
                                                  color: context.onSurfaceColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (user.isPowerUser) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.pro,
                                              style: const TextStyle(
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
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
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
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.06,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.04,
                                                ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '🌍 ${AppLocalizations.of(context)!.homeCountry}${user.homeCountryCode!.toUpperCase()}',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: isDark
                                                    ? Colors.white.withValues(
                                                        alpha: 0.8,
                                                      )
                                                    : context.onSurfaceColor
                                                        .withValues(alpha: 0.8),
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.3)
                                    : AppColors.textTertiaryLight,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── App Appearance (Direct Switcher) ───────────────────
                Text(
                  AppLocalizations.of(context)!.appAppearance,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                _buildThemeSelector(context, ref, isDark),
                const SizedBox(height: 28),

                // ── Settings Console Section ───────────────────────────
                Text(
                  'PREFERENCES & SECURITY',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),

                // 1. Security & App Lock
                _buildMenuCard(
                  context: context,
                  icon: Icons.lock_outline_rounded,
                  iconColor: const Color(0xFFA855F7),
                  title: AppLocalizations.of(context)!.securityAndAccessLock,
                  subtitle: 'Transaction PIN, biometric lock & authentication',
                  routePath: AppRoutes.preferences,
                ),
                const SizedBox(height: 16),

                // 2. Alert Preferences
                _buildMenuCard(
                  context: context,
                  icon: Icons.notifications_none_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: AppLocalizations.of(context)!.alertPreferences,
                  subtitle: AppLocalizations.of(context)!.togglePushEmailDesc,
                  routePath: '/notifications/settings',
                ),
                const SizedBox(height: 16),

                // 3. Travel & Geolocation
                _buildMenuCard(
                  context: context,
                  icon: Icons.map_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: AppLocalizations.of(context)!.travelAndGeolocation,
                  subtitle: AppLocalizations.of(context)!.manageHomeCountryDesc,
                  routePath: AppRoutes.geo,
                ),
                const SizedBox(height: 16),

                // 4. Data & Privacy
                _buildMenuCard(
                  context: context,
                  icon: Icons.privacy_tip_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: AppLocalizations.of(context)!.dataAndPrivacy,
                  subtitle: AppLocalizations.of(
                    context,
                  )!.manageTrackingConsentDesc,
                  routePath: AppRoutes.privacy,
                ),
                const SizedBox(height: 16),

                // 5. Your Devices
                _buildMenuCard(
                  context: context,
                  icon: Icons.devices_rounded,
                  iconColor: const Color(0xFF22C55E),
                  title: AppLocalizations.of(context)!.yourDevices,
                  subtitle: AppLocalizations.of(context)!.manageDevicesDesc,
                  routePath: AppRoutes.devices,
                ),

                // 6. Power User Simulators (Debug only)
                if (kDebugMode && user != null && user.isPowerUser) ...[
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    context: context,
                    icon: Icons.developer_board_rounded,
                    iconColor: Colors.amber,
                    title: AppLocalizations.of(context)!.powerUser,
                    subtitle: AppLocalizations.of(
                      context,
                    )!.accessSystemSimulatorsDesc,
                    routePath: AppRoutes.simulators,
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
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        AppLocalizations.of(context)!.logOut,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(
                          alpha: 0.1,
                        ),
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.redAccent.withValues(alpha: 0.2),
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
      ),
    );
  }

  // ── Theme Selector Segmented Control ─────────────────────────────────
  Widget _buildThemeSelector(BuildContext context, WidgetRef ref, bool isDark) {
    final prefsState = ref.watch(userPreferencesControllerProvider);
    final selectedTheme = prefsState.value?.theme ?? 'system';

    final modes = [
      {
        'code': 'system',
        'label': AppLocalizations.of(context)!.systemTheme,
        'icon': Icons.settings_brightness_rounded,
      },
      {
        'code': 'dark',
        'label': AppLocalizations.of(context)!.darkMode,
        'icon': Icons.dark_mode_rounded,
      },
      {
        'code': 'light',
        'label': AppLocalizations.of(context)!.lightMode,
        'icon': Icons.light_mode_rounded,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard.withValues(alpha: 0.5)
            : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.lightBorder,
          width: 1.0,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: modes.map((mode) {
          final isSelected = mode['code'] == selectedTheme;
          return Expanded(
            child: InkWell(
              onTap: () async {
                await HapticHelper.lightTick();
                ref
                    .read(userPreferencesControllerProvider.notifier)
                    .updateTheme(mode['code'] as String);
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mode['icon'] as IconData,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? Colors.white70
                              : AppColors.textSecondaryLight),
                      size: 20,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mode['label'] as String,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? Colors.white70
                                : AppColors.textSecondaryLight),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
        color: isDark
            ? AppColors.darkCard.withValues(alpha: 0.4)
            : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.lightBorder,
          width: 1.0,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
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
                    AppLocalizations.of(context)!.featureComingSoon(title),
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  backgroundColor: isDark
                      ? AppColors.darkCard
                      : AppColors.lightCard,
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
                    color: iconColor.withValues(alpha: 0.1),
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
                          Flexible(
                            child: Text(
                              title,
                              style: AppTextStyles.titleMedium.copyWith(
                                color: context.onSurfaceColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.soon,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
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
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : AppColors.textTertiaryLight,
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
          side: isDark
              ? BorderSide.none
              : const BorderSide(color: AppColors.lightBorder),
        ),
        title: Text(
          AppLocalizations.of(context)!.logOut,
          style: TextStyle(color: context.onSurfaceColor),
        ),
        content: Text(
          AppLocalizations.of(context)!.confirmLogOut,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
              ),
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
            child: Text(
              AppLocalizations.of(context)!.logOut,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
