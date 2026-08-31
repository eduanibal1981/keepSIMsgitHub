import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_liveness_result.dart';

/// An interactive Carrier BSS Liveness & Activity Verification Badge.
/// Displays live verification status directly from wholesale B2B gateways (DTOne & Zendit).
/// Provides an explicit "Check Line" button and a "Verify via Call or SMS" fallback for unmapped MVNOs.
class CarrierLivenessBadge extends StatelessWidget {
  final SimLivenessResult? result;
  final bool isLoading;
  final VoidCallback? onCheck;
  final VoidCallback? onRetry;
  final VoidCallback? onOtpVerify;

  const CarrierLivenessBadge({
    super.key,
    this.result,
    this.isLoading = false,
    this.onCheck,
    this.onRetry,
    this.onOtpVerify,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    // 1. Loading State
    if (isLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.darkCard : Colors.white).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isDark ? AppColors.primaryLight : AppColors.lightPrimary).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Verifying line with carrier...',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Connecting to carrier BSS registry',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 2. Unchecked State: Show prompt & "Check Line" Action Button
    if (result == null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkCard.withValues(alpha: 0.7)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1)).withValues(alpha: 0.8),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 20,
              color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Carrier Liveness Check',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Tap "Check Line" to verify carrier status',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (onCheck != null)
              ElevatedButton.icon(
                onPressed: onCheck,
                icon: const Icon(Icons.bolt_rounded, size: 14),
                label: const Text('Check Line'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
          ],
        ),
      );
    }

    // 3. Checked State: Result Badges (Active, Inactive, Unsupported)
    final status = result!.carrierStatus.toLowerCase();
    final isActive = status == 'active' && result!.isActive;
    final isInactive = status == 'inactive';
    final isUnsupported = !isActive && !isInactive;

    Color cardBg;
    Color borderColor;
    Color iconColor;
    IconData iconData;
    String titleText;
    String subtitleText;

    if (isActive) {
      cardBg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08);
      borderColor = const Color(0xFF10B981).withValues(alpha: isDark ? 0.4 : 0.3);
      iconColor = const Color(0xFF10B981);
      iconData = Icons.check_circle_rounded;
      final op = result!.detectedOperatorName;
      titleText = op != null && op.isNotEmpty
          ? 'Active on $op (Prepaid)'
          : 'Carrier Line Active (Prepaid)';
      subtitleText = 'Carrier BSS confirmed • Ready for auto-refill protection';
    } else if (isInactive) {
      cardBg = AppColors.error.withValues(alpha: isDark ? 0.15 : 0.08);
      borderColor = AppColors.error.withValues(alpha: isDark ? 0.5 : 0.35);
      iconColor = AppColors.error;
      iconData = Icons.cancel_rounded;
      titleText = 'Number inactive or expired at carrier';
      subtitleText = 'Cannot register for auto-refill. Carrier indicates line is deactivated or recycled.';
    } else if (isUnsupported) {
      cardBg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08);
      borderColor = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.4 : 0.3);
      iconColor = const Color(0xFFF59E0B);
      iconData = Icons.info_outline_rounded;
      titleText = result!.message.isNotEmpty
          ? result!.message
          : 'Carrier verification unavailable for this corridor';
      subtitleText = 'Could not verify active status with carrier BSS. You can verify this line with a quick Voice Call or SMS code.';
    } else {
      return const SizedBox.shrink();
    }

    final effectiveRetry = onRetry ?? onCheck;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(iconData, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titleText,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (subtitleText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (effectiveRetry != null)
                IconButton(
                  icon: Icon(Icons.refresh_rounded, size: 18, color: iconColor),
                  onPressed: effectiveRetry,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Re-verify carrier status',
                ),
            ],
          ),

          // Fallback OTP Action Button for Inconclusive / Unsupported Corridors (e.g. FRiENDi Oman)
          if (isUnsupported && onOtpVerify != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onOtpVerify,
                icon: const Icon(Icons.phone_in_talk_rounded, size: 15),
                label: const Text('Verify via Voice Call or SMS Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 36),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
