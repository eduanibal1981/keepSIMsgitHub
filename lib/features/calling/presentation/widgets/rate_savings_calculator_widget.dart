/// KeepSIMs — Transparent Roaming Savings Calculator Widget
library;

import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';

class RateSavingsCalculatorWidget extends StatefulWidget {
  final CallRate rate;

  const RateSavingsCalculatorWidget({super.key, required this.rate});

  static Future<void> show(BuildContext context, CallRate rate) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => RateSavingsCalculatorWidget(rate: rate),
    );
  }

  @override
  State<RateSavingsCalculatorWidget> createState() => _RateSavingsCalculatorWidgetState();
}

class _RateSavingsCalculatorWidgetState extends State<RateSavingsCalculatorWidget> {
  int _estimatedMinutes = 15;

  // Typical carrier international roaming voice call rate: $2.50/min
  static const double standardCarrierRoamingRate = 2.50;

  @override
  Widget build(BuildContext context) {
    final keepSimsRate = widget.rate.ratePerMinute;
    final carrierTotalCost = _estimatedMinutes * standardCarrierRoamingRate;
    final keepSimsTotalCost = _estimatedMinutes * keepSimsRate;
    final totalSavings = carrierTotalCost - keepSimsTotalCost;
    final savingsPercentage = ((standardCarrierRoamingRate - keepSimsRate) / standardCarrierRoamingRate * 100).clamp(0, 100);

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
                Text(widget.rate.flagEmoji, style: const TextStyle(fontSize: 26)),
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
                        'KeepSIMs: \$${keepSimsRate.toStringAsFixed(2)}/min vs Carrier Roaming: \$${standardCarrierRoamingRate.toStringAsFixed(2)}/min',
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
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
                        const Text('Carrier Roaming', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        const SizedBox(height: 6),
                        Text(
                          '\$${carrierTotalCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('for $_estimatedMinutes mins', style: const TextStyle(color: Colors.white38, fontSize: 10)),
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
                      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('KeepSIMs Voice', style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          '\$${keepSimsTotalCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Save \$${totalSavings.toStringAsFixed(2)} (${savingsPercentage.toStringAsFixed(0)}%)',
                          style: const TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold),
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
                const Text('Estimated Call Duration:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text('$_estimatedMinutes Minutes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
                  label: Text('$mins min', style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close Calculator',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
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
