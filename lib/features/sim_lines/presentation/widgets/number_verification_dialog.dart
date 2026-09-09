import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_verification_quote_model.dart';
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
  String _selectedMethod = 'sms'; // 'sms' or 'voice'

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Automatically reset when opened if the controller was in a finished/error state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final status = ref.read(
        lineVerificationControllerProvider(widget.simLineId),
      ).status;
      if (status == LineVerificationStatus.failure ||
          status == LineVerificationStatus.success) {
        ref
            .read(
              lineVerificationControllerProvider(widget.simLineId).notifier,
            )
            .reset();
      }
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  void _triggerRadar(LineVerificationStatus status) {
    if (status == LineVerificationStatus.ringing ||
        status == LineVerificationStatus.awaitingDlr) {
      if (!_radarController.isAnimating) {
        _radarController.repeat();
      }
    } else {
      if (_radarController.isAnimating) {
        _radarController.stop();
      }
    }
  }

  void _dismissWithBackgroundNotice(BuildContext context) {
    HapticHelper.lightTick();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Live verification is checking in background. The line status will update automatically.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      lineVerificationControllerProvider(widget.simLineId),
    );
    _triggerRadar(state.status);

    ref.listen(lineVerificationControllerProvider(widget.simLineId), (
      prev,
      next,
    ) {
      if (next.status == LineVerificationStatus.ringing ||
          next.status == LineVerificationStatus.awaitingDlr) {
        HapticHelper.mediumImpact();
      } else if (next.status == LineVerificationStatus.success) {
        HapticHelper.successFeedback();
      } else if (next.status == LineVerificationStatus.failure) {
        HapticHelper.errorFeedback();
      }
    });

    final isCheckingInBackground =
        state.status == LineVerificationStatus.ringing ||
        state.status == LineVerificationStatus.awaitingDlr;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: AppColors.darkSurface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          size: 20,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Real Live Verify',
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () {
                      if (isCheckingInBackground) {
                        _dismissWithBackgroundNotice(context);
                      } else {
                        HapticHelper.lightTick();
                        if (state.status == LineVerificationStatus.failure ||
                            state.status == LineVerificationStatus.success) {
                          ref
                              .read(
                                lineVerificationControllerProvider(
                                  widget.simLineId,
                                ).notifier,
                              )
                              .reset();
                        }
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Dynamic Body
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
      case LineVerificationStatus.loadingQuote:
        return _buildLoadingQuoteUI();
      case LineVerificationStatus.quoteReady:
        return _buildQuoteReadyUI(state.quote!);
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

  Widget _buildLoadingQuoteUI() {
    return Column(
      children: [
        const SizedBox(height: 16),
        const SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Retrieving verification rates...',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildQuoteReadyUI(LineVerificationQuote quote) {
    final hasAllowance = quote.hasAnnualAllowance;
    final isPaidPlan = quote.isPaidPlan;

    final smsCatalogCost = quote.smsVerifyCostUsd;
    final callCatalogCost = quote.callVerifyCostUsd;

    final selectedCatalogCost =
        _selectedMethod == 'sms' ? smsCatalogCost : callCatalogCost;
    final selectedCost = hasAllowance ? 0.0 : selectedCatalogCost;
    final hasSufficientWallet =
        selectedCost <= 0.0 || quote.walletAvailableUsd >= selectedCost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Target number & country tag
        Center(
          child: Column(
            children: [
              Text(
                widget.phoneNumber,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (quote.countryName != null && quote.countryName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  quote.countryName!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Annual Allowance Banner if available
        if (hasAllowance)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.purple.shade300.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.stars_rounded,
                  color: Colors.purple.shade300,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1 Free Check Included This Year',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.purple.shade100,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        'Your paid subscription plan covers 1 live test per year.',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.purple.shade200,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (isPaidPlan)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Annual free check already redeemed for this subscription period.',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Method 1: Silent SMS
        _buildMethodCard(
          methodKey: 'sms',
          title: 'Verify via SMS',
          subtitle:
              'Carrier signaling test packet. Reaches SIM silently without notification sounds.',
          icon: Icons.sms_rounded,
          cost: smsCatalogCost,
          isAllowance: hasAllowance,
          isSelected: _selectedMethod == 'sms',
          onTap: () {
            setState(() {
              _selectedMethod = 'sms';
            });
            HapticHelper.lightTick();
          },
        ),
        const SizedBox(height: 10),

        // Method 2: Missed Call
        _buildMethodCard(
          methodKey: 'voice',
          title: 'Verify via Missed Call',
          subtitle:
              'Telecom signaling test. Rings once and disconnects immediately upon tower handshake.',
          icon: Icons.phone_callback_rounded,
          cost: callCatalogCost,
          isAllowance: hasAllowance,
          isSelected: _selectedMethod == 'voice',
          onTap: () {
            setState(() {
              _selectedMethod = 'voice';
            });
            HapticHelper.lightTick();
          },
        ),
        const SizedBox(height: 16),

        // Wallet info & policy notice
        if (selectedCost > 0.0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available Wallet:',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white70,
                  ),
                ),
                Text(
                  '\$${quote.walletAvailableUsd.toStringAsFixed(2)}',
                  style: AppTextStyles.caption.copyWith(
                    color: hasSufficientWallet ? Colors.white : AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '• Funds are temporarily reserved and captured ONLY if carrier confirms delivery.\n• If SIM is unreachable or disconnected, the hold is released immediately.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondaryDark,
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (!hasSufficientWallet)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Insufficient wallet balance (\$${quote.walletAvailableUsd.toStringAsFixed(2)}). Please add funds in the Wallet tab to perform live verification.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        // Action Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: hasSufficientWallet
                ? () {
                    HapticHelper.mediumImpact();
                    ref
                        .read(
                          lineVerificationControllerProvider(
                            widget.simLineId,
                          ).notifier,
                        )
                        .startVerification(_selectedMethod);
                  }
                : null,
            child: Text(
              selectedCost > 0.0
                  ? 'Verify · \$${selectedCost.toStringAsFixed(2)}'
                  : (hasAllowance ? 'Start Free Verification' : 'Start Verification'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodCard({
    required String methodKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required double cost,
    required bool isAllowance,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final borderColor = isSelected
        ? AppColors.primaryLight
        : Colors.white.withValues(alpha: 0.12);

    final costLabel = cost > 0.0 ? '\$${cost.toStringAsFixed(2)}' : 'FREE';

    final costColor = cost <= 0.0
        ? AppColors.success
        : AppColors.primaryLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primaryLight : Colors.white70,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: costColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          costLabel,
                          style: TextStyle(
                            color: costColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondaryDark,
                      fontSize: 11,
                      height: 1.3,
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
          'Connecting Secure Gateway...',
          style: AppTextStyles.titleLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Contacting global telecom gateway and initializing carrier verification session.',
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
                              color: AppColors.secondary.withValues(alpha: 0.8),
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
                'Waiting for network signaling ring...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Keep your phone powered on. Do not answer. The call is dropped immediately once the cellular tower acknowledges ringing.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondaryDark,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () => _dismissWithBackgroundNotice(context),
          child: const Text('Check in Background'),
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
          'Connecting to telecom gateway to transmit silent cellular packet to ${widget.phoneNumber}.',
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
                              color: AppColors.primaryLight.withValues(
                                alpha: 0.8,
                              ),
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
        const SizedBox(height: 16),
        Text(
          'Monitoring carrier delivery acknowledgment. When the SIM card acknowledges packet receipt on the cell tower, the status will verify.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondaryDark,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () => _dismissWithBackgroundNotice(context),
          child: const Text('Check in Background'),
        ),
      ],
    );
  }

  Widget _buildSuccessUI(LineVerificationState state) {
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
          'SIM line confirmed active on carrier network$carrierText. Health score is restored and cellular connectivity is validated.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 26),
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
              'No response received from the SIM card. Please check if the card is properly inserted and has cellular reception.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'No charges were captured. Any wallet hold has been released.',
          style: AppTextStyles.caption.copyWith(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 24),
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
                  ref
                      .read(
                        lineVerificationControllerProvider(
                          widget.simLineId,
                        ).notifier,
                      )
                      .reset();
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
