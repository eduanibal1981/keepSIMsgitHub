import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_line_detail_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/geo/controller/geo_controller.dart';
import '../controllers/return_trip_wizard_controller.dart';
import '../widgets/wizard_step_arrival_date.dart';
import '../widgets/wizard_step_connectivity_check.dart';
import '../widgets/wizard_step_package_selection.dart';
import '../widgets/wizard_step_ready_confirmation.dart';

class ReturnTripWizardScreen extends ConsumerWidget {
  final String simLineId;

  const ReturnTripWizardScreen({
    super.key,
    required this.simLineId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDarkMode;
    final detailAsync = ref.watch(simLineDetailControllerProvider(simLineId));
    final countriesState = ref.watch(supportedCountriesProvider);
    final wizardState = ref.watch(returnTripWizardControllerProvider(simLineId));
    final controller = ref.read(returnTripWizardControllerProvider(simLineId).notifier);

    final line = detailAsync.value?.simLine;
    final countries = countriesState.value ?? [];
    final country = line != null && countries.isNotEmpty
        ? countries.where((c) => c.id == line.countryId).firstOrNull
        : null;

    final countryName = country?.name ?? 'Home';
    final flagEmoji = country?.flagEmoji;
    final userTier = line?.protectionTier ?? 'standard';

    final geoState = ref.watch(geoControllerProvider);
    final userIso = geoState.currentIsoCode.trim().toUpperCase();

    final lineIso = country?.isoCode.trim().toUpperCase();
    final bool isUserInCountry = lineIso != null && userIso == lineIso;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            wizardState.currentStep > 0 && wizardState.currentStep < 3
                ? Icons.arrow_back_ios_new_rounded
                : Icons.close_rounded,
            color: context.onSurfaceColor,
            size: 20,
          ),
          onPressed: () {
            if (wizardState.currentStep > 0 && wizardState.currentStep < 3) {
              controller.previousStep();
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          isUserInCountry ? 'You are at $countryName!' : 'Back to $countryName Wizard',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: context.onSurfaceColor,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getStepTitle(wizardState.currentStep),
                        style: AppTextStyles.caption.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Step ${wizardState.currentStep + 1} of 4',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (wizardState.currentStep + 1) / 4.0,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Error Banner
            if (wizardState.errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        wizardState.errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Step Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: IndexedStack(
                  index: wizardState.currentStep,
                  children: [
                    // Step 0: Arrival Date
                    WizardStepArrivalDate(
                      countryName: countryName,
                      flagEmoji: flagEmoji,
                      state: wizardState,
                      controller: controller,
                      isUserInCountry: isUserInCountry,
                    ),
                    // Step 1: Connectivity Check
                    WizardStepConnectivityCheck(
                      countryName: countryName,
                      carrierName: line?.carrierStatus,
                      state: wizardState,
                      controller: controller,
                    ),
                    // Step 2: Package Selection
                    WizardStepPackageSelection(
                      countryName: countryName,
                      userTier: userTier,
                      state: wizardState,
                      controller: controller,
                    ),
                    // Step 3: Confirmation
                    WizardStepReadyConfirmation(
                      countryName: countryName,
                      flagEmoji: flagEmoji,
                      state: wizardState,
                      onFinish: () => context.pop(),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Controls (Steps 0, 1, 2)
            if (wizardState.currentStep < 3)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF101726) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (wizardState.currentStep > 0) ...[
                      OutlinedButton(
                        onPressed: () {
                          HapticHelper.lightTick();
                          controller.previousStep();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.onSurfaceColor,
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                        child: const Text('Back'),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: wizardState.isSubmitting
                            ? null
                            : () {
                                HapticHelper.lightTick();
                                if (wizardState.currentStep == 0) {
                                  controller.nextStep();
                                } else if (wizardState.currentStep == 1) {
                                  controller.nextStep();
                                } else if (wizardState.currentStep == 2) {
                                  if (line != null && line.countryId != null) {
                                    controller.confirmTrip(
                                      destinationCountryId: line.countryId!,
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: wizardState.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _getNextButtonLabel(wizardState.currentStep),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
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

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Arrival Date';
      case 1:
        return 'Connectivity & Hardware Check';
      case 2:
        return 'Choose Local Data Package';
      case 3:
        return 'Ready for Touchdown';
      default:
        return '';
    }
  }

  String _getNextButtonLabel(int step) {
    switch (step) {
      case 0:
        return 'Check Compatibility →';
      case 1:
        return 'View Data Packages →';
      case 2:
        return 'Confirm Package & Prepare Data';
      default:
        return 'Continue';
    }
  }
}
