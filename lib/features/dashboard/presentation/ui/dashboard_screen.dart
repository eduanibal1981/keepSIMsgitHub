/// SIM Shield — Dashboard Screen
///
/// A highly premium, glowing dark-mode home dashboard.
library;

import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/dashboard/presentation/controller/dashboard_controller.dart';
import 'package:intl/intl.dart';

import 'package:keep_sims/core/widgets/shimmer_loading.dart';
import 'package:keep_sims/core/widgets/error_state.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/dashboard/presentation/widgets/dashboard_sim_line_card.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:keep_sims/core/providers/locale_provider.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/core/services/esim_capability_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentLineIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProfileState = ref.watch(authControllerProvider);
    final dashboardState = ref.watch(dashboardControllerProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      body: authProfileState.when(
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Text(
                'Access Denied. Please sign in.',
                style: TextStyle(color: context.onSurfaceColor),
              ),
            );
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: dashboardState.hasValue
                ? _buildDashboardContent(
                    context,
                    ref,
                    profile,
                    dashboardState.value!,
                  )
                : dashboardState.hasError
                ? ErrorStateView(
                    errorMessage: 'Failed to load dashboard data',
                    errorDetails: dashboardState.error.toString(),
                    onRetry: () => ref.invalidate(dashboardControllerProvider),
                  )
                : const DashboardShimmer(),
          );
        },
        loading: () => Scaffold(
          backgroundColor: context.scaffoldBackgroundColor,
          body: const DashboardShimmer(),
        ),
        error: (err, stack) => Scaffold(
          backgroundColor: context.scaffoldBackgroundColor,
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
    final networkStatus = ref.watch(connectivityServiceProvider);
    final isOffline = networkStatus == NetworkStatus.offline;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: context.surfaceColor,
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
              // ── Offline Mode Banner ────────────────────────────────
              if (isOffline) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amberAccent.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: Colors.amberAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Running Offline Mode',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isLight
                                    ? AppColors.textPrimaryLight
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'You can still manage your SIM cards! Changes will automatically sync when connection returns.',
                              style: AppTextStyles.caption.copyWith(
                                color: isLight
                                    ? AppColors.textSecondaryLight
                                    : AppColors.textSecondaryDark,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Header Row ──────────────────────────────────────────
              _buildHeader(context, ref, welcomeName, isPowerUser),
              const SizedBox(height: 24),

              // ── "At a Glance" Glassmorphic Hero Card ──────────────────
              _buildHeroCard(context, profile.preferredCurrency, data, profile),
              const SizedBox(height: 28),

              // ── Protected SIM Line Health Cards ─────────────────────
              _buildHealthSection(context, ref, profile.id),
              const SizedBox(height: 28),

              // ── Quick Actions ───────────────────────────────────────
              _buildQuickActionsSection(context, profile),
              const SizedBox(height: 28),

              // ── Recent Activity timeline ────────────────────────────
              _buildActivityTimeline(context, data.recentActivities),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header Widget ───────────────────────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    String name,
    bool isPowerUser,
  ) {
    final notificationsState = ref.watch(notificationsControllerProvider);
    final unreadCount = notificationsState.maybeWhen(
      data: (list) => list.where((n) => !n.isRead).length,
      orElse: () => 0,
    );

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
              style: TextStyle(
                color: context.onSurfaceColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.welcomeBack,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.onSurfaceColor.withValues(alpha: 0.6),
                ),
              ),
              Text(
                name,
                style: AppTextStyles.headlineLarge.copyWith(
                  color: context.onSurfaceColor,
                ),
              ),
            ],
          ),
        ),

        // Language Selector Icon Button
        IconButton(
          icon: const Icon(Icons.translate_rounded, size: 22),
          color: context.onSurfaceColor.withValues(alpha: 0.8),
          tooltip: 'App Language',
          onPressed: () async {
            await HapticHelper.lightTick();
            if (context.mounted) {
              _showLanguageSelector(context);
            }
          },
        ),

        // Help Icon Button
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, size: 22),
          color: context.onSurfaceColor.withValues(alpha: 0.8),
          tooltip: 'Help & Support',
          onPressed: () async {
            await HapticHelper.lightTick();
            if (context.mounted) {
              _showHelpModalSheet(context);
            }
          },
        ),

        // Alerts Icon Button with dynamic unread badge
        IconButton(
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(
              unreadCount > 9 ? '9+' : unreadCount.toString(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.healthRed,
            child: const Icon(Icons.notifications_outlined, size: 24),
          ),
          color: context.onSurfaceColor.withValues(alpha: 0.8),
          tooltip: 'Alerts',
          onPressed: () async {
            await HapticHelper.lightTick();
            if (context.mounted) {
              context.push(AppRoutes.notifications);
            }
          },
        ),
      ],
    );
  }

  // ── Help Modal Sheet ───────────────────────────────────────────
  void _showLanguageSelector(BuildContext context) {
    final currentLang = ref.read(localeControllerProvider).languageCode;
    final languages = [
      {'code': 'en', 'name': 'English (US)', 'flag': '🇺🇸'},
      {'code': 'es', 'name': 'Español (Spanish)', 'flag': '🇪🇸'},
      {'code': 'hi', 'name': 'हिन्दी (Hindi)', 'flag': '🇮🇳'},
      {'code': 'ur', 'name': 'اردو (Urdu)', 'flag': '🇵🇰'},
      {'code': 'tr', 'name': 'Türkçe (Turkish)', 'flag': '🇹🇷'},
      {'code': 'si', 'name': 'සිංහල (Sinhala)', 'flag': '🇱🇰'},
      {'code': 'ne', 'name': 'नेपाली (Nepali)', 'flag': '🇳🇵'},
      {'code': 'bn', 'name': 'বাংলা (Bengali)', 'flag': '🇧🇩'},
      {'code': 'ar', 'name': 'العربية (Arabic)', 'flag': '🇦🇪'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: context.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: context.onSurfaceColor.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.selectAppLanguage,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: languages.map((lang) {
                        final isSelected = lang['code'] == currentLang;
                        return InkWell(
                          onTap: () async {
                            await HapticHelper.mediumImpact();
                            ref
                                .read(
                                  userPreferencesControllerProvider.notifier,
                                )
                                .updateLanguage(lang['code']!);
                            ref
                                .read(localeControllerProvider.notifier)
                                .setLocale(Locale(lang['code']!));
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                            await HapticHelper.successFeedback();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? context.onSurfaceColor.withValues(
                                      alpha: 0.05,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(
                                        0xFF6366F1,
                                      ).withValues(alpha: 0.3)
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  lang['flag']!,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  lang['name']!,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: context.onSurfaceColor,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                const Spacer(),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF6366F1),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Help Modal Sheet ───────────────────────────────────────────
  void _showHelpModalSheet(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isLight ? AppColors.lightSurface : AppColors.darkSurface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border(
              top: BorderSide(
                color: isLight ? AppColors.lightBorder : AppColors.darkBorder,
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.lightBorder
                        : AppColors.darkBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.help_outline_rounded,
                      color: context.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Help & Support',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: isLight
                          ? AppColors.textPrimaryLight
                          : AppColors.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'How can we help you?',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isLight
                      ? AppColors.textSecondaryLight
                      : AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 16),
              _buildHelpBulletPoint(
                context,
                Icons.menu_book_rounded,
                'Browse FAQs & troubleshooting guides',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/support/faq');
                },
              ),
              const SizedBox(height: 10),
              _buildHelpBulletPoint(
                context,
                Icons.support_agent_rounded,
                'Open Ticket to report your problem',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/support/create?category=Technical Support');
                },
              ),
              const SizedBox(height: 10),
              _buildHelpBulletPoint(
                context,
                Icons.bug_report_rounded,
                'Submit Feedback and request improvements',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/support/create?category=Feedback & Other');
                },
              ),
              const SizedBox(height: 28),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHelpBulletPoint(
    BuildContext context,
    IconData icon,
    String text, {
    VoidCallback? onTap,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: AppColors.secondary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isLight
                      ? AppColors.textPrimaryLight
                      : AppColors.textPrimaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isLight ? Colors.black26 : Colors.white30,
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero Card Widget ────────────────────────────────────────────
  void _showHeroCardActionSheet(BuildContext context, String topUpId) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isLight ? AppColors.lightSurface : AppColors.darkSurface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border(
              top: BorderSide(
                color: isLight ? AppColors.lightBorder : AppColors.darkBorder,
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.lightBorder
                        : AppColors.darkBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Line Action',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: isLight
                      ? AppColors.textPrimaryLight
                      : AppColors.textPrimaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'What would you like to do?',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isLight
                      ? AppColors.textSecondaryLight
                      : AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 24),
              _buildHelpBulletPoint(
                context,
                Icons.sim_card_outlined,
                'Open nearest top-up line',
                onTap: () {
                  Navigator.pop(context);
                  context.push('${AppRoutes.simLines}/detail/$topUpId');
                },
              ),
              const SizedBox(height: 10),
              _buildHelpBulletPoint(
                context,
                Icons.add_circle_outline,
                'Protect new line',
                onTap: () {
                  Navigator.pop(context);
                  context.push('${AppRoutes.simLines}/add');
                },
              ),
              const SizedBox(height: 28),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    String currency,
    DashboardState data,
    UserProfile profile,
  ) {
    final bool isPremium = profile.isPowerUser;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final int nextTopUpMinutes = data.nextTopUpDate != null
        ? data.nextTopUpDate!.difference(DateTime.now()).inMinutes.clamp(0, 60)
        : 0;
    final bool isHourlyMode =
        data.nextTopUpTotalDays == 0 && data.nextTopUpId != null;

    // Format the next top-up date
    final DateTime dueDate =
        data.nextTopUpDate ??
        DateTime.now().add(Duration(days: data.nextTopUpDays));
    final String formattedDate = data.nextTopUpDate != null
        ? (isHourlyMode
              ? DateFormat('MMMM dd, yyyy HH:mm').format(dueDate)
              : DateFormat('MMMM dd, yyyy').format(dueDate))
        : 'No Line Configuration';

    final double progress = data.nextTopUpDate != null
        ? (data.nextTopUpTotalDays > 0
              ? (data.nextTopUpDays / data.nextTopUpTotalDays).clamp(0.0, 1.0)
              : (isHourlyMode
                    ? (nextTopUpMinutes / 60.0).clamp(0.0, 1.0)
                    : 1.0))
        : 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative background glowing circular elements
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: isDark ? 0.02 : 0.01),
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
                    if (data.nextTopUpId != null) {
                      _showHeroCardActionSheet(context, data.nextTopUpId!);
                    } else {
                      context.push('${AppRoutes.simLines}/add');
                    }
                  },
                  splashColor: context.onSurfaceColor.withValues(alpha: 0.05),
                  highlightColor: context.onSurfaceColor.withValues(alpha: 0.02),
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
                      children: [
                        // Left Side - Circular Ring Progress Indicator
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 82,
                              height: 82,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 7,
                                backgroundColor: context.onSurfaceColor
                                    .withValues(alpha: 0.08),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.success,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  data.nextTopUpDate != null
                                      ? (isHourlyMode
                                            ? '$nextTopUpMinutes'
                                            : '${data.nextTopUpDays}')
                                      : '0',
                                  style: AppTextStyles.headlineMedium.copyWith(
                                    color: context.onSurfaceColor,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  isHourlyMode
                                      ? 'mins'
                                      : AppLocalizations.of(context)!.days,
                                  style: AppTextStyles.caption.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),

                        // Right Side - SIM line info & dates
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      isPremium
                                          ? 'NEXT TOP-UP'
                                          : AppLocalizations.of(
                                              context,
                                            )!.nextNotify,
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (data.nextTopUpDate != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        AppLocalizations.of(context)!.active,
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                              color: AppColors.success,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formattedDate,
                                style: AppTextStyles.headlineSmall.copyWith(
                                  color: context.onSurfaceColor,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data.nextTopUpDate != null
                                    ? (data.nextTopUpNickname != null
                                          ? '${data.nextTopUpNickname} • ${data.nextTopUpPhone}'
                                          : '${data.nextTopUpPhone}')
                                    : 'Add or configure a SIM line',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Divider(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                      height: 1,
                      thickness: 1.2,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.showingNearestLine,
                          style: AppTextStyles.caption.copyWith(
                            color:
                                (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight)
                                    .withValues(alpha: 0.7),
                          ),
                        ),
                        Text(
                          data.totalLines == 1
                              ? '1 line'
                              : '${data.totalLines} lines',
                          style: AppTextStyles.caption.copyWith(
                            color: context.onSurfaceColor,
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

  Widget _buildHealthSection(
    BuildContext context,
    WidgetRef ref,
    String currentUserId,
  ) {
    final simLinesState = ref.watch(simLinesControllerProvider);
    final householdState = ref.watch(householdControllerProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.linesToProtect,
              style: AppTextStyles.headlineSmall.copyWith(
                color: context.onSurfaceColor,
              ),
            ),
            TextButton.icon(
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.primary,
              ),
              label: Text(
                AppLocalizations.of(context)!.addSim,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
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
            if (lines.isEmpty) {
              return _buildEmptyCTA(context);
            }

            return Column(
              children: [
                SizedBox(
                  height: 275,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentLineIndex = index;
                      });
                    },
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: DashboardSimLineCard(line: line),
                      );
                    },
                  ),
                ),
                if (lines.length > 1) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      lines.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentLineIndex == index ? 12 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentLineIndex == index
                              ? context.primaryColor
                              : (context.isDarkMode
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight)
                                    .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
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
        color: context.surfaceColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: context.theme.shadowColor.withValues(alpha: 0.2),
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
              color: AppColors.primary.withValues(alpha: 0.1),
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
              color: context.onSurfaceColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep your active mobile numbers protected from deactivation. Secure your first SIM card now.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.onSurfaceColor.withValues(alpha: 0.6),
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
            icon: Icon(
              Icons.add_moderator_rounded,
              size: 18,
              color: context.onSurfaceColor,
            ),
            label: Text(
              'Protect Your First SIM',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.onSurfaceColor,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: context.onSurfaceColor,
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

  // ── Quick Actions Section ───────────────────────────────────────
  Widget _buildQuickActionsSection(BuildContext context, dynamic profile) {
    final esimCapability = ref.watch(esimCapabilityServiceProvider);
    final bool isEsimSupported = esimCapability.maybeWhen(
      data: (supported) => supported,
      orElse: () => false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.quickActions,
          style: AppTextStyles.headlineSmall.copyWith(
            color: context.onSurfaceColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildQuickActionCard(
              context,
              assetIcon: 'assets/images/esim.png',
              label: 'eSIM',
              color: const Color(0xFF6366F1),
              enabled: isEsimSupported,
              subtitle: isEsimSupported ? null : 'Device not supported',
              onTap: isEsimSupported
                  ? () async {
                      await HapticHelper.lightTick();
                      if (context.mounted) {
                        context.push(AppRoutes.esim);
                      }
                    }
                  : null,
            ),
            const SizedBox(width: 12),
            _buildQuickActionCard(
              context,
              icon: Icons.account_balance_wallet_rounded,
              label: AppLocalizations.of(context)!.wallet,
              color: const Color(0xFF14B8A6),
              onTap: () async {
                await HapticHelper.lightTick();
                context.go('/wallet');
              },
            ),
            const SizedBox(width: 12),
            _buildQuickActionCard(
              context,
              icon: Icons.support_agent_rounded,
              label: AppLocalizations.of(context)!.openTicket,
              color: Colors.blueAccent,
              onTap: () async {
                await HapticHelper.lightTick();
                if (context.mounted) {
                  context.push('/support/create');
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showOpenTicketSheet(BuildContext context) {
    String selectedCategory = 'Technical Support';
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    bool isSubmitting = false;
    final isLight = Theme.of(context).brightness == Brightness.light;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isLight ? AppColors.lightSurface : AppColors.darkSurface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(
                    color: isLight
                        ? AppColors.lightBorder
                        : AppColors.darkBorder,
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isLight
                            ? AppColors.lightBorder
                            : AppColors.darkBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: Colors.blueAccent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Open Support Ticket',
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: isLight
                              ? AppColors.textPrimaryLight
                              : AppColors.textPrimaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Ticket Category',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isLight
                          ? AppColors.textSecondaryLight
                          : AppColors.textSecondaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    dropdownColor: isLight
                        ? AppColors.lightCard
                        : AppColors.darkCard,
                    style: TextStyle(
                      color: isLight
                          ? AppColors.textPrimaryLight
                          : Colors.white,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isLight
                          ? const Color(0xFFEAEEF1)
                          : Colors.black.withValues(alpha: 0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isLight
                              ? AppColors.lightBorder
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                    items:
                        [
                              'Technical Support',
                              'Billing & Wallet',
                              'SIM Lines Management',
                              'Feedback & Other',
                            ]
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedCategory = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Subject',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isLight
                          ? AppColors.textSecondaryLight
                          : AppColors.textSecondaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: subjectController,
                    style: TextStyle(
                      color: isLight
                          ? AppColors.textPrimaryLight
                          : Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Summary of the issue',
                      hintStyle: TextStyle(
                        color: isLight
                            ? AppColors.textTertiaryLight
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                      filled: true,
                      fillColor: isLight
                          ? const Color(0xFFEAEEF1)
                          : Colors.black.withValues(alpha: 0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isLight
                              ? AppColors.lightBorder
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Message Details',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isLight
                          ? AppColors.textSecondaryLight
                          : AppColors.textSecondaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    style: TextStyle(
                      color: isLight
                          ? AppColors.textPrimaryLight
                          : Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Describe the issue or request in detail...',
                      hintStyle: TextStyle(
                        color: isLight
                            ? AppColors.textTertiaryLight
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                      filled: true,
                      fillColor: isLight
                          ? const Color(0xFFEAEEF1)
                          : Colors.black.withValues(alpha: 0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isLight
                              ? AppColors.lightBorder
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (subjectController.text.trim().isEmpty ||
                                  messageController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please fill out all fields.',
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              setModalState(() {
                                isSubmitting = true;
                              });

                              // Mock network delay
                              await Future.delayed(const Duration(seconds: 1));

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Ticket submitted successfully under $selectedCategory! ID: #T-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'Submit Support Ticket',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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
    ).whenComplete(() {
      subjectController.dispose();
      messageController.dispose();
    });
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    IconData? icon,
    String? assetIcon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool enabled = true,
    String? subtitle,
  }) {
    final double opacity = enabled ? 1.0 : 0.45;

    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (assetIcon != null)
                  Image.asset(
                    assetIcon,
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                  )
                else
                  Icon(icon, color: color, size: 28),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: context.onSurfaceColor.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Recent Activity timeline Widget ─────────────────────────────
  Widget _buildActivityTimeline(
    BuildContext context,
    List<DashboardActivity> activities,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity Log',
          style: AppTextStyles.headlineSmall.copyWith(
            color: context.onSurfaceColor,
          ),
        ),
        const SizedBox(height: 16),
        if (activities.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No recent activity records',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.onSurfaceColor.withValues(alpha: 0.4),
                ),
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
                            child: Icon(
                              timelineIcon,
                              color: iconColor,
                              size: 16,
                            ),
                          ),
                        ),
                        if (index < activities.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: context.dividerColor,
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
                                    style: AppTextStyles.titleMedium.copyWith(
                                      color: context.onSurfaceColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  act.timeAgo,
                                  style: AppTextStyles.caption.copyWith(
                                    color: context.onSurfaceColor.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              act.subtitle,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.onSurfaceColor.withValues(
                                  alpha: 0.6,
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
            },
          ),
      ],
    );
  }
}
