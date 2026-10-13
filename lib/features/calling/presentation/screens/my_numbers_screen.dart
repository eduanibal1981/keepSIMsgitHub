/// KeepSIMs — My Virtual DID Numbers & Smart Call Setup Screen
///
/// Features:
/// 1. Provisioned Virtual Numbers list matching Image 2 with Inbound Action dropdown
/// 2. "+ Add Number" button triggering the live Telnyx purchase flow (with intelcallfee)
/// 3. KeepSIMs Smart Call Setup card with real carrier MMI divert rules (all 22 countries)
/// 4. Step 1: Home Operator selector with real carriers (e.g. STC Saudi, Jio, du, Etisalat)
/// 5. Step 2: Live MMI code generated per carrier (e.g. **21* for STC, *401* for Jio)
/// 6. "How it works" guidance and cancellation instructions
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/calling/data/models/carrier_divert_model.dart';
import 'package:keep_sims/features/calling/data/models/virtual_did_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/presentation/widgets/buy_virtual_number_sheet.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';

final virtualDidsProvider =
    FutureProvider.autoDispose<List<VirtualDidNumber>>((ref) async {
  return ref.watch(callingRepositoryProvider).getVirtualDids();
});

final carrierDivertRulesProvider =
    FutureProvider.autoDispose<List<CarrierDivertRule>>((ref) async {
  return ref.watch(callingRepositoryProvider).getCarrierDivertRules();
});

class MyNumbersScreen extends ConsumerStatefulWidget {
  const MyNumbersScreen({super.key});

  @override
  ConsumerState<MyNumbersScreen> createState() => _MyNumbersScreenState();
}

class _MyNumbersScreenState extends ConsumerState<MyNumbersScreen> {
  String? _selectedDidId;
  String? _selectedCarrierId;

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

  String _formatDisplayNumber(String phone) {
    // Format US numbers nicely e.g. +1 (754) 318-0369
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('1')) {
      final area = digits.substring(1, 4);
      final mid = digits.substring(4, 7);
      final last = digits.substring(7);
      return '+1 ($area) $mid-$last';
    } else if (digits.length == 12 && digits.startsWith('44')) {
      final area = digits.substring(2, 4);
      final part1 = digits.substring(4, 8);
      final part2 = digits.substring(8);
      return '+44 $area $part1 $part2';
    }
    return phone;
  }

  String _getNumberTitle(VirtualDidNumber did) {
    final code = did.countryCode.toUpperCase();
    if (code == 'US') return 'US Cloud Gateway';
    if (code == 'GB') return 'London Virtual DID';
    if (code == 'CA') return 'Canada Gateway';
    if (code == 'DE') return 'Germany Cloud DID';
    return '${did.countryName} DID';
  }

  void _openBuyNumberSheet() async {
    final newDid = await BuyVirtualNumberSheet.show(context);
    if (newDid != null) {
      setState(() {
        _selectedDidId = newDid.id;
      });
      ref.invalidate(virtualDidsProvider);
    }
  }

  void _showPstnForwardDialog(BuildContext context, VirtualDidNumber did) {
    final controller =
        TextEditingController(text: did.forwardDestination ?? '');
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
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
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
    final carriersAsync = ref.watch(carrierDivertRulesProvider);
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Virtual Numbers',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF34D399).withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                'Zero-Roaming',
                style: TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.voicemail_rounded,
              color: Colors.white70,
              size: 20,
            ),
            tooltip: 'Voicemail Inbox',
            onPressed: () {
              HapticHelper.lightTick();
              context.push(AppRoutes.voicemail);
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(16),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Global Inbound Numbers & Zero-Roaming Call Divert',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: didsAsync.when(
          data: (dids) {
            final VirtualDidNumber? selectedDid = dids.isNotEmpty
                ? dids.firstWhere(
                    (d) => d.id == _selectedDidId,
                    orElse: () => dids.first,
                  )
                : null;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ── Section 1: Provisioned Virtual Numbers Header matching Image 2 ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Provisioned Virtual Numbers',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _openBuyNumberSheet,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Color(0xFF818CF8), size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Add Number',
                              style: TextStyle(
                                color: Color(0xFF818CF8),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Use your KeepSIMs numbers for inbound calls anywhere in the world.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 12),

                // ── Empty State or Numbers List ──
                if (dids.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.dialer_sip,
                          size: 44,
                          color: Colors.white38,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Virtual Numbers Provisioned',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'A KeepSIMs virtual number receives calls from your home carrier while you are abroad, routing them over your travel eSIM data.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Virtual Number'),
                          onPressed: _openBuyNumberSheet,
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
                              ? const Color(0xFF6366F1).withValues(alpha: 0.6)
                              : AppColors.darkBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Row: Flag, Title, ACTIVE badge, Three-dots
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                                child: Text(
                                  did.flagEmoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          _getNumberTitle(did),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF22C55E)
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
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
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDisplayNumber(did.phoneNumber),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Inbound Action Selector Matching Image 2
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Inbound Action',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: did.forwardMode,
                                        dropdownColor: const Color(0xFF1E293B),
                                        icon: const Icon(
                                          Icons.arrow_drop_down,
                                          color: Colors.white70,
                                          size: 18,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'app',
                                            child: Text('Ring In-App'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'voicemail',
                                            child: Text('Voicemail'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'pstn',
                                            child: Text('Forward Phone'),
                                          ),
                                        ],
                                        onChanged: (val) async {
                                          if (val == null) return;
                                          if (val == 'pstn') {
                                            _showPstnForwardDialog(
                                                context, did);
                                          } else {
                                            await ref
                                                .read(callingRepositoryProvider)
                                                .updateDidForwarding(
                                                  didId: did.id,
                                                  forwardMode: val,
                                                );
                                            ref.invalidate(
                                                virtualDidsProvider);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white38,
                                  size: 18,
                                ),
                                color: const Color(0xFF1E293B),
                                onSelected: (action) {
                                  if (action == 'select') {
                                    setState(() {
                                      _selectedDidId = did.id;
                                    });
                                  } else if (action == 'copy') {
                                    _copyToClipboard(
                                      did.phoneNumber,
                                      'Virtual number',
                                    );
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'select',
                                    child: Text(
                                      'Use in Forwarding Setup',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'copy',
                                    child: Text(
                                      'Copy Number',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 16),

                // ── Section 2: KeepSIMs Smart Call Setup Card matching Image 2 ──
                if (dids.isNotEmpty && selectedDid != null)
                  _buildSmartCallSetupCard(
                    selectedDid,
                    carriersAsync,
                    simLines,
                  ),

                const SizedBox(height: 24),
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
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 36),
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
    AsyncValue<List<CarrierDivertRule>> carriersAsync,
    List<dynamic> simLines,
  ) {
    return carriersAsync.when(
      data: (carriers) {
        // Find selected carrier or default to STC Saudi
        CarrierDivertRule? selectedCarrier;
        if (_selectedCarrierId != null) {
          selectedCarrier = carriers.firstWhere(
            (c) => c.carrierId == _selectedCarrierId,
            orElse: () => carriers.first,
          );
        } else {
          // Try to match from user's registered SIM line
          if (simLines.isNotEmpty) {
            final activeSim = simLines.first;
            final detectedName = (activeSim.nickname ??
                    activeSim.detectedOperatorName ??
                    '')
                .toLowerCase();
            selectedCarrier = carriers.cast<CarrierDivertRule?>().firstWhere(
                  (c) =>
                      c != null &&
                      (detectedName.contains(c.carrierName.toLowerCase()) ||
                          c.carrierName.toLowerCase().contains(detectedName)),
                  orElse: () => null,
                );
          }
          // Default to STC (Saudi Arabia) as shown in Image 2
          selectedCarrier ??= carriers.firstWhere(
            (c) => c.carrierName.toLowerCase().contains('stc'),
            orElse: () => carriers.isNotEmpty
                ? carriers.first
                : const CarrierDivertRule(
                    carrierId: '',
                    carrierName: 'STC Saudi',
                    countryCode: 'SA',
                    countryName: 'Saudi Arabia',
                    cfuFormat: '**21*{number}#',
                    cfuCancel: '##21#',
                    cfuStatus: '*#21#',
                    cancelAll: '##002#',
                  ),
          );
        }

        // Generate MMI code based on carrier's real rule
        final forwardCode = selectedCarrier.formatActivationCode(did.phoneNumber);
        final cancelCode = selectedCarrier.cfuCancel;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Phone-divert Icon, Title, and Zero-Roaming Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.phone_forwarded_rounded,
                      color: Color(0xFF38BDF8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Zero-Roaming Call Forwarding',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4338CA)
                                    .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF818CF8)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.flight_takeoff,
                                    size: 11,
                                    color: Color(0xFF818CF8),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Zero-Roaming',
                                    style: TextStyle(
                                      color: Color(0xFF818CF8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Divert calls from your physical SIM to your KeepSIMs virtual number before traveling. Incoming calls will ring inside this app with \$0 roaming fees.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Step 1: Home Operator Selector Matching Image 2 ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF38BDF8),
                      ),
                      child: const Text(
                        '1',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Home Operator',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Select your current mobile operator.',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCarrier.carrierId.isNotEmpty
                              ? selectedCarrier.carrierId
                              : null,
                          dropdownColor: const Color(0xFF1E293B),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white54,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          items: carriers.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.carrierId,
                              child: Text(
                                '${c.flagEmoji ?? ''} ${c.carrierName}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCarrierId = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Step 2: Dial this MMI code matching Image 2 ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF38BDF8),
                          ),
                          child: const Text(
                            '2',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dial this MMI code on your domestic SIM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Enter the code below on your phone\'s dialer.',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _copyToClipboard(
                            forwardCode,
                            'MMI Code',
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy,
                                    size: 14, color: Color(0xFF38BDF8)),
                                SizedBox(width: 4),
                                Text(
                                  'Copy Code',
                                  style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Monospace Box with MMI Code
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              forwardCode,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontFamily: 'monospace',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.phone,
                              size: 18,
                              color: Color(0xFF22C55E),
                            ),
                            tooltip: 'Dial Code',
                            onPressed: () => _dialCode(forwardCode),
                          ),
                        ],
                      ),
                    ),

                    if (selectedCarrier.specialNotes != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        selectedCarrier.specialNotes!,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 10.5,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        const Text(
                          'To deactivate when returning home: ',
                          style: TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                        InkWell(
                          onTap: () => _copyToClipboard(
                            cancelCode,
                            'Deactivation code',
                          ),
                          child: Text(
                            cancelCode,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── "How it works" Box Matching Image 2 ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Color(0xFF38BDF8),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'How it works:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildHowItWorksItem(
                      'Calls to your home number route to KeepSIMs cloud.',
                    ),
                    const SizedBox(height: 6),
                    _buildHowItWorksItem(
                      'The app rings over Wi-Fi or travel eSIM data.',
                    ),
                    const SizedBox(height: 6),
                    _buildHowItWorksItem(
                      'You avoid roaming fees and keep your number reachable.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => Text(
        'Failed to load carrier divert rules: $e',
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
    );
  }

  Widget _buildHowItWorksItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle,
          color: Color(0xFF22C55E),
          size: 14,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
