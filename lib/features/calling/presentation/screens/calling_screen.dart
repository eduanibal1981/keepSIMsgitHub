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
import 'package:keep_sims/core/fx/money.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/controllers/smart_call_dialer_controller.dart';
import 'package:keep_sims/features/calling/presentation/widgets/destination_country_picker.dart';
import 'package:keep_sims/features/calling/presentation/widgets/call_review_sheet.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/calling/presentation/widgets/dialpad_widget.dart';
import 'package:keep_sims/features/calling/presentation/widgets/call_history_tile.dart';
import 'package:keep_sims/features/calling/presentation/widgets/verify_caller_id_sheet.dart';
import 'package:keep_sims/features/calling/data/services/device_contact_picker.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';

class CallingScreen extends ConsumerStatefulWidget {
  final String? initialNumber;
  final bool showHistory;

  const CallingScreen({
    super.key,
    this.initialNumber,
    this.showHistory = false,
  });

  @override
  ConsumerState<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends ConsumerState<CallingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  bool _reviewingCall = false;

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
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showHistory ? 1 : 0,
    );
    _phoneController.text = ref.read(smartCallDialerProvider).rawNumber;
    if (widget.initialNumber != null && widget.initialNumber!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(smartCallDialerProvider.notifier)
            .setNumber(widget.initialNumber!);
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
        ref
            .read(smartCallDialerProvider.notifier)
            .setNumber(widget.initialNumber!);
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
    final iso = await pickDestinationCountry(
      context,
      suggestedIso: ref.read(smartCallDialerProvider).suggestedCountryIso,
    );
    if (!mounted || iso == null) return;
    ref.read(smartCallDialerProvider.notifier).selectCountry(iso);
    _syncController();
  }

  bool _pickingContact = false;

  Future<void> _showContactPickerSheet(BuildContext context) async {
    if (_pickingContact) return;
    _pickingContact = true;
    HapticHelper.lightTick();
    try {
      final number = await const DeviceContactPicker().pickPhoneNumber();
      if (!mounted || number == null || number.isEmpty) return;
      _phoneController.value = TextEditingValue(
        text: number,
        selection: TextSelection.collapsed(offset: number.length),
      );
      ref.read(smartCallDialerProvider.notifier).setNumber(number);
    } catch (_) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phone contacts are unavailable. Please enter a number manually.',
          ),
        ),
      );
    } finally {
      _pickingContact = false;
    }
  }

  Future<void> _startCall() async {
    if (_reviewingCall) return;
    _reviewingCall = true;
    try {
      await CallReviewSheet.showAndCall(
        context,
        ref,
        suggestedCountryIso: ref
            .read(authControllerProvider)
            .asData
            ?.value
            ?.homeCountryCode,
      );
      if (mounted) _syncController();
    } finally {
      _reviewingCall = false;
    }
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
    final gatewayNumber = callerIdData?.defaultGatewayNumber ?? 'Loading…';
    final isGatewayActive = dialerState.isGatewaySelected;
    final verifiedLine = callerIds.firstWhereOrNull((c) => c.isVerified);

    final rates = ratesAsync.asData?.value ?? [];

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
              context.go(AppRoutes.calling);
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
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
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
                                        ? destinationCountryLabel(
                                            context,
                                            dialerState.destination.countryIso,
                                          )
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  dialerState.previewResult == null
                                      ? '—'
                                      : '\$${dialerState.effectiveRatePerMinute.toStringAsFixed(3)}/min',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (!dialerState.isPreviewLoading &&
                                    dialerState.previewResult != null)
                                  ApproxLocalRateText(
                                    dialerState.effectiveRatePerMinute,
                                    unit: '/min',
                                    minDigits: 3,
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
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
                                      .setNumber(val, preserveCountry: true);
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dialerState.isPreviewLoading
                                    ? 'Calculating rate...'
                                    : dialerState.previewResult == null
                                    ? '—'
                                    : '\$${dialerState.effectiveRatePerSecond.toStringAsFixed(5)}/sec',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (!dialerState.isPreviewLoading &&
                                  dialerState.previewResult != null)
                                ApproxLocalRateText(
                                  dialerState.effectiveRatePerSecond,
                                  unit: '/s',
                                  maxDigits: 5,
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
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
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.35),
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
                          _startCall();
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
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
