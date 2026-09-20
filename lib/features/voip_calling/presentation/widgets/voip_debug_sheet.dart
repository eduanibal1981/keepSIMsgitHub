/// KeepSIMs — VoIP Testing & Debug Simulator Sheet
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/voip_calling/data/services/voip_callkit_service.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/voip_calling_controller.dart';

class VoipDebugSheet extends ConsumerStatefulWidget {
  const VoipDebugSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const VoipDebugSheet(),
    );
  }

  @override
  ConsumerState<VoipDebugSheet> createState() => _VoipDebugSheetState();
}

class _VoipDebugSheetState extends ConsumerState<VoipDebugSheet> {
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _triggerIncomingCallWithDelay() {
    setState(() => _countdown = 3);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() => _countdown = 0);
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        final callkit = VoipCallkitService();
        await callkit.showIncomingCall(
          callId: 'mock-call-${DateTime.now().millisecondsSinceEpoch}',
          callerName: 'Sarah Connor (KeepSIMs)',
          callerPhone: '+1 555-0199',
        );
      }
    });
  }

  void _openActiveCallPreview() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    ref
        .read(voipCallingControllerProvider.notifier)
        .startDebugCall(peerName: 'Sarah Connor', peerPhone: '+1 555-0199');
    context.push(AppRoutes.voipCall);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF131D26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.science_rounded,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VoIP Testing & Debug Suite',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Test WhatsApp calling without external requirements',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Option 1: Simulate Incoming Call (CallKit / Android Telecom)
            _DebugTile(
              icon: Icons.phone_callback_rounded,
              title: _countdown > 0
                  ? 'Lock screen now! Ringing in $_countdown...'
                  : 'Simulate Incoming Call (3s Delay)',
              subtitle:
                  'Tests lockscreen wake-up, ringtone, and Accept/Decline actions',
              badge: _countdown > 0
                  ? 'RINGING IN $_countdown'
                  : 'NATIVE CALLKIT',
              badgeColor: _countdown > 0
                  ? Colors.amberAccent
                  : AppColors.secondary,
              onTap: _countdown > 0 ? null : _triggerIncomingCallWithDelay,
            ),

            const SizedBox(height: 12),

            // Option 2: Direct Active Call Preview
            _DebugTile(
              icon: Icons.phone_in_talk_rounded,
              title: 'Launch WhatsApp Call Screen',
              subtitle:
                  'Preview active call UI, timer, mute, speaker, and proximity blackout',
              badge: 'UI & SENSORS',
              badgeColor: AppColors.primary,
              onTap: _openActiveCallPreview,
            ),

            const SizedBox(height: 12),

            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white60,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Live calling also works directly between any two logged-in devices over local Wi-Fi via Google STUN.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
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

class _DebugTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback? onTap;

  const _DebugTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2732),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badgeColor.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: badgeColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
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
