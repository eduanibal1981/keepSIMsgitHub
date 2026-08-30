import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/line_verification_state.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/line_verification_controller.dart';

class NumberVerificationDialog extends ConsumerStatefulWidget {
  final String simLineId;
  final String phoneNumber;

  const NumberVerificationDialog({
    super.key,
    required this.simLineId,
    required this.phoneNumber,
  });

  @override
  ConsumerState<NumberVerificationDialog> createState() =>
      _NumberVerificationDialogState();
}

class _NumberVerificationDialogState
    extends ConsumerState<NumberVerificationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  void _triggerRadar(LineVerificationStatus status) {
    if (status == LineVerificationStatus.ringing) {
      if (!_radarController.isAnimating) {
        _radarController.repeat();
      }
    } else {
      if (_radarController.isAnimating) {
        _radarController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      lineVerificationControllerProvider(widget.simLineId),
    );
    _triggerRadar(state.status);

    // Watch status changes to fire haptics
    ref.listen(lineVerificationControllerProvider(widget.simLineId), (
      prev,
      next,
    ) {
      if (next.status == LineVerificationStatus.ringing) {
        HapticHelper.mediumImpact();
      } else if (next.status == LineVerificationStatus.success) {
        HapticHelper.successFeedback();
      } else if (next.status == LineVerificationStatus.failure) {
        HapticHelper.errorFeedback();
      }
    });

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.darkSurface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: -5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Line Verification',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (state.status == LineVerificationStatus.idle ||
                      state.status == LineVerificationStatus.failure ||
                      state.status == LineVerificationStatus.success)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () {
                        HapticHelper.lightTick();
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Animated Stage Indicator
              _buildStageUI(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageUI(LineVerificationState state) {
    switch (state.status) {
      case LineVerificationStatus.idle:
        return _buildIdleUI();
      case LineVerificationStatus.triggering:
        return _buildTriggeringUI();
      case LineVerificationStatus.ringing:
        return _buildRingingUI();
      case LineVerificationStatus.sendingSms:
        return _buildSendingSmsUI();
      case LineVerificationStatus.awaitingDlr:
        return _buildAwaitingDlrUI(state);
      case LineVerificationStatus.success:
        return _buildSuccessUI(state);
      case LineVerificationStatus.failure:
        return _buildFailureUI(state);
    }
  }

  Widget _buildIdleUI() {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.phone_iphone,
            size: 40,
            color: AppColors.primaryLight,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          widget.phoneNumber,
          style: AppTextStyles.headlineMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Choose a verification method to test if your SIM line is actively attached to a cellular network.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),

        // 1. Silent SMS Verification Button (verifySMS0)
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: AppColors.primary.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () {
            HapticHelper.mediumImpact();
            ref
                .read(
                  lineVerificationControllerProvider(widget.simLineId).notifier,
                )
                .startSmsVerification(widget.phoneNumber);
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sms_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                'Verify via Silent SMS (verifySMS0)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Missed Call Verification Button
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () {
            HapticHelper.mediumImpact();
            ref
                .read(
                  lineVerificationControllerProvider(widget.simLineId).notifier,
                )
                .startVerification(widget.phoneNumber);
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_callback_rounded, size: 18, color: Colors.white70),
              SizedBox(width: 8),
              Text(
                'Verify via Missed Call',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTriggeringUI() {
    return Column(
      children: [
        const SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Connecting Secure Node...',
          style: AppTextStyles.titleLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Contacting global telecom gateway and initializing Twilio authentication tunnel.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }

  Widget _buildRingingUI() {
    return Column(
      children: [
        // Pulsating radar animation
        SizedBox(
          width: 140,
          height: 140,
          child: AnimatedBuilder(
            animation: _radarController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Overlapping outer ripple rings
                  for (int i = 0; i < 3; i++)
                    Opacity(
                      opacity:
                          (1.0 - ((_radarController.value + i / 3.0) % 1.0)) *
                          0.4,
                      child: Transform.scale(
                        scale:
                            1.0 +
                            (((_radarController.value + i / 3.0) % 1.0) * 1.5),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.secondary.withValues(alpha: 0.8),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Core center pulsating button
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.secondary,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.signal_cellular_alt_rounded,
                      size: 32,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Ringing Target Line...',
          style: AppTextStyles.titleLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.phoneNumber,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.secondaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.secondary,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Waiting for network handshake...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Ensure your SIM is in an active phone. Do not answer. The system rejects the call immediately to create a missed call.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondaryDark,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSendingSmsUI() {
    return Column(
      children: [
        const SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Dispatching Silent Ping...',
          style: AppTextStyles.titleLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Connecting to global telecom gateway to transmit silent cellular packet to ${widget.phoneNumber}.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }

  Widget _buildAwaitingDlrUI(LineVerificationState state) {
    return Column(
      children: [
        // Pulsating radar animation for SMS
        SizedBox(
          width: 140,
          height: 140,
          child: AnimatedBuilder(
            animation: _radarController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (int i = 0; i < 3; i++)
                    Opacity(
                      opacity:
                          (1.0 - ((_radarController.value + i / 3.0) % 1.0)) *
                          0.4,
                      child: Transform.scale(
                        scale:
                            1.0 +
                            (((_radarController.value + i / 3.0) % 1.0) * 1.5),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryLight.withValues(alpha: 0.8),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryLight,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      size: 32,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Awaiting Carrier Handshake...',
          style: AppTextStyles.titleLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.phoneNumber,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.primaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryLight,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Tracking Delivery Receipt (DLR)...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Monitoring real-time carrier signaling ACK. If the line is active, the tower will confirm packet receipt.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondaryDark,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessUI(LineVerificationState state) {
    final isSms = state.verificationChannel == 'telnyx_sms_dlr';
    final carrierText = state.carrierName != null
        ? ' via ${state.carrierName}'
        : '';

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.success, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.3),
                blurRadius: 15,
              ),
            ],
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 44,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Verification Successful!',
          style: AppTextStyles.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isSms
              ? 'SIM line confirmed active on carrier network$carrierText. Health status updated to 100% and Shield is optimized.'
              : 'Your SIM line is active on carrier networks. Health status updated to 100% and Shield is optimized.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () {
            HapticHelper.lightTick();
            Navigator.of(context).pop();
          },
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildFailureUI(LineVerificationState state) {
    final isSms = state.verificationChannel == 'telnyx_sms_dlr';

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.error, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withValues(alpha: 0.3),
                blurRadius: 15,
              ),
            ],
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            size: 44,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Verification Failed',
          style: AppTextStyles.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          state.errorMessage ??
              'No response received. Please check if the SIM card is properly inserted and has active coverage.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  HapticHelper.lightTick();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  HapticHelper.mediumImpact();
                  final notifier = ref.read(
                    lineVerificationControllerProvider(
                      widget.simLineId,
                    ).notifier,
                  );
                  notifier.reset();
                  if (isSms) {
                    notifier.startSmsVerification(widget.phoneNumber);
                  } else {
                    notifier.startVerification(widget.phoneNumber);
                  }
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
