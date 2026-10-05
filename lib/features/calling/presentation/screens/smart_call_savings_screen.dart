/// KeepSIMs — Smart Call Savings Screen
///
/// Full-page interactive comparison calculator matching Image 4 and Stage 5:
/// - Real account call rates
/// - Call duration slider (1-30 minutes) and quick select chips
/// - Authoritative KeepSIMs per-second cost
/// - User-entered or preset roaming rate estimate comparison
/// - Traveler savings ring and honest savings metrics
library;

import 'package:flutter/material.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/domain/smart_call_cost_calculator.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/widgets/destination_country_search_sheet.dart';

class SmartCallSavingsScreen extends ConsumerStatefulWidget {
  final String? initialCountryCode;

  const SmartCallSavingsScreen({super.key, this.initialCountryCode});

  @override
  ConsumerState<SmartCallSavingsScreen> createState() =>
      _SmartCallSavingsScreenState();
}

class _SmartCallSavingsScreenState
    extends ConsumerState<SmartCallSavingsScreen> {
  CallRate? _selectedRate;
  double _durationMinutes = 12.0;
  double? _customRoamingRate; // Null by default — no fabricated comparison
  final TextEditingController _roamingInputController = TextEditingController();

  static const List<double> _presetRoamingRates = [1.50, 2.00, 2.50, 3.00];

  @override
  void dispose() {
    _roamingInputController.dispose();
    super.dispose();
  }

  void _onPresetRateSelected(double rate) {
    HapticHelper.lightTick();
    setState(() {
      if (_customRoamingRate == rate) {
        _customRoamingRate = null;
        _roamingInputController.clear();
      } else {
        _customRoamingRate = rate;
        _roamingInputController.text = rate.toStringAsFixed(2);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ratesAsync = ref.watch(callRatesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF070E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.calling);
            }
          },
        ),
        title: const Text(
          'KeepSIMs Smart Calling',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: ratesAsync.when(
        data: (rates) {
          if (rates.isEmpty) {
            return const Center(
              child: Text(
                'No destination rates available',
                style: TextStyle(color: Colors.white60),
              ),
            );
          }

          // Initialize default rate (Oman or first available)
          _selectedRate ??=
              rates
                  .where(
                    (r) => r.countryCode == (widget.initialCountryCode ?? 'OM'),
                  )
                  .firstOrNull ??
              rates.first;

          final currentRate = _selectedRate!;
          final durationSeconds = (_durationMinutes * 60).round();

          // Calculate savings using pure calculator
          final calcResult = SmartCallCostCalculator.calculateSavings(
            durationSeconds: durationSeconds,
            keepSimsRatePerMinute: currentRate.ratePerMinute,
            comparisonRatePerMinute: _customRoamingRate,
            billingIncrementSeconds: currentRate.billingIncrementSeconds,
            connectionFee: currentRate.connectionFee,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.phone_in_talk_rounded,
                          color: Color(0xFF818CF8),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KeepSIMs Smart Call Savings',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Compare per-second international calling vs carrier roaming.',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Destination Selector Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CALL DESTINATION',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final selected =
                            await DestinationCountrySearchSheet.show(
                              context,
                              rates: rates,
                              selectedRate: _selectedRate,
                            );
                        if (selected != null) {
                          setState(() => _selectedRate = selected);
                        }
                      },
                      child: const Row(
                        children: [
                          Icon(
                            Icons.language_rounded,
                            color: Color(0xFF818CF8),
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'All Countries >',
                            style: TextStyle(
                              color: Color(0xFF818CF8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Selected Destination Card
                InkWell(
                  onTap: () async {
                    final selected = await DestinationCountrySearchSheet.show(
                      context,
                      rates: rates,
                      selectedRate: _selectedRate,
                    );
                    if (selected != null) {
                      setState(() => _selectedRate = selected);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          currentRate.flagEmoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${currentRate.countryCode}  ${currentRate.countryName} (\$${currentRate.ratePerMinute.toStringAsFixed(3)}/min)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Call Duration Slider Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CALL DURATION',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '${_durationMinutes.round()} Minutes',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF818CF8),
                    inactiveTrackColor: const Color(0xFF1E293B),
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                    overlayColor: const Color(0x33818CF8),
                  ),
                  child: Slider(
                    value: _durationMinutes,
                    min: 1.0,
                    max: 30.0,
                    divisions: 29,
                    onChanged: (val) {
                      setState(() => _durationMinutes = val);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [1, 5, 10, 15, 30].map((m) {
                      return Text(
                        '$m',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Roaming Estimate Comparison Rate Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'YOUR ROAMING ESTIMATE',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (_customRoamingRate != null)
                      Text(
                        '\$${_customRoamingRate!.toStringAsFixed(2)} / min',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ..._presetRoamingRates.map((rate) {
                      final isSelected = _customRoamingRate == rate;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('\$${rate.toStringAsFixed(2)}'),
                          selected: isSelected,
                          selectedColor: const Color(0xFF818CF8),
                          backgroundColor: const Color(0xFF0F172A),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (_) => _onPresetRateSelected(rate),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _customRoamingRate != null
                          ? const Color(0xFF818CF8).withValues(alpha: 0.5)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Carrier rate: \$',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _roamingInputController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter rate (e.g. 2.00)',
                            hintStyle: TextStyle(
                              color: Colors.white24,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final parsed = double.tryParse(
                              val.replaceAll(RegExp(r'[^0-9.]'), ''),
                            );
                            setState(() {
                              _customRoamingRate =
                                  (parsed != null && parsed > 0)
                                  ? parsed
                                  : null;
                            });
                          },
                        ),
                      ),
                      if (_customRoamingRate != null)
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white38,
                            size: 16,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _customRoamingRate = null;
                              _roamingInputController.clear();
                            });
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Comparison Cards (KeepSIMs vs Roaming)
                Row(
                  children: [
                    // KeepSIMs Cost Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFF818CF8,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF818CF8,
                                    ).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.savings_outlined,
                                    color: Color(0xFF818CF8),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'KeepSIMs Cost',
                                  style: TextStyle(
                                    color: Color(0xFF818CF8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '\$${calcResult.keepSimsCost.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ApproxLocalText(
                                  calcResult.keepSimsCost,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              currentRate.billingIncrementSeconds == 1
                                  ? 'Billed in 1-second increments.'
                                  : 'Billed in ${currentRate.billingIncrementSeconds}-second increments.',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Roaming Comparison Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14101A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.15,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.flight_outlined,
                                    color: Colors.redAccent,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Carrier Roaming',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  calcResult.comparisonCost != null
                                      ? '\$${calcResult.comparisonCost!.toStringAsFixed(2)}'
                                      : '—',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (calcResult.comparisonCost != null)
                                  ApproxLocalText(
                                    calcResult.comparisonCost!,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              calcResult.hasComparison
                                  ? 'Standard carrier roaming rates.'
                                  : 'Enter rate above to compare.',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Calculated Traveler Savings Card (with percentage ring)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.trending_up_rounded,
                          color: Color(0xFF10B981),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CALCULATED TRAVELER SAVINGS',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  calcResult.isPositiveSavings
                                      ? 'You save \$${(calcResult.savingsAmount ?? 0.0).toStringAsFixed(2)} (${(calcResult.savingsPercentage ?? 0.0).toStringAsFixed(0)}%)'
                                      : calcResult.isEqualCost
                                      ? 'Equal cost'
                                      : calcResult.hasComparison
                                      ? 'Cost difference: +\$${(-(calcResult.savingsAmount ?? 0.0)).toStringAsFixed(2)}'
                                      : 'Add a roaming rate to compare',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (calcResult.hasComparison)
                                  ApproxLocalText(
                                    (calcResult.savingsAmount ?? 0).abs(),
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Same call. Lower cost. More freedom.',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Circular percentage indicator
                      if (calcResult.isPositiveSavings)
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(
                                value:
                                    ((calcResult.savingsPercentage ?? 0.0) /
                                            100.0)
                                        .clamp(0.0, 1.0),
                                backgroundColor: const Color(0xFF1E293B),
                                color: const Color(0xFF10B981),
                                strokeWidth: 5,
                              ),
                            ),
                            Text(
                              '${(calcResult.savingsPercentage ?? 0.0).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Transparent Disclaimer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.white54, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Comparison is based on your entered roaming rate estimate. KeepSIMs calls are billed from your wallet according to destination rates and terms with no hidden surcharges.',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Text(
            'Failed to load rates: $err',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }
}
