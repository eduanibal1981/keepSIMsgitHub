/// SIM Shield — Depletion Forecast Card (G1)
///
/// Shows when a line is predicted to run out, how that number was arrived at,
/// and offers the suggested refill schedule as a one-tap action.
///
/// Renders nothing at all when there is no forecast row yet, or when the line
/// is paused — a paused line is a user decision, not a risk to warn about.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/usage_forecast_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/usage_forecast_provider.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/line_refill_quote_provider.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart';

class DepletionForecastCard extends ConsumerWidget {
  final SimLine line;
  final bool isPremium;
  final ScheduledTopup? existingRefillSchedule;
  final int? carrierDays;

  const DepletionForecastCard({
    super.key,
    required this.line,
    required this.isPremium,
    this.existingRefillSchedule,
    this.carrierDays,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (existingRefillSchedule != null) return const SizedBox.shrink();
    if (line.lastTopupAt == null) return const SizedBox.shrink();

    final forecastAsync = ref.watch(usageForecastForLineProvider(line.id));

    return forecastAsync.maybeWhen(
      data: (forecast) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _card(context, ref, forecast),
        );
      },
      // Loading and error are silent: when lastTopupAt exists, fallback to client calculation
      orElse: () {
        if (line.lastTopupAt != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _card(context, ref, null),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, UsageForecast? f) {
    final int limitDays = carrierDays ?? f?.effectiveValidityDays ?? 90;
    final int daysSinceRecharge = line.lastTopupAt != null
        ? DateTime.now().difference(line.lastTopupAt!).inDays
        : 0;
    final int calculatedDays = limitDays - daysSinceRecharge;
    final DateTime calculatedDepletionAt =
        (line.lastTopupAt ?? DateTime.now()).add(Duration(days: limitDays));

    final int days = (f == null || f.method == 'carrier_rule' || f.daysRemaining == null)
        ? calculatedDays
        : (f.daysRemaining ?? calculatedDays);

    final DateTime depletionAt =
        (f == null || f.method == 'carrier_rule' || f.predictedDepletionAt == null)
            ? calculatedDepletionAt
            : (f.predictedDepletionAt ?? calculatedDepletionAt);

    final bool isUrgent = f?.isUrgent ?? (days <= 7);
    final Color accent = isUrgent
        ? AppColors.healthRed
        : (days <= 30 ? Colors.amberAccent : AppColors.primaryLight);

    final String headline = days <= 0
        ? 'Out of validity now'
        : days == 1
        ? 'Runs out tomorrow'
        : 'Runs out in $days days';

    final String basis = switch (f?.method) {
      'topup_history' =>
        'Based on your own refills — about every '
            '${(f!.observedIntervalDays ?? 0).round()} days across '
            '${f.samplesCount} top-ups.',
      'esim_usage' =>
        'Based on your data use — about '
            '${(f!.mbPerDay ?? 0).round()} MB a day.',
      'carrier_rule' =>
        'Estimated from this carrier\'s validity window. Refill a few times '
            'and this becomes a measurement.',
      _ =>
        'Estimated from this carrier\'s validity window. Refill a few times '
            'and this becomes a measurement.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  headline,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _confidenceChip(context, f),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Predicted ${DateFormat('EEE, MMM dd').format(depletionAt.toLocal())}',
            style: AppTextStyles.bodyMedium.copyWith(color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            basis,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.onSurfaceColor.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          if (f?.suggestedFrequencyDays != null || carrierDays != null) ...[
            const SizedBox(height: 14),
            Divider(color: context.dividerColor, height: 1),
            const SizedBox(height: 14),
            _suggestion(context, ref, f, limitDays),
          ],
        ],
      ),
    );
  }

  Widget _confidenceChip(BuildContext context, UsageForecast? f) {
    final bool measured = f?.isMeasured ?? false;
    final Color c = measured ? AppColors.success : AppColors.textSecondaryDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        measured ? 'MEASURED' : 'ESTIMATE',
        style: AppTextStyles.labelSmall.copyWith(
          color: c,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _suggestion(
    BuildContext context,
    WidgetRef ref,
    UsageForecast? f,
    int limitDays,
  ) {
    final int chip = f?.suggestedChipFor(isPremium: isPremium) ?? limitDays;
    final String freqLabel = switch (chip) {
      7 => 'weekly',
      14 => 'every 14 days',
      30 => 'monthly',
      _ => 'every $chip days',
    };

    final suggestedQuote = ref.watch(suggestedLineRefillQuoteProvider(line)).value;
    final String amount = suggestedQuote != null
        ? ' of \$${suggestedQuote.totalUsd.toStringAsFixed(2)}'
        : (f?.suggestedAmountUsd != null
            ? ' of \$${f!.suggestedAmountUsd!.toStringAsFixed(2)}'
            : '');

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suggested schedule',
                style: AppTextStyles.caption.copyWith(
                  color: context.onSurfaceColor.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'A refill$amount, $freqLabel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () async {
            await HapticHelper.lightTick();
            if (!context.mounted) return;
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => ScheduledTopupSheet(
                simLineId: line.id,
                simNickname: line.nickname ?? line.phoneNumber,
                simLine: line,
                existingSchedule: existingRefillSchedule,
                configMode: 'refill',
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            existingRefillSchedule == null ? 'Use it' : 'Adjust',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
