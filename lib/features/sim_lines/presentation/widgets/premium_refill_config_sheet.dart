/// SIM Shield — Premium Auto-Refill Config Bottom Sheet
///
/// Beautiful sheet allowing users to view each scheduled refill execution,
/// change individual dates, reset them to default, and save changes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/scheduled_topups/model/topup_execution_model.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class PremiumRefillConfigSheet extends ConsumerStatefulWidget {
  final String simLineId;
  final String simNickname;

  const PremiumRefillConfigSheet({
    super.key,
    required this.simLineId,
    required this.simNickname,
  });

  static Future<void> show({
    required BuildContext context,
    required String simLineId,
    required String simNickname,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PremiumRefillConfigSheet(
        simLineId: simLineId,
        simNickname: simNickname,
      ),
    );
  }

  @override
  ConsumerState<PremiumRefillConfigSheet> createState() =>
      _PremiumRefillConfigSheetState();
}

class _PremiumRefillConfigSheetState
    extends ConsumerState<PremiumRefillConfigSheet> {
  Map<String, DateTime>? _editedDates;
  List<TopupExecution>? _cachedExecutions;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;
    final executionsAsync = ref.watch(topupExecutionsForLineProvider(widget.simLineId));

    final simLines = ref.watch(simLinesControllerProvider).value ?? [];
    final currentLine = simLines.cast<SimLine?>().firstWhere(
      (l) => l?.id == widget.simLineId,
      orElse: () => null,
    );

    final schedules = ref.watch(scheduledTopupControllerProvider).value ?? [];
    ScheduledTopup? schedule;
    for (final s in schedules) {
      if (s.simLineId == widget.simLineId && s.scheduleType == 'refill_mini') {
        schedule = s;
        break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border(
          top: BorderSide(color: context.dividerColor, width: 1.5),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: executionsAsync.when(
        loading: () => const SizedBox(
          height: 300,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => SizedBox(
          height: 300,
          child: Center(child: Text('Error: $err')),
        ),
        data: (executions) {
          final miniRefills = executions
              .where((e) => e.executionType == 'refill_mini' && e.status == 'pending')
              .toList()
            ..sort((a, b) => (a.executionTime ?? DateTime.now()).compareTo(b.executionTime ?? DateTime.now()));

          if (_editedDates == null) {
            _editedDates = {
              for (var exec in miniRefills) exec.id: exec.executionTime ?? DateTime.now(),
            };
            _cachedExecutions = miniRefills;
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle Bar
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.onSurfaceColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.settings_suggest_rounded,
                        color: AppColors.primaryLight,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.refillScheduleConfig,
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: context.onSurfaceColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.simNickname,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (_cachedExecutions == null || _cachedExecutions!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No executions scheduled',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  )
                else ...[
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _cachedExecutions!.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final exec = _cachedExecutions![index];
                      final currentDate = _editedDates![exec.id]!;
                      final formattedDate = DateFormat('yyyy-MM-dd').format(currentDate);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface.withValues(alpha: 0.5)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.refillExecutionNum(index + 1),
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: context.onSurfaceColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final selectedDate = await showDatePicker(
                                  context: context,
                                  initialDate: currentDate.isBefore(DateTime.now())
                                      ? DateTime.now().add(const Duration(minutes: 5))
                                      : currentDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (selectedDate != null) {
                                  setState(() {
                                    _editedDates![exec.id] = DateTime(
                                      selectedDate.year,
                                      selectedDate.month,
                                      selectedDate.day,
                                      currentDate.hour,
                                      currentDate.minute,
                                      currentDate.second,
                                    );
                                  });
                                }
                              },
                              icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                              label: Text(l10n.changeDate),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryLight,
                                side: const BorderSide(color: AppColors.primaryLight),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Bottom Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () {
                                  if (schedule == null || currentLine == null) return;
                                  final frequencyDays = schedule.frequencyDays;
                                  final nextTopupDue = currentLine.nextTopupDue;

                                  DateTime baseDate;
                                  if (nextTopupDue == null) {
                                    baseDate = DateTime.now().toUtc();
                                  } else {
                                    int bufferDays = 0;
                                    if (frequencyDays >= 85) {
                                      bufferDays = 5;
                                    } else if (frequencyDays == 30) {
                                      bufferDays = 2;
                                    } else if (frequencyDays == 14) {
                                      bufferDays = 1;
                                    }
                                    baseDate = nextTopupDue.subtract(Duration(days: bufferDays));
                                  }

                                  setState(() {
                                    for (int i = 0; i < _cachedExecutions!.length; i++) {
                                      final exec = _cachedExecutions![i];
                                      DateTime defaultDate = baseDate.add(Duration(days: i * frequencyDays));
                                      if (i == 0 && defaultDate.isBefore(DateTime.now())) {
                                        defaultDate = DateTime.now().toUtc().add(const Duration(minutes: 5));
                                      }
                                      _editedDates![exec.id] = defaultDate;
                                    }
                                  });
                                },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          child: Text(
                            l10n.resetToDefault,
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving || _cachedExecutions!.isEmpty
                              ? null
                              : () async {
                                  HapticHelper.mediumImpact();
                                  setState(() {
                                    _isSaving = true;
                                  });
                                  try {
                                    final result = await ref
                                        .read(scheduledTopupControllerProvider.notifier)
                                        .updateMiniRefillDates(widget.simLineId, _editedDates!);

                                    if (result is Success<void>) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(l10n.refillDateUpdated),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                        Navigator.of(context).pop();
                                      }
                                    } else if (result is Failure<void>) {
                                      throw Exception(result.error.message);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(l10n.failedToUpdateRefillDate(e.toString())),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isSaving = false;
                                      });
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.ok),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
