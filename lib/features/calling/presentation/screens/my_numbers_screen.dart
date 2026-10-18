/// KeepSIMs — Second Number & Smart Call Setup Screen
///
/// Features:
/// Number-first overview, receive-only SMS inbox, and existing SIM diversion setup.
/// 2. "+ Add Number" button triggering the live Telnyx purchase flow (with intelcallfee)
/// 3. KeepSIMs Smart Call Setup card with real carrier MMI divert rules (all 22 countries)
/// 4. Step 1: Home Operator selector with real carriers (e.g. STC Saudi, Jio, du, Etisalat)
/// 5. Step 2: Live MMI code generated per carrier (e.g. **21* for STC, *401* for Jio)
/// 6. "How it works" guidance and cancellation instructions
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/calling/data/models/carrier_divert_model.dart';
import 'package:keep_sims/features/calling/data/models/virtual_did_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'second_number_overview.dart';
export '../controllers/second_number_controller.dart' show virtualDidsProvider;

final carrierDivertRulesProvider =
    FutureProvider.autoDispose<List<CarrierDivertRule>>((ref) async {
      return ref.watch(callingRepositoryProvider).getCarrierDivertRules();
    });

class MyNumbersScreen extends ConsumerStatefulWidget {
  final String? initialDidId;
  const MyNumbersScreen({super.key, this.initialDidId});

  @override
  ConsumerState<MyNumbersScreen> createState() => _MyNumbersScreenState();
}

class _MyNumbersScreenState extends ConsumerState<MyNumbersScreen> {
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

  @override
  Widget build(BuildContext context) => SecondNumberOverview(
    initialDidId: widget.initialDidId,
    onForwardSetup: (did) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.darkBg,
        builder: (context) => Consumer(
          builder: (context, sheetRef, _) => StatefulBuilder(
            builder: (context, updateSheet) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildSmartCallSetupCard(
                did,
                sheetRef.watch(carrierDivertRulesProvider),
                sheetRef.watch(simLinesControllerProvider).value ?? [],
                refresh: updateSheet,
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _buildSmartCallSetupCard(
    VirtualDidNumber did,
    AsyncValue<List<CarrierDivertRule>> carriersAsync,
    List<dynamic> simLines, {
    StateSetter? refresh,
  }) {
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
            final detectedName =
                (activeSim.nickname ?? activeSim.detectedOperatorName ?? '')
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
        final forwardCode = selectedCarrier.formatActivationCode(
          did.phoneNumber,
        );
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
                                color: const Color(
                                  0xFF4338CA,
                                ).withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(
                                    0xFF818CF8,
                                  ).withValues(alpha: 0.4),
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
                          'Divert calls from your physical SIM to your KeepSIMs second number before traveling. Incoming calls will ring inside this app with \$0 roaming fees.',
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
                              (refresh ?? setState)(() {
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
                          onTap: () =>
                              _copyToClipboard(forwardCode, 'MMI Code'),
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy,
                                  size: 14,
                                  color: Color(0xFF38BDF8),
                                ),
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
                          onTap: () =>
                              _copyToClipboard(cancelCode, 'Deactivation code'),
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
        const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 14),
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
