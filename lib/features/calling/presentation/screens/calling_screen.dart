/// KeepSIMs — International App-to-Phone Calling Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/widgets/country_rate_chip.dart';
import 'package:keep_sims/features/calling/presentation/widgets/dialpad_widget.dart';
import 'package:keep_sims/features/calling/presentation/widgets/call_history_tile.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';

class CallingScreen extends ConsumerStatefulWidget {
  const CallingScreen({super.key});

  @override
  ConsumerState<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends ConsumerState<CallingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _dialNumberController = TextEditingController();
  CallRate? _detectedRate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dialNumberController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    setState(() {
      _dialNumberController.text += digit;
      _updateDetectedRate(_dialNumberController.text);
    });
  }

  void _onDeletePressed() {
    final text = _dialNumberController.text;
    if (text.isNotEmpty) {
      setState(() {
        _dialNumberController.text = text.substring(0, text.length - 1);
        _updateDetectedRate(_dialNumberController.text);
      });
    }
  }

  void _updateDetectedRate(String number) {
    if (number.isEmpty) {
      _detectedRate = null;
      return;
    }
    final ratesAsync = ref.read(callRatesProvider);
    final rates = ratesAsync.asData?.value ?? [];

    // Find longest matching prefix
    CallRate? matched;
    int maxLen = 0;
    for (final r in rates) {
      if (number.startsWith(r.phonePrefix) && r.phonePrefix.length > maxLen) {
        matched = r;
        maxLen = r.phonePrefix.length;
      }
    }
    _detectedRate = matched;
  }

  void _startCall() {
    final dest = _dialNumberController.text.trim();
    if (dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an international phone number')),
      );
      return;
    }

    final simLinesAsync = ref.read(simLinesControllerProvider);
    final simLines = simLinesAsync.asData?.value ?? [];
    final defaultCallback = simLines.isNotEmpty ? simLines.first.phoneNumber : '+96891234567';

    ref.read(callingControllerProvider.notifier).startCall(
      destinationNumber: dest.startsWith('+') ? dest : '+$dest',
      userCallbackNumber: defaultCallback,
      rate: _detectedRate,
    );

    context.push('/calling/active');
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletControllerProvider);
    final walletBalance = walletAsync.asData?.value.wallet.balance ?? 0.0;
    final ratesAsync = ref.watch(callRatesProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'International Calling',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          // Unified Wallet Balance Badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  '\$${walletBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
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
          // ── Tab 1: Dialpad & Live Rates ──
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // Popular Country Rates Carousel / Row
                  ratesAsync.when(
                    data: (rates) => SizedBox(
                      height: 58,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: rates.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, idx) {
                          final r = rates[idx];
                          final isSelected = _detectedRate?.id == r.id;
                          return CountryRateChip(
                            rate: r,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                _dialNumberController.text = r.phonePrefix;
                                _detectedRate = r;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    loading: () => const SizedBox(height: 58),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 20),

                  // Phone Number Display with Live Rate Badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Column(
                      children: [
                        if (_detectedRate != null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_detectedRate!.flagEmoji, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(
                                '${_detectedRate!.countryName} • \$${_detectedRate!.ratePerMinute.toStringAsFixed(3)}/min (\$${_detectedRate!.ratePerSecond.toStringAsFixed(4)}/s)',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _dialNumberController.text.isEmpty
                                    ? 'Enter number (e.g. +20...)'
                                    : _dialNumberController.text,
                                style: TextStyle(
                                  color: _dialNumberController.text.isEmpty ? Colors.white30 : Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (_dialNumberController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.backspace_outlined, color: Colors.white70),
                                onPressed: _onDeletePressed,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Dialpad Keys
                  DialpadWidget(
                    onKeyPressed: _onDigitPressed,
                    onDeletePressed: _onDeletePressed,
                  ),

                  const SizedBox(height: 16),

                  // Call Initiation Button
                  GestureDetector(
                    onTap: _startCall,
                    child: Container(
                      width: 72,
                      height: 72,
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
                      child: const Icon(Icons.phone, color: Colors.white, size: 32),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                          Icon(Icons.phone_missed, color: Colors.white.withValues(alpha: 0.3), size: 54),
                          const SizedBox(height: 12),
                          const Text(
                            'No call history yet',
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Make your first pay-per-second international call!',
                            style: TextStyle(color: Colors.white38, fontSize: 13),
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
                          setState(() {
                            _dialNumberController.text = rec.destinationNumber;
                            _updateDetectedRate(rec.destinationNumber);
                            _tabController.animateTo(0);
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
              );
            },
          ),
        ],
      ),
    );
  }
}
