import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_alert_clock_state.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/sim_line_alert_clock_provider.dart';

/// The in-app Alert Clock card on the SIM line detail screen.
///
/// Implements honest deactivation countdowns based strictly on actual carrier rules
/// and verified qualifying activity. Never invents or hallucinates 48-hour alerts
/// when qualifying anchors are missing.
class AlertClockCard extends ConsumerStatefulWidget {
  final String simLineId;
  final VoidCallback? onRecordRecharge;
  final VoidCallback? onRecordUsage;

  const AlertClockCard({
    super.key,
    required this.simLineId,
    this.onRecordRecharge,
    this.onRecordUsage,
  });

  @override
  ConsumerState<AlertClockCard> createState() => _AlertClockCardState();
}

class _AlertClockCardState extends ConsumerState<AlertClockCard>
    with WidgetsBindingObserver {
  final Stopwatch _elapsedSinceFetch = Stopwatch()..start();
  DateTime? _lastEvaluation;
  Timer? _displayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _displayTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      recalculateAndRefreshAlertClock(ref, widget.simLineId);
    }
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clockAsync = ref.watch(simLineAlertClockForLineProvider(widget.simLineId));

    return clockAsync.when(
      data: (clockState) {
        if (clockState == null) {
          return _buildUnavailableCard(context);
        }
        if (_lastEvaluation != clockState.evaluatedAt) {
          _lastEvaluation = clockState.evaluatedAt;
          _elapsedSinceFetch.reset();
        }
        return _buildClockCard(context, ref, clockState);
      },
      loading: () => _buildLoadingCard(context),
      error: (_, _) => _buildUnavailableCard(context),
    );
  }

  Widget _buildUnavailableCard(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Alert Clock is temporarily unavailable. Your line details are still accessible.'),
              ),
              IconButton(
                tooltip: 'Retry Alert Clock',
                onPressed: () => ref.invalidate(
                  simLineAlertClockForLineProvider(widget.simLineId),
                ),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      );

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDarkMode ? const Color(0xFF141923) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF22D3EE)),
          ),
          const SizedBox(width: 12),
          Text(
            'Evaluating Alert Clock status...',
            style: AppTextStyles.bodySmall.copyWith(
              color: context.isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockCard(BuildContext context, WidgetRef ref, SimLineAlertClockState state) {
    final isDark = context.isDarkMode;

    if (state.isEligible) {
      return _buildEligibleClock(context, ref, state, isDark);
    } else if (state.isNeedsActivityDate) {
      return _buildNeedsActivityDate(context, ref, state, isDark);
    } else if (state.isNeedsAmount) {
      return _buildNeedsAmount(context, ref, state, isDark);
    } else if (state.isNeedsUsage) {
      return _buildNeedsUsage(context, ref, state, isDark);
    } else {
      return _buildAdvisory(context, ref, state, isDark);
    }
  }

  Widget _buildEligibleClock(
    BuildContext context,
    WidgetRef ref,
    SimLineAlertClockState state,
    bool isDark,
  ) {
    final hours = ((state.hoursRemaining ?? 0.0) -
            _elapsedSinceFetch.elapsed.inSeconds / 3600.0)
        .clamp(0.0, double.infinity);
    final isWithin48h = hours > 0 && hours <= 48;
    final days = (hours / 24.0).ceil();
    final cutoff = state.deactivationCutoffAt;
    final cutoffFormatted = cutoff != null
        ? DateFormat('MMM dd, yyyy').format(cutoff.toUtc())
        : 'Unknown';

    final Color accentColor = isWithin48h ? AppColors.healthRed : const Color(0xFF22D3EE);
    final Color bgColor = isWithin48h
        ? (isDark ? const Color(0xFF2A1215) : const Color(0xFFFFF1F2))
        : (isDark ? const Color(0xFF101C28) : const Color(0xFFF0FDF4));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: isWithin48h ? 0.6 : 0.25),
          width: isWithin48h ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWithin48h ? Icons.warning_amber_rounded : Icons.timer_outlined,
                color: accentColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                   isWithin48h ? '⚠️ Estimated 48-hour window' : 'Deactivation Alert Clock',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: 18, color: accentColor.withValues(alpha: 0.8)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Refresh Alert Clock',
                onPressed: () async {
                  await HapticHelper.lightTick();
                  await recalculateAndRefreshAlertClock(ref, widget.simLineId);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
             hours <= 0
                 ? 'Estimated cutoff reached'
                 : hours < 24
                     ? 'Less than 1 day estimated'
                     : 'About $days days remaining',
            style: AppTextStyles.headlineMedium.copyWith(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
             'Estimated carrier cutoff: $cutoffFormatted (grace period excluded)',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: accentColor.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${state.carrierName ?? 'Carrier'} · ${state.inactivityLimitDays ?? 180}d limit',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.ruleSourceUrl != null && state.ruleSourceUrl!.isNotEmpty)
                InkWell(
                  onTap: () async {
                    await HapticHelper.lightTick();
                    final uri = Uri.tryParse(state.ruleSourceUrl!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Carrier Policy',
                        style: AppTextStyles.caption.copyWith(
                          color: const Color(0xFF22D3EE),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.open_in_new, size: 12, color: Color(0xFF22D3EE)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNeedsActivityDate(
    BuildContext context,
    WidgetRef ref,
    SimLineAlertClockState state,
    bool isDark,
  ) {
    const Color warningColor = Color(0xFFF59E0B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E170E) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warningColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_busy_outlined, color: warningColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Alert Clock Inactive: Recharge Date Needed',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: warningColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: warningColor),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  await HapticHelper.lightTick();
                  await recalculateAndRefreshAlertClock(ref, widget.simLineId);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.ineligibilityReason ??
                'No qualifying recharge is recorded for this SIM. Self-report your latest recharge date to activate the countdown and the 48-hour alert.',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await HapticHelper.mediumImpact();
                widget.onRecordRecharge?.call();
              },
              icon: const Icon(Icons.edit_calendar, size: 16, color: Colors.black87),
              label: const Text(
                'Record Last Recharge Date',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: warningColor,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeedsAmount(
    BuildContext context,
    WidgetRef ref,
    SimLineAlertClockState state,
    bool isDark,
  ) {
    const Color purpleColor = Color(0xFFA855F7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1325) : const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: purpleColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.price_change_outlined, color: purpleColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Carrier Top-Up Minimum Required',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: purpleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.ineligibilityReason ??
                'This carrier requires a top-up of a specific minimum denomination to buy validity. Please confirm your top-up amount.',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await HapticHelper.mediumImpact();
                widget.onRecordRecharge?.call();
              },
              icon: const Icon(Icons.attach_money, size: 16, color: Colors.white),
              label: const Text(
                'Confirm Recharge Amount',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleColor,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeedsUsage(
    BuildContext context,
    WidgetRef ref,
    SimLineAlertClockState state,
    bool isDark,
  ) {
    const Color blueColor = Color(0xFF38BDF8);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A24) : const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: blueColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_in_talk_outlined, color: blueColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Human Usage Required',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: blueColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This carrier does not extend validity via balance recharge alone. You must place an outbound call, send an SMS, or consume cellular data to keep the line active.',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          if (widget.onRecordUsage != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await HapticHelper.mediumImpact();
                  widget.onRecordUsage?.call();
                },
                icon: const Icon(Icons.add_task, size: 16, color: blueColor),
                label: const Text('Record Recent Usage Event', style: TextStyle(color: blueColor)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: blueColor),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvisory(
    BuildContext context,
    WidgetRef ref,
    SimLineAlertClockState state,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.ineligibilityReason ?? 'Carrier policy verification in progress. Alert clock pending.',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
