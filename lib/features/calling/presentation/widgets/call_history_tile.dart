/// KeepSIMs — Call History Tile
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
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
    final timeStr = DateFormat('MMM dd, hh:mm a').format(record.startedAt);
    final isCompleted = record.status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isCompleted ? AppColors.secondary : AppColors.error)
                  .withValues(alpha: 0.15),
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
                    Text(
                      record.destinationCountryName ?? record.destinationNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (isCompleted && record.totalCost > 0)
                      Text(
                        '-\$${record.totalCost.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      record.destinationNumber,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Text('•', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
                    const SizedBox(width: 8),
                    Text(
                      isCompleted ? record.formattedDuration : record.status,
                      style: TextStyle(
                        color: isCompleted ? AppColors.secondary : AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.phone_forwarded, color: AppColors.primary, size: 20),
            onPressed: onRedial,
          ),
        ],
      ),
    );
  }
}
