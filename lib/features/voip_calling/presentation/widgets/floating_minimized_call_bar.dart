/// KeepSIMs — Floating Minimized Call Bar Widget
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/voip_calling_controller.dart';

class FloatingMinimizedCallBar extends ConsumerWidget {
  const FloatingMinimizedCallBar({super.key});

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voipCallingControllerProvider);

    // Only display when a call is active AND minimized by the user
    if (!state.isActive || !state.isMinimized) return const SizedBox.shrink();

    final statusText = state.status == 'connected'
        ? _formatDuration(state.durationSeconds)
        : (state.status == 'ringing' ? 'Ringing...' : 'Calling...');

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF102820),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Pulsing Call Indicator
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),

              // Peer Name & Timer
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    ref
                        .read(voipCallingControllerProvider.notifier)
                        .setMinimized(false);
                    context.push(AppRoutes.voipCall);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.peerName.isNotEmpty
                            ? state.peerName
                            : 'KeepSIMs Voice Call',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Tap to return • $statusText',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Quick End Call Button (No tooltip to prevent requiring an Overlay)
              IconButton(
                icon: const Icon(
                  Icons.call_end_rounded,
                  color: Colors.redAccent,
                  size: 22,
                ),
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  ref.read(voipCallingControllerProvider.notifier).endCall();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
