/// KeepSIMs — Active Call Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';

class ActiveCallScreen extends ConsumerWidget {
  const ActiveCallScreen({super.key});

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callingControllerProvider);
    final rate = callState.rate;

    final isConnecting = callState.status == 'initiating';
    final isRinging = callState.status == 'ringing';
    final isConnected = callState.status == 'in_progress';
    final isEnded = callState.status == 'ended' ||
        callState.status == 'busy' ||
        callState.status == 'no_answer' ||
        callState.status == 'cancelled' ||
        callState.status == 'declined' ||
        callState.status == 'failed';

    final String statusBadgeText;
    if (isConnected) {
      statusBadgeText = 'CALL CONNECTED';
    } else if (isRinging) {
      statusBadgeText = 'RINGING...';
    } else if (isConnecting) {
      statusBadgeText = 'CALLING...';
    } else if (callState.status == 'busy') {
      statusBadgeText = 'LINE BUSY';
    } else if (callState.status == 'no_answer') {
      statusBadgeText = 'NO ANSWER';
    } else if (callState.status == 'declined') {
      statusBadgeText = 'CALL DECLINED';
    } else if (callState.status == 'cancelled') {
      statusBadgeText = 'CALL CANCELLED';
    } else if (callState.status == 'failed') {
      statusBadgeText = 'CALL FAILED';
    } else {
      statusBadgeText = 'CALL ENDED';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D141C),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ── Top Connection Status Badge ──
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? AppColors.secondary.withValues(alpha: 0.15)
                                    : isRinging
                                        ? AppColors.primary.withValues(alpha: 0.15)
                                        : isEnded
                                            ? AppColors.error.withValues(alpha: 0.15)
                                            : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isConnected
                                      ? AppColors.secondary
                                      : isRinging
                                          ? AppColors.primary
                                          : isEnded
                                              ? AppColors.error
                                              : Colors.white24,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isConnected
                                          ? AppColors.secondary
                                          : isRinging
                                              ? AppColors.primary
                                              : isEnded
                                                  ? AppColors.error
                                                  : Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    statusBadgeText,
                                    style: TextStyle(
                                      color: isConnected
                                          ? AppColors.secondary
                                          : isRinging
                                              ? AppColors.primary
                                              : isEnded
                                                  ? AppColors.error
                                                  : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (callState.errorMessage != null &&
                                callState.errorMessage!.isNotEmpty &&
                                isEnded) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  callState.errorMessage!,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Caller & Destination Info ──
                        Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isConnected
                                    ? AppColors.secondary.withValues(alpha: 0.2)
                                    : AppColors.primary.withValues(alpha: 0.2),
                                border: Border.all(
                                  color: isConnected ? AppColors.secondary : AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  rate?.flagEmoji ?? '🌐',
                                  style: const TextStyle(fontSize: 44),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              rate?.countryName ?? 'International Destination',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              callState.destinationNumber,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Timer Display (Only runs when connected!)
                            Text(
                              _formatDuration(callState.durationSeconds),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Real-time Billing Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                isConnected
                                    ? 'Live Cost: \$${callState.estimatedCost.toStringAsFixed(3)} (@ \$${(rate?.ratePerMinute ?? 0.08).toStringAsFixed(2)}/min)'
                                    : 'Rate: \$${(rate?.ratePerMinute ?? 0.08).toStringAsFixed(2)}/min (Free while ringing)',
                                style: TextStyle(
                                  color: isConnected ? AppColors.secondary : Colors.white60,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // ── In-Call Action Controls ──
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _ActionButton(
                                  icon: callState.isMuted ? Icons.mic_off : Icons.mic,
                                  label: 'Mute',
                                  isActive: callState.isMuted,
                                  onTap: () => ref.read(callingControllerProvider.notifier).toggleMute(),
                                ),
                                _ActionButton(
                                  icon: callState.isSpeaker ? Icons.volume_up : Icons.volume_down,
                                  label: 'Speaker',
                                  isActive: callState.isSpeaker,
                                  onTap: () => ref.read(callingControllerProvider.notifier).toggleSpeaker(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),

                            // End Call / Dismiss Button
                            GestureDetector(
                              onTap: () {
                                ref.read(callingControllerProvider.notifier).endCall();
                                if (context.canPop()) {
                                  context.pop();
                                }
                              },
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.error,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.error.withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isEnded ? Icons.close : Icons.call_end,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.1),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}
