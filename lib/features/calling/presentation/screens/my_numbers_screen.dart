/// KeepSIMs — My Virtual DID Numbers & Smart Call Setup Screen
///
/// Features:
/// 1. Provisioned Virtual Numbers list with real country, status, and routing preference
/// 2. Inbound routing action selector (Ring In-App, Forward, Voicemail)
/// 3. Integrated KeepSIMs Smart Call Setup card with Home Operator / SIM line context
/// 4. MMI code copy and dialer launcher with cancellation instructions
/// 5. Transparent roaming notice (explaining home-operator vs KeepSIMs charges)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/calling/data/models/virtual_did_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';

final virtualDidsProvider =
    FutureProvider.autoDispose<List<VirtualDidNumber>>((ref) async {
  return ref.watch(callingRepositoryProvider).getVirtualDids();
});

class MyNumbersScreen extends ConsumerStatefulWidget {
  const MyNumbersScreen({super.key});

  @override
  ConsumerState<MyNumbersScreen> createState() => _MyNumbersScreenState();
}

class _MyNumbersScreenState extends ConsumerState<MyNumbersScreen> {
  String? _selectedDidId;
  String? _selectedSimLineId;

  void _copyToClipboard(String text, String label) {
    HapticHelper.lightTick();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _dialCode(String code) async {
    HapticHelper.mediumImpact();
    final clean = Uri.encodeComponent(code);
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        _copyToClipboard(code, 'Code');
      }
    }
  }

  void _showForwardingOptions(BuildContext context, VirtualDidNumber did) {
    HapticHelper.lightTick();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Route Inbound Calls To:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.phone_iphone, color: Color(0xFF22C55E)),
                title: const Text('Ring In-App (VoIP)', style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  'Rings inside KeepSIMs over travel eSIM data or Wi-Fi (No roaming fee)',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: did.forwardMode == 'app'
                    ? const Icon(Icons.check_circle, color: Color(0xFF22C55E))
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(callingRepositoryProvider).updateDidForwarding(
                        didId: did.id,
                        forwardMode: 'app',
                      );
                  ref.invalidate(virtualDidsProvider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.voicemail, color: Colors.purpleAccent),
                title: const Text('Direct to Voicemail', style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  'Inbound caller leaves a voicemail in your KeepSIMs inbox',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: did.forwardMode == 'voicemail'
                    ? const Icon(Icons.check_circle, color: Colors.purpleAccent)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(callingRepositoryProvider).updateDidForwarding(
                        didId: did.id,
                        forwardMode: 'voicemail',
                      );
                  ref.invalidate(virtualDidsProvider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone_forwarded, color: AppColors.primary),
                title: const Text('Forward to External Phone', style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  'Forward to another phone number via telephone network',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: did.forwardMode == 'pstn'
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _showPstnForwardDialog(context, did);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showPstnForwardDialog(BuildContext context, VirtualDidNumber did) {
    final controller = TextEditingController(text: did.forwardDestination ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        title: const Text(
          'Forward to External Number',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. +96891234567',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final destination = controller.text.trim();
              if (destination.isNotEmpty) {
                Navigator.pop(ctx);
                await ref.read(callingRepositoryProvider).updateDidForwarding(
                      didId: did.id,
                      forwardMode: 'pstn',
                      forwardDestination: destination,
                    );
                ref.invalidate(virtualDidsProvider);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final didsAsync = ref.watch(virtualDidsProvider);
    final simLinesState = ref.watch(simLinesControllerProvider);
    final simLines = simLinesState.value ?? [];

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KeepSIMs Smart Calling',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              'Numbers & Smart Call Setup',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: didsAsync.when(
          data: (dids) {
            // Select active DID for setup card if not yet chosen
            final VirtualDidNumber? selectedDid = dids.isNotEmpty
                ? dids.firstWhere(
                    (d) => d.id == _selectedDidId,
                    orElse: () => dids.first,
                  )
                : null;

            // Select active SIM line
            final selectedLine = simLines.firstWhere(
              (l) => l.id == _selectedSimLineId,
              orElse: () => simLines.isNotEmpty
                  ? simLines.first
                  : const SimLine(
                      id: '',
                      userId: '',
                      phoneNumber: '',
                      avatarIcon: 'sim_card',
                    ),
            );

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // Section: Provisioned Numbers Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Provisioned Virtual Numbers',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${dids.length} active',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (dids.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.dialer_sip,
                          size: 40,
                          color: Colors.white38,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No Virtual Numbers Provisioned',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'A KeepSIMs virtual number receives calls from your home carrier while you are abroad, routing them over your travel eSIM data.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  ...dids.map((did) {
                    final isSelectedForSetup = did.id == selectedDid?.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelectedForSetup
                              ? AppColors.primary.withValues(alpha: 0.6)
                              : AppColors.darkBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(did.flagEmoji, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      did.phoneNumber,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    Text(
                                      did.countryName,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  did.status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF22C55E),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Routing Mode:',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    did.forwardModeDisplay,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                icon: const Icon(Icons.tune, size: 14),
                                label: const Text(
                                  'Change',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () => _showForwardingOptions(context, did),
                              ),
                            ],
                          ),
                          if (dids.length > 1) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedDidId = did.id;
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    isSelectedForSetup
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: isSelectedForSetup
                                        ? AppColors.primary
                                        : Colors.white38,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isSelectedForSetup
                                        ? 'Selected for Smart Call Setup'
                                        : 'Use this number for Forwarding Setup',
                                    style: TextStyle(
                                      color: isSelectedForSetup
                                          ? AppColors.primary
                                          : Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 16),

                // Section: KeepSIMs Smart Call Setup Card (Image 3)
                if (dids.isNotEmpty && selectedDid != null)
                  _buildSmartCallSetupCard(selectedDid, simLines, selectedLine),

                const SizedBox(height: 20),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading numbers: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(virtualDidsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmartCallSetupCard(
    VirtualDidNumber did,
    List<SimLine> simLines,
    SimLine selectedLine,
  ) {
    final forwardCode = '**21*${did.phoneNumber}#';
    const cancelCode = '##21#';
    final operatorLabel = selectedLine.nickname ??
        selectedLine.detectedOperatorName ??
        (selectedLine.phoneNumber.isNotEmpty
            ? selectedLine.phoneNumber
            : 'Home SIM Operator');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF818CF8).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF818CF8).withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.settings_phone_rounded,
                  color: Color(0xFF818CF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KeepSIMs Smart Call Setup',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Forward calls from home before traveling',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Home Operator / SIM Line Selector
          if (simLines.isNotEmpty) ...[
            const Text(
              'Select Home Line / Operator:',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedLine.id.isNotEmpty ? selectedLine.id : simLines.first.id,
                  isExpanded: true,
                  dropdownColor: AppColors.darkCard,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                  items: simLines.map((line) {
                    final name = line.nickname ?? line.detectedOperatorName ?? line.phoneNumber;
                    return DropdownMenuItem<String>(
                      value: line.id,
                      child: Text(
                        '$name (${line.phoneNumber})',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedSimLineId = val;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Step 1: Activation Code
          const Text(
            '1. Dial from Home SIM Before Flight:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    forwardCode,
                    style: const TextStyle(
                      color: Color(0xFF22C55E),
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
                  tooltip: 'Copy Code',
                  onPressed: () => _copyToClipboard(forwardCode, 'Activation code'),
                ),
                IconButton(
                  icon: const Icon(Icons.phone, size: 16, color: Color(0xFF22C55E)),
                  tooltip: 'Open Phone Dialer',
                  onPressed: () => _dialCode(forwardCode),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Dual-SIM devices: ensure your Home SIM is selected in your phone dialer.',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),

          const SizedBox(height: 14),

          // Step 2: Cancellation Code
          const Text(
            '2. Cancel Forwarding When Returning Home:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    cancelCode,
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
                  tooltip: 'Copy Code',
                  onPressed: () => _copyToClipboard(cancelCode, 'Cancel code'),
                ),
                IconButton(
                  icon: const Icon(Icons.phone, size: 16, color: Colors.white70),
                  tooltip: 'Open Phone Dialer',
                  onPressed: () => _dialCode(cancelCode),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Transparent Roaming & Operator Guidance
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Standard GSM call forwarding instructions. Confirm forwarding support and domestic charges with $operatorLabel. Inbound calls answered in the KeepSIMs app route over your data connection without cellular voice roaming surcharges.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
