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
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/dashboard/presentation/controller/dashboard_controller.dart';
import 'package:keep_sims/features/dashboard/presentation/widgets/sim_protection_hero_card.dart';
import 'package:keep_sims/features/dashboard/presentation/widgets/dashboard_feature_cards.dart';

import 'package:keep_sims/core/widgets/shimmer_loading.dart';
import 'package:keep_sims/core/widgets/error_state.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/dashboard/presentation/widgets/dashboard_sim_line_carousel.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:keep_sims/core/providers/locale_provider.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/dashboard/presentation/widgets/promo_banner.dart';
import 'package:keep_sims/features/geo/controller/geo_controller.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(geoControllerProvider.notifier).checkCurrentLocationOnAppOpen();
    });
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
                ? Builder(
                    builder: (context) {
                      final errStr = dashboardState.error.toString();
                      final isAuthError =
                          errStr.toLowerCase().contains('jwt') ||
                          errStr.toLowerCase().contains('token') ||
                          errStr.toLowerCase().contains('authenticated');
                      return ErrorStateView(
                        errorMessage: isAuthError
                            ? 'Session credentials require refresh'
                            : 'Failed to load dashboard data',
                        errorDetails: isAuthError
                            ? 'Authentication credentials refreshed. Tap below to reload your dashboard metrics.'
                            : errStr,
                        actionLabel: isAuthError
                            ? 'Reconnect Dashboard'
                            : 'Initialize Recovery Retry',
                        onRetry: () => ref
                            .read(dashboardControllerProvider.notifier)
                            .refreshDashboard(),
                      );
                    },
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
            actionLabel: 'Re-authenticate',
            onRetry: () async {
              await ref
                  .read(authRepositoryProvider)
                  .ensureValidSession(force: true);
              ref.invalidate(authControllerProvider);
            },
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              _buildHeader(context, ref, welcomeName),
              const SizedBox(height: 12),

              // ── SIM Protection Hero Card ─────────────────────────────
              SimProtectionHeroCard(
                lineCount:
                    ref.watch(simLinesControllerProvider).value?.length ??
                    data.totalLines,
                onManageSims: () async {
                  await HapticHelper.lightTick();
                  if (!context.mounted) return;
                  final lines = ref.read(simLinesControllerProvider).value;
                  final lineCount = lines?.length ?? data.totalLines;
                  if (lineCount == 0) {
                    context.push('${AppRoutes.simLines}/add');
                  } else {
                    context.go(AppRoutes.simLines);
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.dashboardExplore,
                style: AppTextStyles.headlineSmall.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.onSurfaceColor,
                ),
              ),
              const SizedBox(height: 12),
              DashboardFeatureCards(
                onSmartCall: () async {
                  await HapticHelper.lightTick();
                  if (context.mounted) context.push(AppRoutes.calling);
                },
                onVirtualNumbers: () async {
                  await HapticHelper.lightTick();
                  if (context.mounted) context.push(AppRoutes.myNumbers);
                },
                onEsims: () async {
                  await HapticHelper.lightTick();
                  if (context.mounted) context.push(AppRoutes.esim);
                },
              ),
              const SizedBox(height: 12),

              // ── Protected SIM Line Health Cards ─────────────────────
              _buildHealthSection(context, ref, profile.id),
              const SizedBox(height: 28),

              // Keep campaign offers below the SIM lines.
              const PromoBanner(),

              // ── Recent Activity timeline ────────────────────────────
              _buildActivityTimeline(context, data.recentActivities),
            ],
          ),
        ),
      ),
    );
  }

  String _isoToFlagEmoji(String isoCode) {
    if (isoCode.length != 2) return '🌐';
    final String upper = isoCode.toUpperCase();
    final int firstLetter = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  void _showLocationInfoDialog(
    BuildContext context,
    WidgetRef ref,
    String countryName,
    String flagEmoji,
  ) {
    final isDark = context.isDarkMode;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? AppColors.primary : AppColors.lightPrimary)
                      .withValues(alpha: 0.12),
                ),
                child: Text(flagEmoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Current Location',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.onSurfaceColor,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'You are currently detected in '),
                    TextSpan(
                      text: countryName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' $flagEmoji.'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'If this is incorrect, please ensure you are not using a VPN and that your device is online. Tapping Refresh will re-check your location.',
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              child: const Text('OK'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await HapticHelper.mediumImpact();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Re-checking location...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                await ref
                    .read(geoControllerProvider.notifier)
                    .checkCurrentLocationOnAppOpen();
                await ref
                    .read(dashboardControllerProvider.notifier)
                    .refreshDashboard();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (hour < 12) {
      return isArabic ? 'صباح الخير' : 'Good Morning';
    } else if (hour < 17) {
      return isArabic ? 'مساء الخير' : 'Good Afternoon';
    } else {
      return isArabic ? 'مساء الخير' : 'Good Evening';
    }
  }

  // Header actions retain language/location access through the avatar menu.
  Widget _buildHeader(BuildContext context, WidgetRef ref, String name) {
    final l10n = AppLocalizations.of(context)!;
    final unreadCount = ref
        .watch(notificationsControllerProvider)
        .maybeWhen(
          data: (list) => list.where((n) => !n.isRead).length,
          orElse: () => 0,
        );
    final geo = ref.watch(geoControllerProvider);
    final displayName = name.trim().split(' ').first;
    final accent = context.isDarkMode
        ? AppColors.primary
        : const Color(0xFF009BAA);
    return Row(
      children: [
        PopupMenuButton<String>(
          tooltip: l10n.dashboardAccountOptions,
          onSelected: (value) {
            if (value == 'language') _showLanguageSelector(context);
            if (value == 'location') {
              _showLocationInfoDialog(
                context,
                ref,
                geo.currentCountry,
                _isoToFlagEmoji(geo.currentIsoCode),
              );
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'language',
              child: Text(l10n.selectAppLanguage),
            ),
            PopupMenuItem(
              value: 'location',
              child: Text(l10n.dashboardCurrentLocation),
            ),
          ],
          child: CircleAvatar(
            radius: 21,
            backgroundColor: accent,
            child: Text(
              displayName.isEmpty
                  ? 'K'
                  : displayName.characters.first.toUpperCase(),
              style: AppTextStyles.titleLarge.copyWith(
                color: Colors.white,
                fontSize: 19,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getGreeting(context),
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.isDarkMode
                      ? AppColors.textSecondaryDark
                      : const Color(0xFF69758A),
                  fontSize: 12.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayName.isEmpty ? name : displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleMedium.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: context.onSurfaceColor,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.account_balance_wallet_outlined, size: 25),
          tooltip: l10n.wallet,
          color: context.onSurfaceColor,
          onPressed: () async {
            await HapticHelper.lightTick();
            if (context.mounted) context.push(AppRoutes.wallet);
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, size: 26),
          tooltip:
              '${l10n.profileNotifications}${unreadCount > 0 ? ' ($unreadCount)' : ''}',
          color: context.onSurfaceColor,
          onPressed: () async {
            await HapticHelper.lightTick();
            if (context.mounted) context.push(AppRoutes.notifications);
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
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: context.onSurfaceColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.selectAppLanguage,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
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
                  ],
                ),
                const SizedBox(height: 16),
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

  Widget _buildHealthSection(
    BuildContext context,
    WidgetRef ref,
    String currentUserId,
  ) {
    final simLinesState = ref.watch(simLinesControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.dashboardYourSimLines,
                style: AppTextStyles.titleMedium.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.onSurfaceColor,
                ),
              ),
            ),
            TextButton.icon(
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: context.isDarkMode
                    ? AppColors.primary
                    : const Color(0xFF009BAA),
              ),
              label: Text(
                AppLocalizations.of(context)!.addSim,
                style: AppTextStyles.labelLarge.copyWith(
                  color: context.isDarkMode
                      ? AppColors.primary
                      : const Color(0xFF009BAA),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(44, 44),
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
        const SizedBox(height: 8),
        simLinesState.when(
          data: (lines) {
            if (lines.isEmpty) {
              return _buildEmptyCTA(context);
            }

            return DashboardSimLineCarousel(lines: lines);
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
