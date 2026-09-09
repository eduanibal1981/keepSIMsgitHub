import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/manual_recharge_dialog.dart';

class LastRechargePanel extends StatelessWidget {
  final SimLine simLine;
  final bool isViewer;

  const LastRechargePanel({
    super.key,
    required this.simLine,
    this.isViewer = false,
  });

  String _formatDaysAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays <= 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    final months = (diff.inDays / 30).floor();
    if (months == 1) return '1 month ago';
    if (months < 12) return '$months months ago';
    final years = (diff.inDays / 365).floor();
    return years == 1 ? '1 year ago' : '$years years ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final hasRecharge = simLine.lastTopupAt != null;
    final isCarrierConfirmed = simLine.isCarrierVerified && simLine.carrierStatus == 'active';

    final Color panelColor = hasRecharge
        ? (isCarrierConfirmed ? AppColors.success : Colors.amber.shade700)
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    final String titleText = hasRecharge
        ? '${DateFormat('MMM dd, yyyy').format(simLine.lastTopupAt!.toLocal())} · ${_formatDaysAgo(simLine.lastTopupAt!.toLocal())}'
        : 'No recharge recorded';

    final String subtitleText = hasRecharge
        ? (isCarrierConfirmed ? 'Confirmed network recharge' : 'Recorded by you')
        : 'Self-report your last carrier top-up';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: panelColor.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: panelColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: panelColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasRecharge ? Icons.history_rounded : Icons.edit_calendar_rounded,
              size: 18,
              color: panelColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: panelColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'LAST RECHARGE',
                        style: AppTextStyles.caption.copyWith(
                          color: panelColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  titleText,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleText,
                  style: AppTextStyles.caption.copyWith(
                    color: context.onSurfaceColor.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!isViewer) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () async {
                await HapticHelper.lightTick();
                if (context.mounted) {
                  ManualRechargeDialog.show(
                    context: context,
                    simLine: simLine,
                  );
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 14,
                      color: context.onSurfaceColor.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Update',
                      style: AppTextStyles.caption.copyWith(
                        color: context.onSurfaceColor.withValues(alpha: 0.9),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
