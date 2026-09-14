import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_sims/features/offline_recharge/service/recovery_reachability_service.dart';
import 'package:keep_sims/features/offline_recharge/ui/recovery_guidance_screen.dart';

abstract final class _C {
  static const surface = Color(0xFF101E30);
  static const surface2 = Color(0xFF182A42);
  static const hairline = Color(0xFF26374F);
  static const signal = Color(0xFF34D399);
  static const signalDim = Color(0x2434D399);
  static const amber = Color(0xFFF5A954);
  static const amberDim = Color(0x24F5A954);
  static const fog = Color(0xFF8FA1B8);
  static const paper = Color(0xFFEEF2F6);
  static const sandboxPurple = Color(0xFF8B5CF6);
  static const sandboxPurpleDim = Color(0x268B5CF6);
}

TextStyle _sans({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = _C.paper,
  double? height,
}) =>
    GoogleFonts.ibmPlexSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );

TextStyle _mono({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = _C.paper,
  double letterSpacing = 0.01,
}) =>
    GoogleFonts.ibmPlexMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );

/// Emergency Backup eSIM Card rendered in Offline Refill.
///
/// Clearly presents the zero-data sponsored recovery option,
/// highlighting that this is a Sandbox Demonstration during pilot phase.
class EmergencyEsimCard extends ConsumerWidget {
  const EmergencyEsimCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recoveryState = ref.watch(recoveryReachabilityServiceProvider);
    final hasEsim = recoveryState.hasBackupEsim;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasEsim
              ? _C.signal.withValues(alpha: 0.3)
              : _C.hairline,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _C.surface2,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.signal_cellular_alt_rounded,
                  size: 20,
                  color: _C.signal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Emergency Backup eSIM',
                            style: _sans(size: 14, weight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _C.sandboxPurpleDim,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SANDBOX',
                            style: _mono(
                              size: 9,
                              weight: FontWeight.w700,
                              color: _C.sandboxPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Zero-data recovery line for barred SIMs',
                      style: _sans(size: 11.5, color: _C.fog),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: hasEsim ? _C.signalDim : _C.amberDim,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: hasEsim
                    ? _C.signal.withValues(alpha: 0.25)
                    : _C.amber.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasEsim
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 16,
                  color: hasEsim ? _C.signal : _C.amber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasEsim
                        ? 'Backup profile ready on device'
                        : 'Setup required before going offline',
                    style: _sans(
                      size: 12,
                      weight: FontWeight.w600,
                      color: hasEsim ? _C.signal : _C.amber,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => RecoveryGuidanceScreen.show(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _C.surface2,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _C.hairline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_rounded,
                      size: 16, color: _C.signal),
                  const SizedBox(width: 8),
                  Text(
                    hasEsim ? 'View eSIM & Recovery Guide' : 'Prepare Backup eSIM',
                    style: _sans(
                      size: 13,
                      weight: FontWeight.w700,
                      color: _C.paper,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
