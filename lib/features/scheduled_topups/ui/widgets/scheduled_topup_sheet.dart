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
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import '../../model/scheduled_topup_model.dart';
import '../../controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';

class ScheduledTopupSheet extends ConsumerStatefulWidget {
  final String simLineId;
  final String simNickname;
  final ScheduledTopup? existingSchedule;
  final String configMode; // 'notify' or 'refill'

  const ScheduledTopupSheet({
    super.key,
    required this.simLineId,
    required this.simNickname,
    this.existingSchedule,
    required this.configMode,
  });

  @override
  ConsumerState<ScheduledTopupSheet> createState() =>
      _ScheduledTopupSheetState();
}

class _ScheduledTopupSheetState extends ConsumerState<ScheduledTopupSheet> {
  late double _amount;
  late int _frequencyDays;
  late bool _isActive;
  bool _isSaving = false;
  bool _isDeleting = false;

  final List<double> _presetAmounts = [5.0, 10.0, 15.0, 25.0, 50.0];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).value;
    // Use default logic or feature-specific logic
    final globalTier = user?.subscriptionTier ?? 'standard';
    final bool isPremium = globalTier == 'premium';
    final bool isNotifyMode = widget.configMode == 'notify';

    if (widget.existingSchedule != null) {
      _amount = widget.existingSchedule!.amount;
      _frequencyDays = widget.existingSchedule!.frequencyDays;
      _isActive = widget.existingSchedule!.isActive;
    } else {
      _amount = 10.0;
      _frequencyDays = (!isNotifyMode && isPremium) ? 85 : 30;
      _isActive = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.existingSchedule != null;
    final user = ref.watch(authControllerProvider).value;
    final walletState = ref.watch(walletControllerProvider).value;
    final simLines = ref.watch(simLinesControllerProvider).value ?? [];
    final currentLine = simLines.cast<SimLine?>().firstWhere(
      (l) => l?.id == widget.simLineId,
      orElse: () => null,
    );
    // Handled by SIM line or globally
    final globalTier = user?.subscriptionTier ?? 'standard';
    final bool isPremium = globalTier == 'premium';
    final bool isNotifyMode = widget.configMode == 'notify';
    final String labelPrefix = isNotifyMode
        ? 'Auto-Notify'
        : 'Custom Auto-Refill';

    DateTime calculatedNextExecution;
    if (isEditMode &&
        widget.existingSchedule!.frequencyDays == _frequencyDays) {
      calculatedNextExecution = widget.existingSchedule!.nextExecutionAt
          .toUtc();
    } else {
      int delayDays = _frequencyDays;
      if (_frequencyDays == 90 || _frequencyDays == 85) {
        delayDays = 85;
      } else if (_frequencyDays == 30) {
        delayDays = 28;
      } else if (_frequencyDays == 14) {
        delayDays = 13;
      }
      calculatedNextExecution = DateTime.now().toUtc().add(
        _frequencyDays == 0
            ? const Duration(hours: 1)
            : Duration(days: delayDays),
      );
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
                  color: context.onSurfaceColor
                      .withValues(alpha: 0.4)
                      .withValues(alpha: 0.5),
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
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    isNotifyMode
                        ? Icons.notifications_active_rounded
                        : Icons.verified_user,
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
                        isEditMode
                            ? 'Edit $labelPrefix'
                            : 'Enable $labelPrefix',
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: context.onSurfaceColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.simNickname,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.onSurfaceColor.withValues(alpha: 0.6),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 24,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (isNotifyMode) ...[
              // Notification Alert Channels Section for All Users (Read-only overview)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Alert Delivery Status',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      await HapticHelper.lightTick();
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Dismiss bottom sheet
                        context.push(
                          '/notifications/settings',
                        ); // Route to global alert settings
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        'Configure ➜',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Alert channels are configured globally. Changes affect all protected lines.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.onSurfaceColor.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 12),
              ref
                  .watch(notificationChannelsControllerProvider)
                  .when(
                    data: (channels) {
                      final order = {
                        'push': 1,
                        'email': 2,
                        'whatsapp': 3,
                        'telegram': 4,
                      };
                      final filtered =
                          channels
                              .where(
                                (c) => order.containsKey(c['channel_type']),
                              )
                              .toList()
                            ..sort(
                              (a, b) => (order[a['channel_type']] ?? 99)
                                  .compareTo(order[b['channel_type']] ?? 99),
                            );

                      return Container(
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.dividerColor),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              Divider(color: context.dividerColor, height: 1),
                          itemBuilder: (context, index) {
                            final ch = filtered[index];
                            final type = ch['channel_type'] as String;
                            final isEnabled = ch['is_enabled'] ?? false;

                            String label = '';
                            IconData icon = Icons.notifications;
                            Color color = AppColors.primary;
                            switch (type) {
                              case 'push':
                                label = 'Push Notifications';
                                icon = Icons.notifications_active_rounded;
                                color = AppColors.primaryLight;
                                break;
                              case 'whatsapp':
                                label = 'WhatsApp Alerts';
                                icon = Icons.chat_bubble_outline_rounded;
                                color = const Color(0xFF4ADE80);
                                break;
                              case 'telegram':
                                label = 'Telegram Bot';
                                icon = Icons.telegram_rounded;
                                color = const Color(0xFF22D3EE);
                                break;
                              case 'email':
                                label = 'Email Alerts';
                                icon = Icons.email_rounded;
                                color = const Color(0xFF38BDF8);
                                break;
                            }

                            final bool isLineBasic =
                                currentLine?.protectionTier.toLowerCase() ==
                                'basic';
                            final bool isUnavailable =
                                type != 'push' && isLineBasic;
                            final bool isLocked =
                                type != 'push' && globalTier == 'basic';

                            return ListTile(
                              dense: true,
                              leading: Icon(
                                icon,
                                color: (isUnavailable || isLocked)
                                    ? AppColors.textTertiaryDark
                                    : color,
                                size: 20,
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    label,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: (isUnavailable || isLocked)
                                          ? AppColors.textSecondaryDark
                                          : context.onSurfaceColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isLocked && !isUnavailable) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.lock_rounded,
                                      color: Colors.amberAccent,
                                      size: 14,
                                    ),
                                  ],
                                ],
                              ),
                              trailing: isUnavailable
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.healthRed.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.healthRed
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        'Upgrade',
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                              color: AppColors.healthRed,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                      ),
                                    )
                                  : isLocked
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amberAccent.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.amberAccent.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'LOCKED',
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                              color: Colors.amberAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                      ),
                                    )
                                  : isEnabled
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.success.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'ACTIVE',
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                              color: AppColors.success,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.onSurfaceColor
                                            .withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: context.onSurfaceColor
                                              .withValues(alpha: 0.1),
                                        ),
                                      ),
                                      child: Text(
                                        'OFF',
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                              color: context.onSurfaceColor
                                                  .withValues(alpha: 0.4),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                      ),
                                    ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    error: (err, _) => const SizedBox.shrink(),
                  ),
              const SizedBox(height: 24),
            ],
            if (!isNotifyMode) ...[
              Text(
                'Select Refill Amount',
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presetAmounts.map((amount) {
                  final isSelected = _amount == amount;
                  return InkWell(
                    onTap: () => setState(() => _amount = amount),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : context.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : context.dividerColor,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '\$${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: isSelected
                              ? context.onSurfaceColor
                              : context.onSurfaceColor.withValues(alpha: 0.6),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Select Interval Section
            Text(
              isNotifyMode
                  ? 'Select Renewal Interval'
                  : 'Select Refill Interval',
              style: AppTextStyles.titleMedium.copyWith(
                color: context.onSurfaceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: (isPremium ? [0, 7, 14, 30, 85] : [0, 7, 14, 30, 90])
                  .map((freq) {
                    final isSelected = _frequencyDays == freq;
                    String freqLabel = '$freq Days';
                    if (freq == 0) freqLabel = '1 Hour';
                    if (freq == 30) freqLabel = 'Monthly';
                    if (freq == 90 || freq == 85) {
                      freqLabel = freq == 85 ? 'Every 85 Days' : 'Quarterly';
                    }

                    return InkWell(
                      onTap: () => setState(() => _frequencyDays = freq),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : context.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : context.dividerColor,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          freqLabel,
                          style: TextStyle(
                            color: isSelected
                                ? context.onSurfaceColor
                                : context.onSurfaceColor.withValues(alpha: 0.6),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(),
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
                  Icon(
                    Icons.event_repeat_rounded,
                    color: context.onSurfaceColor.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNotifyMode
                              ? 'Estimated Next Renewal:'
                              : 'Estimated Next Execution:',
                          style: AppTextStyles.caption.copyWith(
                            color: context.onSurfaceColor.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat(
                            'EEEE, MMM dd, yyyy',
                          ).format(calculatedNextExecution.toLocal()),
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
            if (!isNotifyMode && walletState != null && _amount > 0) ...[
              Builder(builder: (context) {
                final balance = walletState.wallet.balance;
                final possibleRefills = (balance / _amount).floor();
                if (possibleRefills > 1) return const SizedBox(height: 32);

                return Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 32.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amberAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            possibleRefills == 1
                                ? 'Your wallet balance (\$$balance) covers only 1 refill. Remember to top up later!'
                                : 'Your wallet balance (\$$balance) is not enough for this refill amount.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.amber.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ] else ...[
              const SizedBox(height: 32),
            ],

            // Submit Buttons
            Row(
              children: [
                if (isEditMode) ...[
                  // Cancel / Delete schedule button
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _isDeleting || _isSaving
                          ? null
                          : _handleDelete,
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
                          : const Icon(
                              Icons.delete_outline,
                              color: AppColors.healthRed,
                            ),
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
                      shadowColor: AppColors.primary.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: context.onSurfaceColor,
                            ),
                          )
                        : Text(
                            isEditMode
                                ? 'Save Configuration'
                                : (isNotifyMode
                                      ? 'Enable Auto-Notify'
                                      : 'Enable Auto-Refill'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
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
      final user = ref.read(authControllerProvider).value;
      final bool isNotifyMode = widget.configMode == 'notify';

      if (!isNotifyMode) {
        final walletState = ref.read(walletControllerProvider).value;
        if (walletState != null && walletState.wallet.balance < _amount) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Insufficient wallet balance. Please add funds first.'),
                backgroundColor: AppColors.error,
              ),
            );
            setState(() => _isSaving = false);
          }
          return;
        }
      }

      DateTime calculatedNextExecution;
      if (widget.existingSchedule != null &&
          widget.existingSchedule!.frequencyDays == _frequencyDays) {
        calculatedNextExecution = widget.existingSchedule!.nextExecutionAt
            .toUtc();
      } else {
        int delayDays = _frequencyDays;
        if (_frequencyDays == 90 || _frequencyDays == 85) {
          delayDays = 85;
        } else if (_frequencyDays == 30) {
          delayDays = 28;
        } else if (_frequencyDays == 14) {
          delayDays = 13;
        }
        calculatedNextExecution = DateTime.now().toUtc().add(
          _frequencyDays == 0
              ? const Duration(hours: 1)
              : Duration(days: delayDays),
        );
      }

      final schedule = ScheduledTopup(
        id: widget.existingSchedule?.id ?? '',
        simLineId: widget.simLineId,
        userId: widget.existingSchedule?.userId ?? user?.id ?? '',
        amount: isNotifyMode ? 0.0 : _amount,
        currency: 'USD',
        frequencyDays: _frequencyDays,
        nextExecutionAt: calculatedNextExecution,
        isActive: _isActive,
        status: widget.existingSchedule?.status ?? 'active',
        scheduleType: widget.configMode == 'refill'
            ? 'refill_custom'
            : widget.configMode,
      );

      final result = await ref
          .read(scheduledTopupControllerProvider.notifier)
          .saveSchedule(schedule);

      if (mounted) {
        switch (result) {
          case Success():
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isNotifyMode
                      ? 'Auto-Notify configuration saved successfully.'
                      : 'Auto-Refill configuration saved successfully.',
                ),
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
      final isNotifyMode = widget.configMode == 'notify';

      // Since they are now two completely separate database records,
      // deleting either Auto-Notify or Auto-Refill simply removes its specific record completely!
      final result = await ref
          .read(scheduledTopupControllerProvider.notifier)
          .removeSchedule(widget.existingSchedule!.id);

      if (mounted) {
        switch (result) {
          case Success():
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isNotifyMode
                      ? 'Auto-Notify configuration cancelled successfully.'
                      : 'Auto-Refill configuration cancelled successfully.',
                ),
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
