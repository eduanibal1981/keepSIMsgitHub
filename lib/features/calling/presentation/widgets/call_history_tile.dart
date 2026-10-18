/// KeepSIMs — Call History Tile
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:keep_sims/features/calling/data/models/call_record_model.dart';

class CallHistoryTile extends StatelessWidget {
  final CallRecord record;
  final VoidCallback onRedial;

  const CallHistoryTile({
    super.key,
    required this.record,
    required this.onRedial,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final timeStr = DateFormat(
      'MMM dd, hh:mm a',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(record.startedAt.toLocal());
    final isCompleted = record.status == 'completed';
    final status = isCompleted
        ? record.formattedDuration
        : switch (record.status) {
            'declined' => ar ? 'مرفوضة' : 'Declined',
            'busy' => ar ? 'مشغول' : 'Busy',
            'no_answer' => ar ? 'لم يتم الرد' : 'No answer',
            'cancelled' => ar ? 'ملغاة' : 'Cancelled',
            'failed' => ar ? 'فشلت' : 'Failed',
            'initiated' => ar ? 'جارٍ الاتصال' : 'Calling',
            'ringing' => ar ? 'جارٍ الرنين' : 'Ringing',
            'in_progress' => ar ? 'جارية' : 'In progress',
            _ => ar ? 'انتهت' : 'Ended',
          };
    final statusColor = isCompleted ? colors.primary : colors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: Text(record.flagEmoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.destinationCountryName ??
                            record.destinationNumber,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (isCompleted && record.totalCost > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '-\$${record.totalCost.toStringAsFixed(2)}',
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  record.destinationNumber,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: ar ? 'اتصل مرة أخرى' : 'Call again',
            icon: Icon(Icons.phone_forwarded, color: colors.primary, size: 20),
            onPressed: onRedial,
          ),
        ],
      ),
    );
  }
}
