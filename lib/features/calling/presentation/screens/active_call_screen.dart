/// KeepSIMs — Active Call In-Progress Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';

class ActiveCallScreen extends ConsumerWidget {
  const ActiveCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callingControllerProvider);
    final controller = ref.read(callingControllerProvider.notifier);

    final m = callState.durationSeconds ~/ 60;
    final s = callState.durationSeconds % 60;
    final durationStr =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Top Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
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
                                color: callState.status == 'in_progress'
                                    ? AppColors.secondary
                                    : AppColors.warning,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              callState.status == 'in_progress'
                                  ? 'CALL CONNECTED'
                                  : callState.status == 'ringing'
                                  ? 'RINGING DESTINATION...'
                                  : 'CONNECTING...',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Flag Avatar
                      Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          callState.rate?.flagEmoji ?? '🌐',
                          style: const TextStyle(fontSize: 44),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        callState.rate?.countryName ?? 'International Call',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        callState.destinationNumber,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        durationStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: Text(
                          'Live Cost: \$${callState.estimatedCost.toStringAsFixed(3)} (@ \$${(callState.rate?.ratePerMinute ?? 0.08).toStringAsFixed(2)}/min)',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Error message if any
                      if (callState.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error),
                          ),
                          child: Text(
                            callState.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],

                      // In-call action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildControlBtn(
                            icon: callState.isMuted ? Icons.mic_off : Icons.mic,
                            label: callState.isMuted ? 'Muted' : 'Mute',
                            isActive: callState.isMuted,
                            onTap: controller.toggleMute,
                          ),
                          _buildControlBtn(
                            icon: callState.isSpeaker
                                ? Icons.volume_up
                                : Icons.volume_down,
                            label: 'Speaker',
                            isActive: callState.isSpeaker,
                            onTap: controller.toggleSpeaker,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Hangup Button
                      GestureDetector(
                        onTap: () {
                          controller.endCall();
                          context.pop();
                        },
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF4D4D),
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.white : AppColors.darkCard,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
