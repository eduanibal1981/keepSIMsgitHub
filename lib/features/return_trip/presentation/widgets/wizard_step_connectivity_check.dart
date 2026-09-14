import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import '../controllers/return_trip_wizard_controller.dart';

class WizardStepConnectivityCheck extends StatelessWidget {
  final String countryName;
  final String? carrierName;
  final ReturnTripWizardState state;
  final ReturnTripWizardController controller;

  const WizardStepConnectivityCheck({
    super.key,
    required this.countryName,
    this.carrierName,
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    if (state.isCheckingEsim) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Checking Device Compatibility...',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.onSurfaceColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Detecting eSIM hardware and network capabilities',
                style: AppTextStyles.caption.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final hasEsim = state.hasEsimSupport;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary Result Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182234) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasEsim
                    ? const Color(0xFF10B981).withValues(alpha: 0.5)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: (hasEsim ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                            .withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: hasEsim
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasEsim ? Icons.sim_card_download_rounded : Icons.sim_card_rounded,
                        color: hasEsim ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasEsim
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              hasEsim ? 'ESIM SUPPORTED' : 'PHYSICAL SIM ONLY',
                              style: TextStyle(
                                color: hasEsim ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasEsim
                                ? 'Your device supports eSIM'
                                : 'Your device uses Physical SIM',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: context.onSurfaceColor,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(
                  color: isDark ? const Color(0xFF263348) : const Color(0xFFF1F5F9),
                  height: 1,
                ),
                const SizedBox(height: 14),
                Text(
                  hasEsim
                      ? 'Great news! You can install an instant travel eSIM with unlimited data, or recharge data directly on your existing ${carrierName ?? countryName} SIM.'
                      : 'No eSIM hardware was detected on this device. You will receive direct carrier recharge codes (USSD / PIN) that activate instant 4G data on your physical ${carrierName ?? countryName} SIM upon arrival.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Feature Details
          Text(
            'What happens next?',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: context.onSurfaceColor,
            ),
          ),
          const SizedBox(height: 10),

          _buildStepDetailCard(
            context,
            icon: Icons.inventory_2_outlined,
            title: 'Curated Data Packages for $countryName',
            description: hasEsim
                ? 'We have matched both the cheapest 1-day unlimited eSIM and local carrier recharge passes.'
                : 'We have filtered the best carrier data packs for ${carrierName ?? countryName}.',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildStepDetailCard(
            context,
            icon: Icons.price_check_rounded,
            title: 'Tier Discounts Applied on App Fees',
            description: 'Premium users pay \$0 app fee (100% off). Standard users get 50% discount on the app fee.',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildStepDetailCard(
            context,
            icon: Icons.bolt_rounded,
            title: 'Ready upon Touchdown',
            description: 'Your line details and instructions will be saved in your console so you connect immediately.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStepDetailCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182234) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.onSurfaceColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
