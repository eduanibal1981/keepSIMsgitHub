import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_sims/features/offline_recharge/model/recovery_state_model.dart';
import 'package:keep_sims/features/offline_recharge/repository/recovery_repository.dart';
import 'package:keep_sims/features/offline_recharge/service/recovery_reachability_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

abstract final class _C {
  static const ink = Color(0xFF0B1622);
  static const surface = Color(0xFF101E30);
  static const surface2 = Color(0xFF182A42);
  static const surface3 = Color(0xFF1F3450);
  static const hairline = Color(0xFF26374F);
  static const signal = Color(0xFF34D399);
  static const signalDim = Color(0x2434D399);
  static const amber = Color(0xFFF5A954);
  static const danger = Color(0xFFF2545B);
  static const fog = Color(0xFF8FA1B8);
  static const fogDim = Color(0xFF5C7089);
  static const paper = Color(0xFFEEF2F6);
  static const sandboxBadge = Color(0xFF8B5CF6);
  static const sandboxBadgeDim = Color(0x268B5CF6);
}

TextStyle _sans({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = _C.paper,
  double? height,
  double letterSpacing = 0,
}) =>
    GoogleFonts.ibmPlexSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
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

class RecoveryGuidanceScreen extends ConsumerStatefulWidget {
  const RecoveryGuidanceScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecoveryGuidanceScreen()),
    );
  }

  @override
  ConsumerState<RecoveryGuidanceScreen> createState() =>
      _RecoveryGuidanceScreenState();
}

class _RecoveryGuidanceScreenState extends ConsumerState<RecoveryGuidanceScreen> {
  String? _copiedField;
  bool _isActionLoading = false;
  int _osTabIndex = Platform.isIOS ? 0 : 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recoveryReachabilityServiceProvider.notifier).probeReachability();
      ref.read(recoveryRepositoryProvider).syncLatestStatus();
    });
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    setState(() => _copiedField = label);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copiedField = null);
    });
  }

  Future<void> _handlePrepareProfile() async {
    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(recoveryRepositoryProvider);
      final res = await repo.prepareRecoveryProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.isSuccess
                ? 'Backup profile prepared (Sandbox mode)'
                : 'Preparation failed: ${res.error}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleRequestAllowance() async {
    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(recoveryRepositoryProvider);
      final res = await repo.requestRecoveryAllowance();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.isSuccess
                ? 'Emergency 1 GB sandbox allowance granted!'
                : 'Request failed: ${res.error}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recoveryReachabilityServiceProvider);

    return Scaffold(
      backgroundColor: _C.ink,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: _C.paper),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Emergency Recovery',
          style: _sans(size: 17, weight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: state.reachability.isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _C.signal,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: _C.fog),
            tooltip: 'Probe Connection',
            onPressed: state.reachability.isChecking
                ? null
                : () => ref
                    .read(recoveryReachabilityServiceProvider.notifier)
                    .probeReachability(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSandboxBanner(),
                const SizedBox(height: 12),
                _buildReachabilityCard(state),
                const SizedBox(height: 16),
                _buildProfileCard(state),
                const SizedBox(height: 16),
                _buildAllowanceCard(state),
                const SizedBox(height: 16),
                _buildDeviceSwitchingInstructions(),
                const SizedBox(height: 24),
                _buildOfflineFallbackOptions(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSandboxBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.sandboxBadgeDim,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.sandboxBadge.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, size: 20, color: _C.sandboxBadge),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'SANDBOX DEMONSTRATION',
                      style: _sans(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: _C.sandboxBadge,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _C.sandboxBadge.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('FIRSTY STAGING',
                          style: _mono(size: 9.5, color: _C.paper)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Mock eSIM activation code and allowance for offline recovery validation. Does not provide live cellular RF data until Firsty commercial activation.',
                  style: _sans(size: 11.5, color: _C.fog, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReachabilityCard(RecoveryStateModel state) {
    Color statusColor;
    IconData statusIcon;

    switch (state.reachability) {
      case KeepSimsReachability.reachable:
        statusColor = _C.signal;
        statusIcon = Icons.check_circle_outline_rounded;
      case KeepSimsReachability.checking:
        statusColor = _C.amber;
        statusIcon = Icons.sync_rounded;
      case KeepSimsReachability.unreachable:
        statusColor = _C.danger;
        statusIcon = Icons.wifi_off_rounded;
      case KeepSimsReachability.serviceError:
        statusColor = _C.amber;
        statusIcon = Icons.warning_amber_rounded;
      case KeepSimsReachability.unknown:
        statusColor = _C.fog;
        statusIcon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 20, color: statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.reachability.userMessage,
                  style: _sans(size: 14, weight: FontWeight.w600),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _C.hairline),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: state.reachability.isChecking
                    ? null
                    : () => ref
                        .read(recoveryReachabilityServiceProvider.notifier)
                        .probeReachability(),
                child: Text('Probe', style: _sans(size: 12, color: _C.paper)),
              ),
            ],
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              state.errorMessage!,
              style: _sans(size: 11.5, color: _C.danger),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Interface: ${state.interfaceType.label}',
                  style: _mono(size: 11, color: _C.fogDim)),
              const Spacer(),
              if (state.lastCheckedAt != null)
                Text(
                  'Checked ${state.lastCheckedAt!.hour.toString().padLeft(2, '0')}:${state.lastCheckedAt!.minute.toString().padLeft(2, '0')}:${state.lastCheckedAt!.second.toString().padLeft(2, '0')}',
                  style: _mono(size: 11, color: _C.fogDim),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(RecoveryStateModel state) {
    if (!state.hasBackupEsim) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sim_card_alert_outlined,
                    size: 20, color: _C.amber),
                const SizedBox(width: 10),
                Text('Backup eSIM Profile',
                    style: _sans(size: 14.5, weight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'No emergency recovery eSIM profile is currently saved on this device. Prepare a backup profile before going offline.',
              style: _sans(size: 12.5, color: _C.fog, height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.signal,
                  foregroundColor: const Color(0xFF06251A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isActionLoading ? null : _handlePrepareProfile,
                child: _isActionLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Prepare Backup eSIM (Sandbox)',
                        style: _sans(size: 13.5, weight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sim_card_rounded, size: 20, color: _C.signal),
              const SizedBox(width: 10),
              Text('Backup eSIM (Ready Offline)',
                  style: _sans(size: 14.5, weight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.signalDim,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(state.provisioningState.label,
                    style: _sans(
                        size: 11, weight: FontWeight.w600, color: _C.signal)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // QR Code rendering
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.hairline),
              ),
              child: QrImageView(
                data: state.activationCode ?? '',
                version: QrVersions.auto,
                size: 160.0,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow('LPA Activation Code', state.activationCode ?? '',
              isMonospace: true, copyable: true),
          if (state.iccid != null)
            _buildInfoRow('ICCID', state.iccid!,
                isMonospace: true, copyable: true),
          if (state.smdpAddress != null)
            _buildInfoRow('SM-DP+ Address', state.smdpAddress!,
                isMonospace: true, copyable: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _C.hairline),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => ref
                      .read(recoveryReachabilityServiceProvider.notifier)
                      .reportInstallationCompleted(),
                  child: Text('Mark as Installed',
                      style: _sans(size: 12.5, color: _C.paper)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllowanceCard(RecoveryStateModel state) {
    final hasAllowance = state.remainingMb > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.data_saver_on_outlined,
                  size: 20, color: _C.amber),
              const SizedBox(width: 10),
              Text('Recovery Data Allowance',
                  style: _sans(size: 14.5, weight: FontWeight.w600)),
              const Spacer(),
              Text(
                hasAllowance
                    ? '${state.remainingMb} MB / ${state.totalMb} MB'
                    : '0 MB',
                style: _mono(
                    size: 12,
                    weight: FontWeight.w700,
                    color: hasAllowance ? _C.signal : _C.fogDim),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Partner-funded emergency data session to restore messaging and banking access once KeepSIMs is reached.',
            style: _sans(size: 12, color: _C.fog, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.surface2,
                foregroundColor: _C.paper,
                side: const BorderSide(color: _C.hairline),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.bolt_rounded, size: 18, color: _C.amber),
              label: _isActionLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Request 1 GB Sandbox Allowance',
                      style: _sans(size: 13, weight: FontWeight.w600)),
              onPressed: _isActionLoading ? null : _handleRequestAllowance,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isMonospace = false, bool copyable = false}) {
    final isCopied = _copiedField == label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _C.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _C.hairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _sans(size: 11, color: _C.fogDim)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: isMonospace
                        ? _mono(size: 12, color: _C.paper)
                        : _sans(size: 12, color: _C.paper),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (copyable)
              IconButton(
                icon: Icon(
                  isCopied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 16,
                  color: isCopied ? _C.signal : _C.fog,
                ),
                onPressed: () => _copy(label, value),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSwitchingInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_phone_outlined,
                  size: 20, color: _C.paper),
              const SizedBox(width: 10),
              Text('How to Switch Mobile Data',
                  style: _sans(size: 14.5, weight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          // OS Switcher
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _osTabIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _osTabIndex == 0 ? _C.surface3 : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _osTabIndex == 0 ? _C.signal : _C.hairline,
                      ),
                    ),
                    child: Center(
                      child: Text('iPhone (iOS)',
                          style: _sans(
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: _osTabIndex == 0 ? _C.signal : _C.fog)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _osTabIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _osTabIndex == 1 ? _C.surface3 : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _osTabIndex == 1 ? _C.signal : _C.hairline,
                      ),
                    ),
                    child: Center(
                      child: Text('Android',
                          style: _sans(
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: _osTabIndex == 1 ? _C.signal : _C.fog)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_osTabIndex == 0) ...[
            _buildStepRow(1, 'Open Settings > Cellular (or Mobile Data).'),
            _buildStepRow(2, 'Tap your KeepSIMs Backup eSIM and toggle Turn On.'),
            _buildStepRow(3, 'Tap Cellular Data and choose the Backup eSIM line.'),
            _buildStepRow(4, 'Ensure "Allow Cellular Data Switching" is OFF.'),
          ] else ...[
            _buildStepRow(1, 'Open Settings > Network & internet > SIMs.'),
            _buildStepRow(2, 'Select KeepSIMs Backup eSIM and enable it.'),
            _buildStepRow(3, 'Set Mobile data preference to this eSIM.'),
            _buildStepRow(4, 'Ensure Data Roaming is enabled for the backup line.'),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: _C.surface2,
              shape: BoxShape.circle,
              border: Border.all(color: _C.hairline),
            ),
            child: Center(
              child: Text(
                '$number',
                style: _mono(size: 11, weight: FontWeight.w600, color: _C.fog),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: _sans(size: 12.5, color: _C.paper, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineFallbackOptions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Other Ways to Refill Offline',
              style: _sans(size: 13, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'If the backup eSIM has no signal, you can still trigger a refill via WhatsApp, SMS, or Emergency PIN.',
            style: _sans(size: 11.5, color: _C.fog, height: 1.4),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _C.hairline),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.offline_bolt_outlined,
                size: 16, color: _C.signal),
            label: Text('Open Offline Refill Channels',
                style: _sans(size: 12, color: _C.paper)),
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
