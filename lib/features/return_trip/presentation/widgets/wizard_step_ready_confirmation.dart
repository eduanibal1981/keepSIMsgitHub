import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import '../controllers/return_trip_wizard_controller.dart';

class WizardStepReadyConfirmation extends StatelessWidget {
  final String countryName;
  final String? flagEmoji;
  final ReturnTripWizardState state;
  final VoidCallback onFinish;

  const WizardStepReadyConfirmation({
    super.key,
    required this.countryName,
    this.flagEmoji,
    required this.state,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final pkg = state.selectedPackage;
    final arrivalDate = state.arrivalDate ?? DateTime.now();
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),

          // Success Animated Icon
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x3310B981),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'You\'re All Set for $countryName!',
            style: AppTextStyles.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: context.onSurfaceColor,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.4),
              ),
            ),
            child: const Text(
              'DATA READY FOR ARRIVAL',
              style: TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Trip & Package Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182234) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  icon: Icons.flight_land_rounded,
                  label: 'Arrival Date',
                  value: state.isAlreadyArrived ? 'Already Arrived' : dateFormat.format(arrivalDate),
                  isDark: isDark,
                  context: context,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    color: isDark ? const Color(0xFF263348) : const Color(0xFFF1F5F9),
                    height: 1,
                  ),
                ),
                if (pkg != null) ...[
                  _buildSummaryRow(
                    icon: pkg.isEsim ? Icons.sim_card_download_rounded : Icons.cell_tower_rounded,
                    label: 'Chosen Package',
                    value: '${pkg.title} (${pkg.formattedAllowance})',
                    isDark: isDark,
                    context: context,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      color: isDark ? const Color(0xFF263348) : const Color(0xFFF1F5F9),
                      height: 1,
                    ),
                  ),
                  _buildSummaryRow(
                    icon: Icons.payments_outlined,
                    label: 'Total Paid',
                    value: '\$${pkg.effectivePriceUsd.toStringAsFixed(2)}',
                    isDark: isDark,
                    context: context,
                    highlightColor: const Color(0xFF10B981),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Activation Instructions Card
          if (pkg != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.25) : const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.touch_app_rounded, color: Color(0xFF0284C7), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Touchdown Instructions',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    pkg.activationInstructions ??
                        (pkg.isEsim
                            ? 'Turn on Data Roaming on your eSIM profile once you reach Egypt.'
                            : 'Dial the recharge USSD code on your phone when landing.'),
                    style: TextStyle(
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  if (pkg.ussdRechargeCode != null) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        HapticHelper.lightTick();
                        Clipboard.setData(ClipboardData(text: pkg.ussdRechargeCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('USSD code copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0284C7)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              pkg.ussdRechargeCode!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            const Row(
                              children: [
                                Icon(Icons.copy_rounded, size: 16, color: Color(0xFF0284C7)),
                                SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: TextStyle(
                                    color: Color(0xFF0284C7),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Finish Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Back to SIM Protection Console',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required BuildContext context,
    Color? highlightColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: highlightColor ?? context.onSurfaceColor,
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }
}
