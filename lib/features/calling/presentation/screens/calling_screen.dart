/// KeepSIMs — Smart Calling Screen
///
/// Implements KeepSIMs Smart Call dialer strictly matching Image 1:
/// - Real route/rate header card with per-second rate ticker
/// - Number input with direct editing, paste, and contact picker
/// - Outbound Caller ID cards (Cloud Gateway vs Personal Line)
/// - Clean dialpad with Clear, Smart Call, and Delete actions
/// - Quick Destination Codes (OM +968, EG +20, US +1, GB +44, AE +971, SA +966)
/// - Integrated Recent Calls tab for redial and history
library;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/controllers/smart_call_dialer_controller.dart';
import 'package:keep_sims/features/calling/presentation/widgets/destination_country_search_sheet.dart';
import 'package:keep_sims/features/calling/presentation/widgets/dialpad_widget.dart';
import 'package:keep_sims/features/calling/presentation/widgets/call_history_tile.dart';
import 'package:keep_sims/features/calling/presentation/widgets/verify_caller_id_sheet.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';

class CallingScreen extends ConsumerStatefulWidget {
  final String? initialNumber;

  const CallingScreen({super.key, this.initialNumber});

  @override
  ConsumerState<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends ConsumerState<CallingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  bool _hasInitializedDefaultCountry = false;

  static const List<Map<String, String>> _quickDestinations = [
    {'code': 'OM', 'prefix': '+968'},
    {'code': 'EG', 'prefix': '+20'},
    {'code': 'US', 'prefix': '+1'},
    {'code': 'GB', 'prefix': '+44'},
    {'code': 'AE', 'prefix': '+971'},
    {'code': 'SA', 'prefix': '+966'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialNumber != null && widget.initialNumber!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(smartCallDialerProvider.notifier).setNumber(widget.initialNumber!);
        _phoneController.text = widget.initialNumber!;
      });
    }
  }

  @override
  void didUpdateWidget(CallingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialNumber != null &&
        widget.initialNumber != oldWidget.initialNumber &&
        widget.initialNumber!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(smartCallDialerProvider.notifier).setNumber(widget.initialNumber!);
        _phoneController.text = widget.initialNumber!;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    HapticHelper.lightTick();
    ref.read(smartCallDialerProvider.notifier).appendDigit(digit);
    _syncController();
  }

  void _onDeletePressed() {
    HapticHelper.lightTick();
    ref.read(smartCallDialerProvider.notifier).deleteDigit();
    _syncController();
  }

  void _onClearPressed() {
    HapticHelper.lightTick();
    ref.read(smartCallDialerProvider.notifier).clear();
    _phoneController.clear();
  }

  void _syncController() {
    final number = ref.read(smartCallDialerProvider).rawNumber;
    if (_phoneController.text != number) {
      _phoneController.value = TextEditingValue(
        text: number,
        selection: TextSelection.collapsed(offset: number.length),
      );
    }
  }

  Future<void> _openCountrySearch(List<CallRate> rates) async {
    final dialerState = ref.read(smartCallDialerProvider);
    final selected = await DestinationCountrySearchSheet.show(
      context,
      rates: rates,
      selectedRate: dialerState.selectedRate,
    );
    if (selected != null) {
      ref.read(smartCallDialerProvider.notifier).selectCountryRate(selected);
      _syncController();
    }
  }

  void _showContactPickerSheet(BuildContext context) {
    final simLines = ref.read(simLinesControllerProvider).value ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Contact or Line',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (simLines.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No saved contacts or household lines yet.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: simLines.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white12),
                    itemBuilder: (context, idx) {
                      final line = simLines[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1E293B),
                          child: Text(
                            (line.countryId ?? 'SIM').toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF818CF8),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          line.nickname?.isNotEmpty == true
                              ? line.nickname!
                              : (line.detectedOperatorName?.isNotEmpty == true
                                  ? line.detectedOperatorName!
                                  : line.phoneNumber),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        subtitle: Text(
                          line.phoneNumber,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white38,
                          size: 14,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          ref
                              .read(smartCallDialerProvider.notifier)
                              .setNumber(line.phoneNumber);
                          _syncController();
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startCall({bool forceGateway = false}) async {
    final dialerState = ref.read(smartCallDialerProvider);
    final formattedNumber = dialerState.formattedDestination;

    if (formattedNumber.isEmpty || formattedNumber.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid destination phone number'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final callerIdData = ref.read(callerIdListProvider).asData?.value;
    final isGatewayActive =
        forceGateway || dialerState.isGatewaySelected || (callerIdData?.isGatewayActive ?? true);
    final activeCallerId = isGatewayActive
        ? null
        : callerIdData?.callerIds
            .where((c) => c.isVerified && c.isDefault)
            .firstOrNull;
    final effectiveId = isGatewayActive
        ? (callerIdData?.defaultGatewayNumber ?? '+17543180369')
        : (activeCallerId?.phoneNumber ??
            callerIdData?.defaultGatewayNumber ??
            '+17543180369');

    // Policy check: Self-dialing conflict
    if (!isGatewayActive && effectiveId == formattedNumber) {
      _showRouteConflictDialog(
        title: 'Self-Dialing Not Supported',
        message:
            'You cannot place an outbound call to your own verified Caller ID number. Would you like to call using KeepSIMs Voice Gateway instead?',
        formattedDestination: formattedNumber,
      );
      return;
    }

    // Policy check: External Oman identity calling Oman destination
    if (!isGatewayActive &&
        effectiveId.startsWith('+968') &&
        formattedNumber.startsWith('+968')) {
      _showRouteConflictDialog(
        title: 'Unsupported Carrier Route',
        message:
            'External Oman numbers cannot call Oman numbers directly due to local telecom carrier restrictions. Would you like to connect this call using KeepSIMs Voice Gateway instead?',
        formattedDestination: formattedNumber,
      );
      return;
    }

    // Microphone Permission Pre-flight
    if (!kIsWeb) {
      var micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
      }
      if (!mounted) return;
      if (micStatus.isPermanentlyDenied) {
        _showMicrophonePermissionDialog();
        return;
      }
      if (!micStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to make calls.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    ref
        .read(callingControllerProvider.notifier)
        .startCall(
          destinationNumber: formattedNumber,
          callerIdId: activeCallerId?.id,
          explicitGateway: isGatewayActive,
          userCallbackNumber: effectiveId,
          rate: dialerState.selectedRate,
        );

    context.push(AppRoutes.callingActive);
  }

  void _showMicrophonePermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mic_off, color: AppColors.error, size: 24),
            SizedBox(width: 10),
            Text(
              'Microphone Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'KeepSIMs needs access to your microphone so the person you call can hear you. Please enable microphone permission in your device settings.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRouteConflictDialog({
    required String title,
    required String message,
    required String formattedDestination,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.shield_outlined, size: 16),
            label: const Text(
              'Use KeepSIMs Gateway',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _startCall(forceGateway: true);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletControllerProvider);
    final walletBalance = walletAsync.asData?.value.wallet.balance ?? 0.0;
    final ratesAsync = ref.watch(callRatesProvider);
    final callerIdListAsync = ref.watch(callerIdListProvider);
    final dialerState = ref.watch(smartCallDialerProvider);

    final callerIdData = callerIdListAsync.asData?.value;
    final callerIds = callerIdData?.callerIds ?? [];
    final gatewayNumber = callerIdData?.defaultGatewayNumber ?? '+17543180369';
    final isGatewayActive = dialerState.isGatewaySelected;
    final verifiedLine = callerIds.firstWhereOrNull((c) => c.isVerified);

    final rates = ratesAsync.asData?.value ?? [];

    // Initialize default country rate once
    if (!_hasInitializedDefaultCountry && rates.isNotEmpty) {
      _hasInitializedDefaultCountry = true;
      final defaultRate =
          rates.firstWhereOrNull((r) => r.countryCode == 'OM') ??
          rates.firstWhereOrNull((r) => r.countryCode == 'EG') ??
          rates.first;
      if (dialerState.selectedRate == null) {
        Future.microtask(() {
          ref.read(smartCallDialerProvider.notifier).selectCountryRate(defaultRate);
        });
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.signal_cellular_alt_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'KeepSIMs',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF818CF8).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF818CF8).withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                'Smart Calling',
                style: TextStyle(
                  color: Color(0xFF818CF8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Wallet balance pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(0xFF10B981),
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  '\$${walletBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF818CF8),
          labelColor: const Color(0xFF818CF8),
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Dialer'),
            Tab(text: 'Recent Calls'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Smart Call Dialer ──
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. KeepSIMs Smart Call Rate Card (Image 1)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF818CF8).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rate & Destination Header
                      InkWell(
                        onTap: () => _openCountrySearch(rates),
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.public_rounded,
                                color: Color(0xFF818CF8),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Text(
                                        'KeepSIMs Smart Call',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: Colors.white54,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                  Text(
                                    dialerState.selectedRate != null
                                        ? 'International Route • ${dialerState.selectedRate!.countryName} (${dialerState.selectedRate!.phonePrefix})'
                                        : 'Select Destination Route',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '\$${dialerState.effectiveRatePerMinute.toStringAsFixed(3)}/min',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Number / Contact Input Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF070E17),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              color: Colors.white38,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                focusNode: _phoneFocusNode,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Type a number or select a contact',
                                  hintStyle: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 13,
                                    fontWeight: FontWeight.normal,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onChanged: (val) {
                                  ref
                                      .read(smartCallDialerProvider.notifier)
                                      .setNumber(val);
                                },
                              ),
                            ),
                            // Contacts Icon Action
                            IconButton(
                              icon: const Icon(
                                Icons.person_outline_rounded,
                                color: Color(0xFF818CF8),
                                size: 20,
                              ),
                              tooltip: 'Contacts',
                              onPressed: () => _showContactPickerSheet(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Per-second rate display
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Per-second rate:',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            dialerState.isPreviewLoading
                                ? 'Calculating rate...'
                                : '\$${dialerState.effectiveRatePerSecond.toStringAsFixed(5)}/sec',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Outbound Caller ID (CLID) Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'OUTBOUND CALLER ID (CLID)',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white38,
                          size: 13,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          color: !isGatewayActive
                              ? const Color(0xFF10B981)
                              : Colors.white38,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          !isGatewayActive ? 'Verified' : 'Default Route',
                          style: TextStyle(
                            color: !isGatewayActive
                                ? const Color(0xFF10B981)
                                : Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Two Caller ID Cards (Cloud Gateway vs Personal Line)
                Row(
                  children: [
                    // Gateway Card
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          ref
                              .read(smartCallDialerProvider.notifier)
                              .selectIdentity(isGateway: true);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isGatewayActive
                                  ? const Color(0xFF818CF8)
                                  : const Color(0xFF1E293B),
                              width: isGatewayActive ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.public_rounded,
                                color: Color(0xFF818CF8),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Cloud Gateway',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      gatewayNumber,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isGatewayActive
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: isGatewayActive
                                    ? const Color(0xFF818CF8)
                                    : Colors.white24,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Personal Line Card
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          if (verifiedLine != null) {
                            ref
                                .read(smartCallDialerProvider.notifier)
                                .selectIdentity(
                                  isGateway: false,
                                  callerIdId: verifiedLine.id,
                                  phoneNumber: verifiedLine.phoneNumber,
                                );
                          } else {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => const VerifyCallerIdSheet(),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: !isGatewayActive
                                  ? const Color(0xFF818CF8)
                                  : const Color(0xFF1E293B),
                              width: !isGatewayActive ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.smartphone_rounded,
                                color: Color(0xFF10B981),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Personal Line',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      verifiedLine != null
                                          ? verifiedLine.phoneNumber
                                          : '• Verify Number',
                                      style: TextStyle(
                                        color: verifiedLine != null
                                            ? Colors.white60
                                            : const Color(0xFF38BDF8),
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                !isGatewayActive
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: !isGatewayActive
                                    ? const Color(0xFF818CF8)
                                    : Colors.white24,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3. Dialpad Keys (Image 1)
                DialpadWidget(
                  onKeyPressed: _onDigitPressed,
                  onDeletePressed: _onDeletePressed,
                  onLongDeletePressed: _onClearPressed,
                ),
                const SizedBox(height: 14),

                // 4. Bottom Dialpad Row: Clear - Call ("Smart Call") - Delete
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Clear Button
                      TextButton(
                        onPressed: _onClearPressed,
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Smart Call Initiation Button (PSTN)
                      GestureDetector(
                        onTap: () => _startCall(),
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.phone_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),

                      // Delete Button
                      TextButton(
                        onPressed: _onDeletePressed,
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 5. Quick Destination Codes (Image 1)
                const Text(
                  'QUICK DESTINATION CODES',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickDestinations.map((dest) {
                    return InkWell(
                      onTap: () {
                        HapticHelper.lightTick();
                        final match = rates.firstWhereOrNull(
                          (r) => r.countryCode == dest['code'],
                        );
                        if (match != null) {
                          ref
                              .read(smartCallDialerProvider.notifier)
                              .selectCountryRate(match);
                        } else {
                          ref
                              .read(smartCallDialerProvider.notifier)
                              .setNumber(dest['prefix']!);
                        }
                        _syncController();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Text(
                          '${dest['code']}  ${dest['prefix']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // ── Tab 2: Recent Call History ──
          Consumer(
            builder: (context, ref, _) {
              final historyAsync = ref.watch(callHistoryStreamProvider);
              return historyAsync.when(
                data: (records) {
                  if (records.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_missed_rounded,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 54,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No call history yet',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Make your first Smart Call to connect worldwide!',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: records.length,
                    itemBuilder: (context, idx) {
                      final rec = records[idx];
                      return CallHistoryTile(
                        record: rec,
                        onRedial: () {
                          ref
                              .read(smartCallDialerProvider.notifier)
                              .setNumber(rec.destinationNumber);
                          _syncController();
                          _tabController.animateTo(0);
                        },
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, _) => Center(
                  child: Text(
                    'Error: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
