import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_liveness_result.dart';
import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';

/// Modal bottom sheet allowing users to verify inconclusive / unmapped SIM lines
/// (e.g. FRiENDi Mobile Oman or GCC carriers) via Voice Call or SMS OTP.
class SimOtpVerificationSheet extends ConsumerStatefulWidget {
  final String fullPhoneNumber;
  final String? carrierName;
  final String? countryCode;

  const SimOtpVerificationSheet({
    super.key,
    required this.fullPhoneNumber,
    this.carrierName,
    this.countryCode,
  });

  static Future<SimLivenessResult?> show(
    BuildContext context, {
    required String fullPhoneNumber,
    String? carrierName,
    String? countryCode,
  }) {
    return showModalBottomSheet<SimLivenessResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.isDarkMode
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SimOtpVerificationSheet(
        fullPhoneNumber: fullPhoneNumber,
        carrierName: carrierName,
        countryCode: countryCode,
      ),
    );
  }

  @override
  ConsumerState<SimOtpVerificationSheet> createState() =>
      _SimOtpVerificationSheetState();
}

class _SimOtpVerificationSheetState
    extends ConsumerState<SimOtpVerificationSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSending = false;
  bool _isVerifying = false;
  String? _activeChannel; // 'call' | 'sms'
  String? _statusMessage;
  String? _errorMessage;

  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _codeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown([int seconds = 60]) {
    _countdownTimer?.cancel();
    setState(() {
      _resendCountdown = seconds;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 1) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        setState(() {
          _resendCountdown = 0;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _sendOtp(String channel) async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
      _activeChannel = channel;
    });

    try {
      final repo = ref.read(simLinesRepositoryProvider);
      final res = await repo.sendSimOtp(
        phoneNumber: widget.fullPhoneNumber,
        channel: channel,
        countryCode: widget.countryCode,
      );

      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _isSending = false;
            _statusMessage = channel == 'call'
                ? 'Calling your SIM now with a spoken 4-digit code...'
                : 'SMS verification code sent to your SIM.';
          });
          _startCountdown(60);
        } else {
          setState(() {
            _isSending = false;
            _errorMessage = res['message'] ?? 'Failed to send OTP.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || code.length < 4) {
      setState(() {
        _errorMessage = 'Please enter the 4-digit verification code.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(simLinesRepositoryProvider);
      final result = await repo.verifySimOtp(
        phoneNumber: widget.fullPhoneNumber,
        code: code,
        operatorName: widget.carrierName,
        countryCode: widget.countryCode,
      );

      if (mounted) {
        setState(() {
          _isVerifying = false;
        });

        if (result.isActive) {
          Navigator.pop(context, result);
        } else {
          setState(() {
            _errorMessage = result.message.isNotEmpty
                ? result.message
                : 'Incorrect code. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify SIM Line Liveness',
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.fullPhoneNumber} ${widget.carrierName != null ? '• ${widget.carrierName}' : ''}',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'To ensure your line is active before enabling auto-refill, choose how you would like to receive a quick 4-digit verification code:',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Method 1: Voice Call (Recommended)
            _buildOptionCard(
              isDark: isDark,
              channel: 'call',
              icon: Icons.phone_in_talk_rounded,
              title: 'Voice Call (Recommended)',
              subtitle: 'Telnyx calls your SIM and speaks a 4-digit code. Bypasses carrier SMS spam filters.',
              badge: 'Fast & Reliable',
              badgeColor: const Color(0xFF10B981),
            ),
            const SizedBox(height: 12),

            // Method 2: SMS Text Message
            _buildOptionCard(
              isDark: isDark,
              channel: 'sms',
              icon: Icons.sms_rounded,
              title: 'SMS Message',
              subtitle: 'Receive a 4-digit verification code via SMS text message.',
              badge: 'Standard SMS',
              badgeColor: const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 24),

            // OTP Input Form (Shown when an OTP dispatch was initiated)
            if (_activeChannel != null) ...[
              Divider(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                height: 1,
              ),
              const SizedBox(height: 20),

              if (_statusMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Text(
                'Enter 4-Digit Code',
                style: AppTextStyles.labelMedium.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.onSurfaceColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white24 : Colors.black26,
                          letterSpacing: 8,
                        ),
                        filled: true,
                        fillColor: isDark ? AppColors.darkCard : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verify Code',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Resend & Switch options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_resendCountdown > 0)
                    Text(
                      'Resend in ${_resendCountdown}s',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 11.5,
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: _isSending
                          ? null
                          : () => _sendOtp(_activeChannel ?? 'call'),
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text('Resend Code'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  TextButton(
                    onPressed: _isSending
                        ? null
                        : () => _sendOtp(_activeChannel == 'call' ? 'sms' : 'call'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      _activeChannel == 'call'
                          ? 'Try SMS instead'
                          : 'Try Voice Call instead',
                      style: TextStyle(
                        color: context.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required bool isDark,
    required String channel,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
  }) {
    final isSelected = _activeChannel == channel;

    return InkWell(
      onTap: _isSending ? null : () => _sendOtp(channel),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
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
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
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
}
