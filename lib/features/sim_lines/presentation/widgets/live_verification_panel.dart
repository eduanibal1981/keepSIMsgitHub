import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';

class LiveVerificationPanel extends StatelessWidget {
  final SimLine simLine;
  final bool isViewer;
  final VoidCallback onVerifyTap;

  const LiveVerificationPanel({
    super.key,
    required this.simLine,
    required this.onVerifyTap,
    this.isViewer = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final isVerified = simLine.verificationStatus == 'verified';
    final Color panelColor = isVerified
        ? (isDark ? AppColors.primaryLight : AppColors.lightPrimary)
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    final String titleText = isVerified
        ? 'Cellular network attached'
        : 'Not checked yet';

    final String subtitleText = isVerified
        ? (simLine.carrierVerifiedAt != null
            ? 'Last check: ${DateFormat('MMM dd, yyyy, HH:mm').format(simLine.carrierVerifiedAt!.toLocal())}'
            : 'Carrier reachability confirmed')
        : 'Verify SIM physical network presence';

    final bool hasPaidPlan = simLine.isPaidPlan;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: panelColor.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: panelColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: panelColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVerified ? Icons.cell_tower_rounded : Icons.signal_cellular_alt_rounded,
                  size: 18,
                  color: panelColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: panelColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'LIVE VERIFICATION',
                            style: AppTextStyles.caption.copyWith(
                              color: panelColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        if (hasPaidPlan) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '1 FREE/YR',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.purple.shade300,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      titleText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: AppTextStyles.caption.copyWith(
                        color: context.onSurfaceColor.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!isViewer) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    HapticHelper.mediumImpact();
                    onVerifyTap();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Real live verify',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
