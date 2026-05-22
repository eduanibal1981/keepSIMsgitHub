/// SIM Shield — Scheduled Top-Up Bottom Sheet
///
/// Gorgeous dark-mode user interface allowing users to set up, edit,
/// and cancel auto top-up schedules for a given protected SIM line.
library;

import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/result.dart';
import '../../model/scheduled_topup_model.dart';
import '../../controller/scheduled_topup_controller.dart';

class ScheduledTopupSheet extends ConsumerStatefulWidget {
  final String simLineId;
  final String simNickname;
  final ScheduledTopup? existingSchedule;

  const ScheduledTopupSheet({
    super.key,
    required this.simLineId,
    required this.simNickname,
    this.existingSchedule,
  });

  @override
  ConsumerState<ScheduledTopupSheet> createState() => _ScheduledTopupSheetState();
}

class _ScheduledTopupSheetState extends ConsumerState<ScheduledTopupSheet> {
  late double _amount;
  late int _frequencyDays;
  late bool _isActive;
  bool _isSaving = false;
  bool _isDeleting = false;

  final List<double> _presetAmounts = [5.0, 10.0, 15.0, 25.0, 50.0];
  final List<int> _presetFrequencies = [7, 14, 30, 90];

  @override
  void initState() {
    super.initState();
    if (widget.existingSchedule != null) {
      _amount = widget.existingSchedule!.amount;
      _frequencyDays = widget.existingSchedule!.frequencyDays;
      _isActive = widget.existingSchedule!.isActive;
    } else {
      _amount = 10.0;
      _frequencyDays = 30;
      _isActive = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.existingSchedule != null;

    DateTime calculatedNextExecution;
    if (isEditMode && widget.existingSchedule!.frequencyDays == _frequencyDays) {
      calculatedNextExecution = widget.existingSchedule!.nextExecutionAt;
    } else {
      calculatedNextExecution = DateTime.now().add(Duration(days: _frequencyDays));
    }

    return Container(
      decoration: const BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.only(
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
      child: SingleChildScrollView(
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
                  color: context.onSurfaceColor.withOpacity(0.4).withOpacity(0.5),
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
                    color: AppColors.secondary.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.verified_user,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditMode ? 'Edit Auto-Refill' : 'Enable Auto-Refill',
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: context.onSurfaceColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.simNickname,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryLight),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Select Refill Amount Section
            Text(
              'Select Refill Amount',
              style: AppTextStyles.titleMedium.copyWith(
                color: context.onSurfaceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Presets row
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetAmounts.map((amt) {
                final isSelected = _amount == amt;
                return ChoiceChip(
                  label: Text('\$${amt.toStringAsFixed(0)} USD'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _amount = amt);
                    }
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: context.cardColor,
                  checkmarkColor: context.onSurfaceColor,
                  labelStyle: TextStyle(
                    color: isSelected ? context.onSurfaceColor : context.onSurfaceColor.withOpacity(0.6),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : context.dividerColor,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Custom Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Custom Amount:',
                  style: AppTextStyles.bodyMedium.copyWith(color: context.onSurfaceColor.withOpacity(0.6)),
                ),
                Text(
                  '\$${_amount.toStringAsFixed(2)} USD',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: context.dividerColor,
                thumbColor: AppColors.secondary,
                overlayColor: AppColors.secondary.withOpacity(0.2),
              ),
              child: Slider(
                value: _amount.clamp(5.0, 100.0),
                min: 5.0,
                max: 100.0,
                divisions: 19,
                label: '\$${_amount.toStringAsFixed(0)}',
                onChanged: (val) {
                  setState(() => _amount = val);
                },
              ),
            ),
            const SizedBox(height: 20),

            // Select Refill Frequency Section
            Text(
              'Select Refill Interval',
              style: AppTextStyles.titleMedium.copyWith(
                color: context.onSurfaceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _presetFrequencies.map((freq) {
                final isSelected = _frequencyDays == freq;
                String freqLabel = '$freq Days';
                if (freq == 30) freqLabel = 'Monthly';
                if (freq == 90) freqLabel = 'Quarterly';

                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _frequencyDays = freq),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.15) : context.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : context.dividerColor,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        freqLabel,
                        style: TextStyle(
                          color: isSelected ? context.onSurfaceColor : context.onSurfaceColor.withOpacity(0.6),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Next Execution Date estimation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.dividerColor),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_repeat_rounded,
                    color: context.onSurfaceColor.withOpacity(0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Next Execution:',
                          style: AppTextStyles.caption.copyWith(color: context.onSurfaceColor.withOpacity(0.4)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('EEEE, MMM dd, yyyy').format(calculatedNextExecution),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.onSurfaceColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit Buttons
            Row(
              children: [
                if (isEditMode) ...[
                  // Cancel / Delete schedule button
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _isDeleting || _isSaving ? null : _handleDelete,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.healthRed),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isDeleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.healthRed,
                              ),
                            )
                          : const Icon(Icons.delete_outline, color: AppColors.healthRed),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                
                // Save button
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: _isSaving || _isDeleting ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: context.onSurfaceColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                      shadowColor: AppColors.primary.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: context.onSurfaceColor,
                            ),
                          )
                        : Text(
                            isEditMode ? 'Save Configuration' : 'Enable Renewal Schedule',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      DateTime calculatedNextExecution;
      if (widget.existingSchedule != null && widget.existingSchedule!.frequencyDays == _frequencyDays) {
        calculatedNextExecution = widget.existingSchedule!.nextExecutionAt;
      } else {
        calculatedNextExecution = DateTime.now().add(Duration(days: _frequencyDays));
      }

      final schedule = ScheduledTopup(
        id: widget.existingSchedule?.id ?? '',
        simLineId: widget.simLineId,
        userId: widget.existingSchedule?.userId ?? '',
        amount: _amount,
        currency: 'USD',
        frequencyDays: _frequencyDays,
        nextExecutionAt: calculatedNextExecution,
        isActive: _isActive,
        status: widget.existingSchedule?.status ?? 'active',
      );

      final result = await ref
          .read(scheduledTopupControllerProvider.notifier)
          .saveSchedule(schedule);

      if (mounted) {
        switch (result) {
          case Success():
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Auto-Refill renewal schedule saved successfully.'),
                backgroundColor: AppColors.success,
              ),
            );
          case Failure(error: final err):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to save schedule: ${err.message}'),
                backgroundColor: AppColors.error,
              ),
            );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unknown error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDelete() async {
    if (widget.existingSchedule == null) return;
    
    setState(() => _isDeleting = true);
    try {
      final result = await ref
          .read(scheduledTopupControllerProvider.notifier)
          .removeSchedule(widget.existingSchedule!.id);

      if (mounted) {
        switch (result) {
          case Success():
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Auto-Refill renewal schedule cancelled successfully.'),
                backgroundColor: AppColors.success,
              ),
            );
          case Failure(error: final err):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete schedule: ${err.message}'),
                backgroundColor: AppColors.error,
              ),
            );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unknown error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }
}
