/// KeepSIMs — International App-to-Phone Calling Screen
library;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/widgets/destination_country_search_sheet.dart';
import 'package:keep_sims/features/calling/presentation/widgets/dialpad_widget.dart';
import 'package:keep_sims/features/calling/presentation/widgets/call_history_tile.dart';
import 'package:keep_sims/features/calling/presentation/widgets/caller_id_picker_sheet.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';

class CallingScreen extends ConsumerStatefulWidget {
  const CallingScreen({super.key});

  @override
  ConsumerState<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends ConsumerState<CallingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _phoneController = TextEditingController();
  CallRate? _selectedCountryRate;
  bool _hasInitializedDefaultCountry = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    setState(() {
      _phoneController.text += digit;
      if (_selectedCountryRate == null || digit == '+') {
        final rates = ref.read(callRatesProvider).asData?.value ?? [];
        _autoDetectRateFromInput(_phoneController.text, rates);
      }
    });
  }

  void _onDeletePressed() {
    final text = _phoneController.text;
    if (text.isNotEmpty) {
      setState(() {
        _phoneController.text = text.substring(0, text.length - 1);
        if (_selectedCountryRate == null) {
          final rates = ref.read(callRatesProvider).asData?.value ?? [];
          _autoDetectRateFromInput(_phoneController.text, rates);
        }
      });
    }
  }

  void _onClearPressed() {
    setState(() {
      _phoneController.clear();
    });
  }

  void _autoDetectRateFromInput(String number, List<CallRate> rates) {
    if (number.isEmpty || rates.isEmpty) return;
    CallRate? matched;
    int maxLen = 0;
    for (final r in rates) {
      final prefixClean = r.phonePrefix.replaceAll('+', '');
      final numberClean = number.replaceAll('+', '');
      if ((number.startsWith(r.phonePrefix) ||
              numberClean.startsWith(prefixClean)) &&
          r.phonePrefix.length > maxLen) {
        matched = r;
        maxLen = r.phonePrefix.length;
      }
    }
    if (matched != null) {
      final found = matched;
      setState(() {
        _selectedCountryRate = found;
        if (number.startsWith(found.phonePrefix)) {
          _phoneController.text = number.substring(found.phonePrefix.length);
        }
      });
    }
  }

  Future<void> _openCountrySearch(List<CallRate> rates) async {
    final selected = await DestinationCountrySearchSheet.show(
      context,
      rates: rates,
      selectedRate: _selectedCountryRate,
    );
    if (selected != null) {
      setState(() {
        _selectedCountryRate = selected;
      });
    }
  }

  void _openCallerIdPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CallerIdPickerSheet(),
    );
  }

  void _startCall() {
    final national = _phoneController.text.trim();
    if (_selectedCountryRate == null && !national.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a destination country or enter country code',
          ),
        ),
      );
      return;
    }

    if (national.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a destination phone number'),
        ),
      );
      return;
    }

    final String formattedNumber;
    if (national.startsWith('+')) {
      formattedNumber = national;
    } else {
      final cleanNational =
          national.startsWith('0') ? national.substring(1) : national;
      final prefix = _selectedCountryRate!.phonePrefix.startsWith('+')
          ? _selectedCountryRate!.phonePrefix
          : '+${_selectedCountryRate!.phonePrefix}';
      formattedNumber = '$prefix$cleanNational';
    }

    // Get active caller ID if verified
    final callerIdsAsync = ref.read(userCallerIdsProvider);
    final callerIds = callerIdsAsync.asData?.value ?? [];
    final activeCallerId = callerIds
        .where((c) => c.isVerified && c.isDefault)
        .firstOrNull
        ?.phoneNumber;

    ref.read(callingControllerProvider.notifier).startCall(
          destinationNumber: formattedNumber,
          userCallbackNumber: activeCallerId ?? '+17543180369',
          rate: _selectedCountryRate,
        );

    context.push(AppRoutes.callingActive);
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletControllerProvider);
    final walletBalance = walletAsync.asData?.value.wallet.balance ?? 0.0;
    final ratesAsync = ref.watch(callRatesProvider);
    final callerIdListAsync = ref.watch(callerIdListProvider);

    final callerIds = callerIdListAsync.asData?.value.callerIds ?? [];
    final activeCallerId =
        callerIds.where((c) => c.isVerified && c.isDefault).firstOrNull;
    final gatewayNumber =
        callerIdListAsync.asData?.value.defaultGatewayNumber ?? '+17543180369';

    final rates = ratesAsync.asData?.value ?? [];

    // Initialize default country from Caller ID or default list once rates arrive
    if (!_hasInitializedDefaultCountry && rates.isNotEmpty) {
      _hasInitializedDefaultCountry = true;
      if (activeCallerId != null) {
        for (final r in rates) {
          if (activeCallerId.phoneNumber.startsWith(r.phonePrefix)) {
            _selectedCountryRate = r;
            break;
          }
        }
      }
      _selectedCountryRate ??=
          rates.firstWhereOrNull((r) => r.countryCode == 'OM') ??
              rates.firstWhereOrNull((r) => r.countryCode == 'EG') ??
              rates.first;
    }

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
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
        title: const Text(
          'International Calling',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          // Unified Wallet Balance Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.primary,
                  size: 15,
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
          // Close button on other side of balance
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 22,
            ),
            tooltip: 'Close',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.home);
              }
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.dialpad), text: 'Dialer'),
            Tab(icon: Icon(Icons.history), text: 'Recent Calls'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Dialer & Rates ──
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // ── Switchable Caller ID Status Banner ──
                  GestureDetector(
                    onTap: _openCallerIdPicker,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: (activeCallerId != null
                                ? AppColors.secondary
                                : AppColors.primary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (activeCallerId != null
                                  ? AppColors.secondary
                                  : AppColors.primary)
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            activeCallerId != null
                                ? Icons.verified_user_rounded
                                : Icons.shield_outlined,
                            color: activeCallerId != null
                                ? AppColors.secondary
                                : AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      activeCallerId != null
                                          ? 'Outgoing Caller ID'
                                          : 'Outgoing Caller ID: KeepSIMs Gateway',
                                      style: TextStyle(
                                        color: activeCallerId != null
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (activeCallerId != null
                                                ? AppColors.secondary
                                                : AppColors.primary)
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        activeCallerId != null
                                            ? 'VERIFIED'
                                            : 'DEFAULT',
                                        style: TextStyle(
                                          color: activeCallerId != null
                                              ? AppColors.secondary
                                              : AppColors.primary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  activeCallerId != null
                                      ? activeCallerId.phoneNumber
                                      : gatewayNumber,
                                  style: TextStyle(
                                    color: activeCallerId != null
                                        ? AppColors.secondary
                                        : AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.darkCard,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.darkBorder),
                            ),
                            child: const Icon(
                              Icons.swap_horiz_rounded,
                              color: Colors.white70,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Phone Input Box (Country Code Beside Text Entry + Price Below) ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedCountryRate != null
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.darkBorder,
                        width: _selectedCountryRate != null ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Row: Country Code Selector Beside Phone Number Text Entry
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Country Code Picker Button
                            InkWell(
                              onTap: () => _openCountrySearch(rates),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.darkBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedCountryRate?.flagEmoji ?? '🌐',
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _selectedCountryRate?.phonePrefix ?? '+',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.white54,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Vertical divider
                            Container(
                              height: 28,
                              width: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              color: Colors.white12,
                            ),

                            // National Phone Number Text Entry
                            Expanded(
                              child: Text(
                                _phoneController.text.isEmpty
                                    ? 'Phone number'
                                    : _phoneController.text,
                                style: TextStyle(
                                  color: _phoneController.text.isEmpty
                                      ? Colors.white24
                                      : Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Backspace Button
                            if (_phoneController.text.isNotEmpty)
                              GestureDetector(
                                onLongPress: _onClearPressed,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.backspace_outlined,
                                    color: Colors.white70,
                                    size: 22,
                                  ),
                                  onPressed: _onDeletePressed,
                                  splashRadius: 20,
                                  tooltip: 'Backspace (Hold to clear)',
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        const Divider(color: Colors.white10, height: 1),
                        const SizedBox(height: 8),

                        // Price / Rate row shown below the entry
                        Row(
                          children: [
                            if (_selectedCountryRate != null) ...[
                              const Icon(
                                Icons.savings_outlined,
                                color: AppColors.secondary,
                                size: 15,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    text:
                                        '${_selectedCountryRate!.countryName}: ',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                    children: [
                                      TextSpan(
                                        text:
                                            '\$${_selectedCountryRate!.ratePerMinute.toStringAsFixed(3)}/min',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            ' (\$${_selectedCountryRate!.ratePerSecond.toStringAsFixed(4)}/s)',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Per-sec billing',
                                  style: TextStyle(
                                    color: AppColors.secondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ] else ...[
                              const Icon(
                                Icons.info_outline,
                                color: Colors.white38,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'Select a destination country to view rates',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Dialpad Keys ──
                  DialpadWidget(
                    onKeyPressed: _onDigitPressed,
                    onDeletePressed: _onDeletePressed,
                    onLongDeletePressed: _onClearPressed,
                  ),

                  const SizedBox(height: 14),

                  // ── Call Initiation Button ──
                  GestureDetector(
                    onTap: _startCall,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.accentGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.phone,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
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
                            Icons.phone_missed,
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
                            'Make your first pay-per-second international call!',
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
                          final number = rec.destinationNumber;
                          final currentRates =
                              ref.read(callRatesProvider).asData?.value ?? [];
                          CallRate? matched;
                          int maxLen = 0;
                          for (final r in currentRates) {
                            if (number.startsWith(r.phonePrefix) &&
                                r.phonePrefix.length > maxLen) {
                              matched = r;
                              maxLen = r.phonePrefix.length;
                            }
                          }
                          final found = matched;
                          setState(() {
                            if (found != null) {
                              _selectedCountryRate = found;
                              _phoneController.text =
                                  number.substring(found.phonePrefix.length);
                            } else {
                              _phoneController.text = number;
                            }
                            _tabController.animateTo(0);
                          });
                        },
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
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
