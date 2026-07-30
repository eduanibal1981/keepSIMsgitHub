import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import '../controller/geo_controller.dart';
import '../model/geo_state.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class GeoScreen extends ConsumerStatefulWidget {
  const GeoScreen({super.key});

  @override
  ConsumerState<GeoScreen> createState() => _GeoScreenState();
}

class _GeoScreenState extends ConsumerState<GeoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Trigger IP-based country check on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(geoControllerProvider.notifier).checkCurrentLocationOnAppOpen();
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geoState = ref.watch(geoControllerProvider);
    final authProfile = ref.watch(authControllerProvider).value;
    final homeCountry = authProfile?.homeCountryCode ?? 'US';
    final simLines = ref.watch(simLinesControllerProvider).value ?? [];
    final supportedCountries = ref.watch(supportedCountriesProvider).value ?? [];
    final l10n = AppLocalizations.of(context)!;
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
          l10n.geoTitle,
          style: AppTextStyles.titleLarge.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.primaryColor.withValues(alpha: 0.15),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.colorScheme.secondary.withValues(alpha: 0.1),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          // Main Scrollable Area
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              key: const ValueKey('geo_content_scroll'),
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Radar Shield Hero
                  _buildRadarShieldHero(geoState.travelModeEnabled),
                  const SizedBox(height: 25),

                  // Section 2: Active Geo Location Card
                  _buildActiveGeoBanner(geoState, homeCountry),
                  const SizedBox(height: 20),

                  // Section 2b (G5): "Roam or eSIM?" — only away from home,
                  // which is the only place the comparison means anything.
                  if (geoState.currentIsoCode != homeCountry) ...[
                    _buildRoamCalculatorCard(geoState),
                    const SizedBox(height: 20),
                  ],

                  // Section 3: Smart Prompts (Freeze & Resume recommendations)
                  if (geoState.promptFreeze) _buildFreezeRecommendationCard(),
                  if (geoState.promptResume) _buildResumeRecommendationCard(),
                  if (geoState.promptFreeze || geoState.promptResume)
                    const SizedBox(height: 20),

                  // Section 4: Travel Mode Master Switch
                  _buildTravelModeCard(geoState),
                  const SizedBox(height: 20),

                  // Section 5: Zero-Permission IP Detection Banner
                  _buildGeoNoticeCard(),
                  const SizedBox(height: 20),

                  // Section 6: International Lines Management Card
                  _buildInternationalLinesSection(
                    simLines: simLines,
                    supportedCountries: supportedCountries,
                    homeCountryCode: homeCountry,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Processing Overlay
          if (geoState.isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: CircularProgressIndicator(
                  color: context.colorScheme.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRadarShieldHero(bool travelMode) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _radarController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: List.generate(3, (index) {
                  final double scale =
                      1.0 + (index * 0.4) + (_radarController.value * 0.4);
                  final double opacity =
                      (1.0 -
                          (_radarController.value + index * 0.3).clamp(
                            0.0,
                            1.0,
                          )) *
                      0.4;
                  return Transform.scale(
                    scale: scale.clamp(1.0, 3.0),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              (travelMode
                                      ? context.colorScheme.secondary
                                      : context.primaryColor)
                                  .withValues(alpha: opacity.clamp(0.0, 1.0)),
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: travelMode
                  ? AppColors.accentGradient
                  : AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color:
                      (travelMode
                              ? context.colorScheme.secondary
                              : context.primaryColor)
                          .withValues(alpha: 0.4),
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              travelMode ? Icons.flight_takeoff_rounded : Icons.shield_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveGeoBanner(GeoState geoState, String homeCountry) {
    final bool isHome = geoState.currentIsoCode == homeCountry;
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      (isHome
                              ? context.primaryColor
                              : context.colorScheme.secondary)
                          .withValues(alpha: 0.15),
                ),
                child: Icon(
                  isHome ? Icons.home_rounded : Icons.public_rounded,
                  color: isHome
                      ? (isDark ? AppColors.primaryLight : context.primaryColor)
                      : context.colorScheme.secondary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.currentCountryLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isHome
                            ? (isDark
                                  ? AppColors.primaryLight
                                  : context.primaryColor)
                            : context.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${geoState.currentCountry} (${geoState.currentIsoCode})',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            height: 30,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.detectedViaIp,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    geoState.travelModeEnabled ? 'Active' : 'Standby',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// G5. The geo trigger already knows the user is abroad; this is the step
  /// that turns that into a number they can act on. The country is passed
  /// explicitly so the calculator opens on the detected destination rather than
  /// re-reading `profiles.last_country`, which lags a freshly detected hop.
  Widget _buildRoamCalculatorCard(GeoState geoState) {
    final isDark = context.isDarkMode;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticHelper.lightTick();
        context.push(
          '${AppRoutes.esimRoamCalculator}?country=${geoState.currentIsoCode}',
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.colorScheme.secondary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colorScheme.secondary.withValues(alpha: 0.15),
              ),
              child: Icon(
                Icons.calculate_rounded,
                color: context.colorScheme.secondary,
                size: 26,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Roam or eSIM?',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'See what your own carrier charges to roam in '
                    '${geoState.currentCountry}, next to an eSIM.',
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
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: context.onSurfaceColor.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreezeRecommendationCard() {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.ac_unit_rounded,
                color: isDark ? AppColors.primaryLight : context.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Welcome Home! 🏡',
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'We detected you are currently in your Home Country. You can freeze renewals on your international lines to prevent unwanted wallet balance depletion.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await HapticHelper.mediumImpact();
                    await ref
                        .read(geoControllerProvider.notifier)
                        .freezeAllInternationalLines();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.linesFrozenSuccess)),
                      );
                    }
                  },
                  child: Text(
                    l10n.freezeInternationalLines,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () async {
                  await HapticHelper.lightTick();
                  ref
                      .read(geoControllerProvider.notifier)
                      .dismissFreezePrompt();
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumeRecommendationCard() {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colorScheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colorScheme.secondary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flash_on_rounded,
                color: context.colorScheme.secondary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Travel Detected! ✈️',
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'You are traveling abroad. Resume your paused international SIM renewals to ensure uninterrupted mobile network coverage.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await HapticHelper.mediumImpact();
                    await ref
                        .read(geoControllerProvider.notifier)
                        .resumeAllInternationalLines();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.linesResumedSuccess)),
                      );
                    }
                  },
                  child: Text(
                    l10n.resumeInternationalLines,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isDark ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () async {
                  await HapticHelper.lightTick();
                  ref
                      .read(geoControllerProvider.notifier)
                      .dismissResumePrompt();
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTravelModeCard(GeoState geoState) {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.travelModeToggle,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.travelModeDescription,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: geoState.travelModeEnabled,
            activeThumbColor: context.colorScheme.secondary,
            activeTrackColor: context.colorScheme.secondary.withValues(alpha: 0.3),
            inactiveThumbColor: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            inactiveTrackColor: isDark
                ? AppColors.darkBorder
                : AppColors.lightBorder,
            onChanged: (val) async {
              await HapticHelper.mediumImpact();
              ref.read(geoControllerProvider.notifier).toggleTravelMode(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGeoNoticeCard() {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.geoNotice,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInternationalLinesSection({
    required List<dynamic> simLines,
    required List<dynamic> supportedCountries,
    required String homeCountryCode,
  }) {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    final intlLines = simLines.where((l) {
      final country = supportedCountries.firstWhere(
        (c) => c.id == l.countryId,
        orElse: () => null,
      );
      return country == null || country.isoCode != homeCountryCode;
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'International SIM Lines',
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: intlLines.isEmpty
                        ? null
                        : () async {
                            await HapticHelper.mediumImpact();
                            await ref
                                .read(geoControllerProvider.notifier)
                                .freezeAllInternationalLines();
                          },
                    child: Text(
                      l10n.freezeInternationalLines,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: context.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: intlLines.isEmpty
                        ? null
                        : () async {
                            await HapticHelper.mediumImpact();
                            await ref
                                .read(geoControllerProvider.notifier)
                                .resumeAllInternationalLines();
                          },
                    child: Text(
                      l10n.resumeInternationalLines,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: context.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (intlLines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No international SIM lines registered.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: intlLines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final line = intlLines[index];
                final isPaused = line.status == 'paused';
                final isProtected = line.requiresProtectionAtHome;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPaused
                            ? Icons.pause_circle_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        color: isPaused
                            ? Colors.orange
                            : context.colorScheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.phoneNumber as String? ?? 'SIM Line',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: context.onSurfaceColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isPaused ? 'Status: Frozen' : 'Status: Active',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isPaused
                                    ? Colors.orange
                                    : (isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isProtected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.alwaysProtectedBadge,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: context.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(
                            isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            color: isPaused
                                ? context.colorScheme.secondary
                                : Colors.orange,
                          ),
                          onPressed: () async {
                            await HapticHelper.lightTick();
                            await ref
                                .read(simLinesControllerProvider.notifier)
                                .freezeLine(line.id as String, !isPaused);
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
