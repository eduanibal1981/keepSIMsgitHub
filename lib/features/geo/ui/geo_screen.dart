import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import '../controller/geo_controller.dart';
import '../model/geo_state.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/profile/presentation/widgets/subscription_upsell_sheet.dart';

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
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geoState = ref.watch(geoControllerProvider);
    final authProfile = ref.watch(authControllerProvider).valueOrNull;
    final homeCountry = authProfile?.homeCountryCode ?? 'US';

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () async {
            await HapticHelper.lightTick();
            context.pop();
          },
        ),
        title: Text(
          'Travel & Geolocation',
          style: AppTextStyles.titleLarge.copyWith(
            color: Colors.white,
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
                    color: AppColors.primary.withOpacity(0.15),
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
                    color: AppColors.secondary.withOpacity(0.1),
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
                  // Section 1: Animated Radar Shield Hero
                  _buildRadarShieldHero(geoState.travelModeEnabled),
                  const SizedBox(height: 25),

                  // Section 2: Active Geo Location Banner
                  _buildActiveGeoBanner(geoState, homeCountry),
                  const SizedBox(height: 20),

                  // Section 3: Smart Prompts (Freeze & Resume recommendations)
                  if (geoState.promptFreeze) _buildFreezeRecommendationCard(),
                  if (geoState.promptResume) _buildResumeRecommendationCard(),
                  if (geoState.promptFreeze || geoState.promptResume)
                    const SizedBox(height: 20),

                  // Section 4: Travel Mode Settings Switch
                  _buildTravelModeCard(geoState),
                  const SizedBox(height: 20),

                  // Section 5: Border Crossing Simulator (Flight Boarding Gate)
                  _buildSimulatorConsole(geoState, homeCountry),
                  const SizedBox(height: 20),

                  // Section 6: Real-time Diagnostics Terminal
                  _buildDiagnosticsTerminal(geoState.logs),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Loader Overlay
          if (geoState.isProcessing)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.secondary),
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
          // Radar Dotted Rings
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
                                      ? AppColors.secondary
                                      : AppColors.primary)
                                  .withOpacity(opacity.clamp(0.0, 1.0)),
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),

          // Core Hologram Node
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
                  color: (travelMode ? AppColors.secondary : AppColors.primary)
                      .withOpacity(0.4),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isHome ? AppColors.primary : AppColors.secondary)
                      .withOpacity(0.15),
                ),
                child: Icon(
                  isHome ? Icons.home_rounded : Icons.public_rounded,
                  color: isHome ? AppColors.primaryLight : AppColors.secondary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHome ? 'AT HOME' : 'ABROAD / TRAVELING',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isHome
                            ? AppColors.primaryLight
                            : AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${geoState.currentCountry} (${geoState.currentIsoCode})',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.darkBorder, height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shield Protection',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Fully Shielded',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
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

  Widget _buildFreezeRecommendationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.ac_unit_rounded,
                color: AppColors.primaryLight,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Welcome Home! 🏡',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'We detected you are currently in your Home Country. You can freeze renewals on your international lines to prevent unwanted wallet balance depletion.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await HapticHelper.mediumImpact();
                    ref
                        .read(geoControllerProvider.notifier)
                        .freezeAllInternationalLines();
                  },
                  child: Text(
                    'Freeze All Lines',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onPressed: () async {
                  await HapticHelper.lightTick();
                  ref
                      .read(geoControllerProvider.notifier)
                      .dismissFreezePrompt();
                },
                child: Text(
                  'Dismiss',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumeRecommendationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flash_on_rounded,
                color: AppColors.secondary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Travel Detected! ✈️',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'You are traveling abroad. Please resume your paused international SIM renewals to ensure uninterrupted mobile network coverage.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await HapticHelper.mediumImpact();
                    ref
                        .read(geoControllerProvider.notifier)
                        .resumeAllInternationalLines();
                  },
                  child: Text(
                    'Resume Renewals',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onPressed: () async {
                  await HapticHelper.lightTick();
                  ref
                      .read(geoControllerProvider.notifier)
                      .dismissResumePrompt();
                },
                child: Text(
                  'Dismiss',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTravelModeCard(GeoState geoState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Global Travel Mode',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Allows automated geofencing rules to activate border-crossing routines.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: geoState.travelModeEnabled,
            activeColor: AppColors.secondary,
            activeTrackColor: AppColors.secondary.withOpacity(0.3),
            inactiveThumbColor: AppColors.textSecondaryDark,
            inactiveTrackColor: AppColors.darkBorder,
            onChanged: (val) async {
              final user = ref.read(authControllerProvider).valueOrNull;
              final tier = user?.subscriptionTier ?? 'standard';
              if (tier == 'basic') {
                SubscriptionUpsellSheet.show(
                  context: context,
                  title: 'Starter Feature Locked 🔒',
                  description: 'Automated Global Travel & Home modes are available starting from the Starter Plan. Upgrade now to freeze renewals when you are home!',
                  requiredPlan: 'Starter Plan',
                  highlights: [
                    'Smart Travel / Home modes active',
                    'Protect up to 5 SIM cards simultaneously',
                    'All notifications (WhatsApp, Telegram, Email)',
                  ],
                );
                return;
              }
              await HapticHelper.mediumImpact();
              ref.read(geoControllerProvider.notifier).toggleTravelMode(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatorConsole(GeoState geoState, String homeCountry) {
    final double buttonHeight = 46.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flight_takeoff_rounded,
                color: AppColors.primaryLight,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Border Crossing Simulator',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Simulate boardings to trigger smart freeze or active country resumption rules.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 20),

          // Flight terminal select options
          Row(
            children: [
              Expanded(
                child: _buildFlightTicket(
                  flag: '🏡',
                  label: 'Fly Home',
                  countryName: 'Home Country',
                  isoCode: homeCountry,
                  geoState: geoState,
                  height: buttonHeight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFlightTicket(
                  flag: '🇬🇧',
                  label: 'London',
                  countryName: 'United Kingdom',
                  isoCode: 'GB',
                  geoState: geoState,
                  height: buttonHeight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFlightTicket(
                  flag: '🇦🇪',
                  label: 'Dubai',
                  countryName: 'United Arab Emirates',
                  isoCode: 'AE',
                  geoState: geoState,
                  height: buttonHeight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFlightTicket(
                  flag: '🇸🇬',
                  label: 'Singapore',
                  countryName: 'Singapore',
                  isoCode: 'SG',
                  geoState: geoState,
                  height: buttonHeight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlightTicket({
    required String flag,
    required String label,
    required String countryName,
    required String isoCode,
    required GeoState geoState,
    required double height,
  }) {
    final bool isCurrent = geoState.currentIsoCode == isoCode;

    return Container(
      height: height,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isCurrent
              ? AppColors.secondary.withOpacity(0.08)
              : Colors.transparent,
          side: BorderSide(
            color: isCurrent ? AppColors.secondary : AppColors.darkBorder,
            width: isCurrent ? 1.5 : 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () async {
          final user = ref.read(authControllerProvider).valueOrNull;
          final tier = user?.subscriptionTier ?? 'standard';
          if (tier == 'basic') {
            SubscriptionUpsellSheet.show(
              context: context,
              title: 'Starter Feature Locked 🔒',
              description: 'The Border Crossing Simulator allows testing automated freeze/resume scripts. This feature requires at least the Starter Plan!',
              requiredPlan: 'Starter Plan',
              highlights: [
                'Test and simulate geofencing scenarios',
                'Smart Travel / Home modes active',
                'WhatsApp & Telegram notification channels',
              ],
            );
            return;
          }
          await HapticHelper.mediumImpact();
          ref
              .read(geoControllerProvider.notifier)
              .simulateTravelTo(isoCode, countryName);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: isCurrent ? AppColors.secondary : Colors.white,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsTerminal(List<String> logs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SYSTEM DIAGNOSTICS LOGS',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ONLINE',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            height: 120,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                // Return bottom first to look like command terminal
                final log = logs[logs.length - 1 - index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    log,
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
