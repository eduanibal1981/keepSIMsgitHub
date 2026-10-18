/// KeepSIMs — Transparent Roaming Savings Calculator Widget
library;

import 'package:flutter/material.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/domain/smart_call_cost_calculator.dart';

class RateSavingsCalculatorWidget extends StatefulWidget {
  final CallRate rate;
  final double? initialComparisonRate;

  const RateSavingsCalculatorWidget({
    super.key,
    required this.rate,
    this.initialComparisonRate = 2.50,
  });

  static Future<void> show(
    BuildContext context,
    CallRate rate, {
    double? initialComparisonRate = 2.50,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => RateSavingsCalculatorWidget(
        rate: rate,
        initialComparisonRate: initialComparisonRate,
      ),
    );
  }

  @override
  State<RateSavingsCalculatorWidget> createState() =>
      _RateSavingsCalculatorWidgetState();
}

class _RateSavingsCalculatorWidgetState
    extends State<RateSavingsCalculatorWidget> {
  int _estimatedMinutes = 15;
  late double _comparisonRate;

  @override
  void initState() {
    super.initState();
    _comparisonRate = widget.initialComparisonRate ?? 2.50;
  }

  @override
  Widget build(BuildContext context) {
    final keepSimsRate = widget.rate.ratePerMinute;
    final durationSeconds = _estimatedMinutes * 60;

    final savingsResult = SmartCallCostCalculator.calculateSavings(
      durationSeconds: durationSeconds,
      keepSimsRatePerMinute: keepSimsRate,
      comparisonRatePerMinute: _comparisonRate,
      billingIncrementSeconds: widget.rate.billingIncrementSeconds,
      connectionFee: widget.rate.connectionFee,
    );

    final carrierTotalCost = savingsResult.comparisonCost ?? 0.0;
    final keepSimsTotalCost = savingsResult.keepSimsCost;
    final totalSavings = savingsResult.savingsAmount ?? 0.0;
    final savingsPercentage = savingsResult.savingsPercentage ?? 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  widget.rate.flagEmoji,
                  style: const TextStyle(fontSize: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Roaming Savings: ${widget.rate.countryName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'KeepSIMs: \$${keepSimsRate.toStringAsFixed(2)}/min vs Carrier Roaming: \$${_comparisonRate.toStringAsFixed(2)}/min',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Comparison Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Carrier Roaming',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${carrierTotalCost.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            ApproxLocalText(
                              carrierTotalCost,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'for $_estimatedMinutes mins',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'KeepSIMs Calls',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${keepSimsTotalCost.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ApproxLocalText(
                              keepSimsTotalCost,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              savingsResult.isPositiveSavings
                                  ? 'Save \$${totalSavings.toStringAsFixed(2)} (${savingsPercentage.toStringAsFixed(0)}%)'
                                  : savingsResult.isEqualCost
                                  ? 'Equal Cost'
                                  : 'Cost: +\$${(-totalSavings).toStringAsFixed(2)}',
                              style: TextStyle(
                                color: savingsResult.isPositiveSavings
                                    ? AppColors.secondary
                                    : Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ApproxLocalText(
                              savingsResult.isPositiveSavings
                                  ? totalSavings
                                  : -totalSavings,
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
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Call Duration Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimated Call Duration:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '$_estimatedMinutes Minutes',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                thumbColor: AppColors.primary,
                inactiveTrackColor: Colors.white12,
              ),
              child: Slider(
                value: _estimatedMinutes.toDouble(),
                min: 5,
                max: 60,
                divisions: 11,
                onChanged: (val) {
                  setState(() {
                    _estimatedMinutes = val.round();
                  });
                },
              ),
            ),
            const SizedBox(height: 12),

            // Quick select chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [5, 15, 30, 60].map((mins) {
                final isSelected = _estimatedMinutes == mins;
                return ChoiceChip(
                  label: Text(
                    '$mins min',
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: const Color(0xFF1E293B),
                  onSelected: (_) {
                    setState(() {
                      _estimatedMinutes = mins;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close Calculator',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
