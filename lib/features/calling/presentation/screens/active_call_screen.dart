/// KeepSIMs — Active Call Screen
library;

import 'package:flutter/material.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
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
    final isEnded = callState.isTerminal;

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
    } else if (callState.status == 'completed') {
      statusBadgeText = 'CALL COMPLETED';
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ── Top Connection Status Badge ──
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? AppColors.secondary.withValues(
                                        alpha: 0.15,
                                      )
                                    : isRinging
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : isEnded
                                    ? (callState.status == 'completed'
                                          ? AppColors.secondary.withValues(
                                              alpha: 0.15,
                                            )
                                          : AppColors.error.withValues(
                                              alpha: 0.15,
                                            ))
                                    : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isConnected
                                      ? AppColors.secondary
                                      : isRinging
                                      ? AppColors.primary
                                      : isEnded
                                      ? (callState.status == 'completed'
                                            ? AppColors.secondary
                                            : AppColors.error)
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
                                          ? (callState.status == 'completed'
                                                ? AppColors.secondary
                                                : AppColors.error)
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
                                          ? (callState.status == 'completed'
                                                ? AppColors.secondary
                                                : AppColors.error)
                                          : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Effective Outbound Caller ID Chip
                            if (callState.effectiveCallerId != null &&
                                callState.effectiveCallerId!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Outbound Caller ID: ${callState.effectiveCallerId}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],

                            // Error / Explanation Banner
                            if (callState.errorMessage != null &&
                                callState.errorMessage!.isNotEmpty &&
                                isEnded &&
                                callState.status != 'completed') ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.error.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      callState.errorMessage!,
                                      textAlign: TextAlign.center,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (callState.errorMessage!
                                            .toLowerCase()
                                            .contains('microphone') ||
                                        callState.suggestedAction ==
                                            'open_settings') ...[
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () => openAppSettings(),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.settings,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Open App Settings',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (callState.sipHangupCause != null ||
                                        callState.callId != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Ref: ${callState.sipHangupCause != null ? 'SIP ${callState.sipHangupCause}' : ''}${callState.callId != null ? ' • Session: ${callState.callId!.substring(0, 8)}' : ''}',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.4,
                                          ),
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ],
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
                                  color: isConnected
                                      ? AppColors.secondary
                                      : AppColors.primary,
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

                            // Timer Display (Runs when connected or shows final duration when completed)
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isConnected ||
                                            callState.status == 'completed'
                                        ? 'Cost: \$${callState.estimatedCost.toStringAsFixed(3)} (@ \$${(rate?.ratePerMinute ?? 0.08).toStringAsFixed(2)}/min)'
                                        : 'Rate: \$${(rate?.ratePerMinute ?? 0.08).toStringAsFixed(2)}/min (Free while ringing)',
                                    style: TextStyle(
                                      color:
                                          isConnected ||
                                              callState.status == 'completed'
                                          ? AppColors.secondary
                                          : Colors.white60,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if ((isConnected ||
                                          callState.status == 'completed') &&
                                      callState.estimatedCost > 0)
                                    ApproxLocalRateText(
                                      callState.estimatedCost,
                                      minDigits: 3,
                                      style: const TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
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
                                  icon: callState.isMuted
                                      ? Icons.mic_off
                                      : Icons.mic,
                                  label: 'Mute',
                                  isActive: callState.isMuted,
                                  onTap: () => ref
                                      .read(callingControllerProvider.notifier)
                                      .toggleMute(),
                                ),
                                _ActionButton(
                                  icon: Icons.dialpad,
                                  label: 'Keypad',
                                  isActive: false,
                                  onTap: () => _showDtmfKeypad(context, ref),
                                ),
                                if (!kIsWeb)
                                  _ActionButton(
                                    icon: callState.isSpeaker
                                        ? Icons.volume_up
                                        : Icons.volume_down,
                                    label: 'Speaker',
                                    isActive: callState.isSpeaker,
                                    onTap: () => ref
                                        .read(
                                          callingControllerProvider.notifier,
                                        )
                                        .toggleSpeaker(),
                                  ),
                              ],
                            ),
                            if (!isEnded) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Keep KeepSIMs open during your call.',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 30),

                            // End Call / Dismiss Button
                            GestureDetector(
                              onTap: () {
                                ref
                                    .read(callingControllerProvider.notifier)
                                    .endCall();
                                if (context.canPop()) {
                                  context.pop();
                                }
                              },
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isEnded
                                      ? Colors.white24
                                      : AppColors.error,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (isEnded
                                                  ? Colors.white
                                                  : AppColors.error)
                                              .withValues(alpha: 0.3),
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

  void _showDtmfKeypad(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _DtmfKeypadSheet(),
    );
  }
}

class _DtmfKeypadSheet extends ConsumerStatefulWidget {
  const _DtmfKeypadSheet();

  @override
  ConsumerState<_DtmfKeypadSheet> createState() => _DtmfKeypadSheetState();
}

class _DtmfKeypadSheetState extends ConsumerState<_DtmfKeypadSheet> {
  String _enteredDigits = '';

  void _onKeyPress(String digit) {
    setState(() {
      _enteredDigits += digit;
    });
    ref.read(callingControllerProvider.notifier).sendDtmf(digit);
  }

  @override
  Widget build(BuildContext context) {
    final keys = [
      ('1', ''),
      ('2', 'ABC'),
      ('3', 'DEF'),
      ('4', 'GHI'),
      ('5', 'JKL'),
      ('6', 'MNO'),
      ('7', 'PQRS'),
      ('8', 'TUV'),
      ('9', 'WXYZ'),
      ('*', ''),
      ('0', '+'),
      ('#', ''),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Keypad',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Container(
                height: 44,
                alignment: Alignment.center,
                child: Text(
                  _enteredDigits.isEmpty
                      ? 'Touch-tone dialpad'
                      : _enteredDigits,
                  style: TextStyle(
                    color: _enteredDigits.isEmpty
                        ? Colors.white38
                        : Colors.white,
                    fontSize: _enteredDigits.isEmpty ? 14 : 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: _enteredDigits.isEmpty ? 0 : 4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: keys.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final item = keys[index];
                  final digit = item.$1;
                  final sub = item.$2;
                  return InkWell(
                    onTap: () => _onKeyPress(digit),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            digit,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (sub.isNotEmpty)
                            Text(
                              sub,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
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
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.1),
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
