/// KeepSIMs — WhatsApp-Style Internet Voice Calling Screen
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/voip_calling_controller.dart';

class WhatsAppCallScreen extends ConsumerStatefulWidget {
  const WhatsAppCallScreen({super.key});

  @override
  ConsumerState<WhatsAppCallScreen> createState() => _WhatsAppCallScreenState();
}

class _WhatsAppCallScreenState extends ConsumerState<WhatsAppCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voipCallingControllerProvider);

    // Auto-pop on terminal state after brief display
    ref.listen<VoipActiveCallState>(voipCallingControllerProvider, (
      prev,
      next,
    ) {
      if (next.isTerminal && (prev == null || !prev.isTerminal)) {
        HapticFeedback.mediumImpact();
        final router = GoRouter.of(context);
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) {
            if (router.canPop()) {
              router.pop();
            } else {
              router.go(AppRoutes.home);
            }
          }
        });
      }
    });

    // Proximity Sensor Blackout: Blank screen completely when phone is pressed against ear
    if (state.isNearEar && state.isActive) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(),
      );
    }

    String statusText;
    Color statusColor = Colors.white70;

    switch (state.status) {
      case 'calling':
        statusText = 'Calling...';
        break;
      case 'ringing':
        statusText = 'Ringing...';
        statusColor = AppColors.secondary;
        break;
      case 'connected':
        statusText = _formatDuration(state.durationSeconds);
        statusColor = Colors.white;
        break;
      case 'reconnecting':
        statusText = 'Reconnecting...';
        statusColor = AppColors.warning;
        break;
      case 'declined':
        statusText = 'Call Declined';
        statusColor = Colors.redAccent;
        break;
      case 'busy':
        statusText = 'User Busy';
        statusColor = Colors.redAccent;
        break;
      case 'timeout':
        statusText = 'No Answer';
        statusColor = Colors.orangeAccent;
        break;
      case 'ended':
      case 'completed':
        statusText = 'Call Ended';
        statusColor = Colors.white70;
        break;
      case 'failed':
        statusText = state.errorMessage ?? 'Call Failed';
        statusColor = Colors.redAccent;
        break;
      default:
        statusText = 'Connecting...';
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && ref.read(voipCallingControllerProvider).isActive) {
          ref.read(voipCallingControllerProvider.notifier).setMinimized(true);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(
          0xFF0B141B,
        ), // WhatsApp dark navy-green background
        body: SafeArea(
          child: Stack(
            children: [
              // Ambient Gradient Background
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 1.2,
                      colors: [
                        const Color(0xFF102820).withValues(alpha: 0.6),
                        const Color(0xFF0B141B),
                      ],
                    ),
                  ),
                ),
              ),

              // Main Content
              Column(
                children: [
                  // Top Action Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          tooltip: 'Minimize call',
                          onPressed: () {
                            ref
                                .read(voipCallingControllerProvider.notifier)
                                .setMinimized(true);
                            if (context.canPop()) {
                              context.pop();
                            }
                          },
                        ),
                      Row(
                        children: [
                          const Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'End-to-end encrypted',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 48), // Balancing spacer
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // Peer Avatar with Animated Glow
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final scale =
                        state.status == 'calling' || state.status == 'ringing'
                        ? _pulseAnimation.value
                        : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: state.status == 'ringing'
                                  ? AppColors.secondary.withValues(alpha: 0.3)
                                  : Colors.cyan.withValues(alpha: 0.2),
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 70,
                          backgroundColor: const Color(0xFF1E2C33),
                          backgroundImage:
                              (state.peerAvatarUrl != null &&
                                  state.peerAvatarUrl!.isNotEmpty)
                              ? NetworkImage(state.peerAvatarUrl!)
                              : null,
                          child:
                              (state.peerAvatarUrl == null ||
                                  state.peerAvatarUrl!.isEmpty)
                              ? Text(
                                  state.peerName.isNotEmpty
                                      ? state.peerName[0].toUpperCase()
                                      : 'K',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Peer Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    state.peerName.isNotEmpty
                        ? state.peerName
                        : 'KeepSIMs User',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 8),

                // Call Subtitle & State
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                    letterSpacing: 0.4,
                  ),
                ),

                if (state.isPeerMuted && state.status == 'connected') ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.mic_off_rounded,
                        size: 14,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Peer is muted',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],

                const Spacer(flex: 2),

                // WhatsApp-style In-Call Bottom Controls Glass Panel
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1E293B,
                          ).withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Speaker Toggle
                            _ActionButton(
                              icon: state.isSpeaker
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_down_rounded,
                              label: 'Speaker',
                              isActive: state.isSpeaker,
                              activeColor: AppColors.secondary,
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(
                                      voipCallingControllerProvider.notifier,
                                    )
                                    .toggleSpeaker();
                              },
                            ),

                            // Mute Mic Toggle
                            _ActionButton(
                              icon: state.isMuted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              label: state.isMuted ? 'Unmute' : 'Mute',
                              isActive: state.isMuted,
                              activeColor: Colors.amberAccent,
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(
                                      voipCallingControllerProvider.notifier,
                                    )
                                    .toggleMute();
                              },
                            ),

                            // End Call Button (Prominent Red)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.heavyImpact();
                                ref
                                    .read(
                                      voipCallingControllerProvider.notifier,
                                    )
                                    .endCall();
                              },
                              child: Container(
                                width: 62,
                                height: 62,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFEF4444),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x66EF4444),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.call_end_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? activeColor
                    : Colors.white.withValues(alpha: 0.12),
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.black87 : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? activeColor : Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
