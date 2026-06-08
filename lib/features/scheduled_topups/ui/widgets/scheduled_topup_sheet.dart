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
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/profile/presentation/widgets/subscription_upsell_sheet.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/scheduled_topup_model.dart';
import '../../controller/scheduled_topup_controller.dart';

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
  final List<int> _presetFrequencies = [0, 7, 14, 30, 90];

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
    final user = ref.watch(authControllerProvider).valueOrNull;
    final globalTier = user?.subscriptionTier ?? 'standard';
    final bool isPremium = globalTier == 'premium';
    final bool isNotifyMode = widget.configMode == 'notify';
    final String labelPrefix = isNotifyMode ? 'Auto-Notify' : 'Auto-Refill';
    final String? userId = user?.id;

    DateTime calculatedNextExecution;
    if (isEditMode &&
        widget.existingSchedule!.frequencyDays == _frequencyDays) {
      calculatedNextExecution = widget.existingSchedule!.nextExecutionAt.toUtc();
    } else {
      int delayDays = _frequencyDays;
      if (_frequencyDays == 90) {
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
                      .withOpacity(0.4)
                      .withOpacity(0.5),
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
                    border: Border.all(
                      color: AppColors.secondary.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    isNotifyMode ? Icons.notifications_active_rounded : Icons.verified_user,
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
                        isEditMode ? 'Edit $labelPrefix' : 'Enable $labelPrefix',
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
                    color: context.onSurfaceColor.withOpacity(0.6),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 24,
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (isNotifyMode) ...[
              // Notification Alert Channels Section for All Users
              Text(
                'Select Notification Channels',
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ref.watch(notificationChannelsControllerProvider).when(
                data: (channels) {
                  final order = {'push': 1, 'email': 2, 'whatsapp': 3, 'telegram': 4};
                  final filtered = channels.where((c) => order.containsKey(c['channel_type'])).toList()
                    ..sort((a, b) => (order[a['channel_type']] ?? 99).compareTo(order[b['channel_type']] ?? 99));

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
                      separatorBuilder: (context, index) => Divider(color: context.dividerColor, height: 1),
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

                        final bool isLocked = type != 'push' && globalTier == 'basic';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: isLocked
                                  ? () async {
                                      await HapticHelper.mediumImpact();
                                      if (!context.mounted) return;
                                      SubscriptionUpsellSheet.show(
                                        context: context,
                                        title: '$label Locked 🔒',
                                        description: '$label alerts are Starter and Premium plan features. Upgrade your plan to unlock WhatsApp, Telegram, and Email alerts!',
                                        requiredPlan: 'Starter Plan',
                                        highlights: [
                                          'Protect up to 5 SIM lines simultaneously',
                                          'Unlock WhatsApp, Telegram & Email notifications',
                                          'Enable Travel & Home automated validity modes',
                                        ],
                                      );
                                    }
                                  : null,
                              child: SwitchListTile(
                                value: isLocked ? false : isEnabled,
                                activeThumbColor: color,
                                activeTrackColor: color.withOpacity(0.2),
                                inactiveThumbColor: AppColors.textTertiaryDark,
                                inactiveTrackColor: AppColors.darkBorder,
                                title: Row(
                                  children: [
                                    Icon(icon, color: isLocked ? AppColors.textTertiaryDark : color, size: 20),
                                    const SizedBox(width: 12),
                                    Text(
                                      label,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: isLocked ? AppColors.textSecondaryDark : context.onSurfaceColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (isLocked) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.lock_rounded,
                                        color: Colors.amberAccent,
                                        size: 14,
                                      ),
                                    ],
                                  ],
                                ),
                                onChanged: isLocked
                                    ? null
                                    : (val) async {
                                        await ref.read(notificationChannelsControllerProvider.notifier).toggleChannel(type, val);
                                      },
                              ),
                            ),
                            if (isEnabled && type != 'push' && !isLocked) ...[
                              _InlineChannelConfig(
                                channel: ch,
                                userId: userId,
                                ref: ref,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                error: (err, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
            ],

            if (!isNotifyMode && isPremium) ...[
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
                      color: isSelected
                          ? context.onSurfaceColor
                          : context.onSurfaceColor.withOpacity(0.6),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : context.dividerColor,
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
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.onSurfaceColor.withOpacity(0.6),
                    ),
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
              const SizedBox(height: 24),
            ],

            // Select Refill Frequency Section
            Text(
              isNotifyMode ? 'Select Renewal Interval' : 'Select Refill Interval',
              style: AppTextStyles.titleMedium.copyWith(
                color: context.onSurfaceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetFrequencies.map((freq) {
                final isSelected = _frequencyDays == freq;
                String freqLabel = '$freq Days';
                if (freq == 0) freqLabel = '1 Hour';
                if (freq == 30) freqLabel = 'Monthly';
                if (freq == 90) freqLabel = 'Quarterly';

                return InkWell(
                  onTap: () => setState(() => _frequencyDays = freq),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.15)
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
                            : context.onSurfaceColor.withOpacity(0.6),
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
                    color: context.onSurfaceColor.withOpacity(0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNotifyMode ? 'Estimated Next Renewal:' : 'Estimated Next Execution:',
                          style: AppTextStyles.caption.copyWith(
                            color: context.onSurfaceColor.withOpacity(0.4),
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
            const SizedBox(height: 32),

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
                      shadowColor: AppColors.primary.withOpacity(0.3),
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
                                : (isNotifyMode ? 'Enable Auto-Notify' : 'Enable Auto-Refill'),
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
      final user = ref.read(authControllerProvider).valueOrNull;
      final globalTier = user?.subscriptionTier ?? 'standard';
      final bool isPremium = globalTier == 'premium';
      final bool isNotifyMode = widget.configMode == 'notify';

      DateTime calculatedNextExecution;
      if (widget.existingSchedule != null &&
          widget.existingSchedule!.frequencyDays == _frequencyDays) {
        calculatedNextExecution = widget.existingSchedule!.nextExecutionAt.toUtc();
      } else {
        int delayDays = _frequencyDays;
        if (_frequencyDays == 90) {
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
        amount: isNotifyMode ? 0.0 : (isPremium ? _amount : 0.0),
        currency: 'USD',
        frequencyDays: _frequencyDays,
        nextExecutionAt: calculatedNextExecution,
        isActive: _isActive,
        status: widget.existingSchedule?.status ?? 'active',
        scheduleType: widget.configMode, // 'notify' or 'refill'
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

// ─────────────────────────────────────────────────────────────────────────────
// Custom Inline Config Widget for Notification Channels inside the Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _InlineChannelConfig extends StatefulWidget {
  final Map<String, dynamic> channel;
  final String? userId;
  final WidgetRef ref;

  const _InlineChannelConfig({
    required this.channel,
    required this.userId,
    required this.ref,
  });

  @override
  State<_InlineChannelConfig> createState() => _InlineChannelConfigState();
}

class _InlineChannelConfigState extends State<_InlineChannelConfig> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final config = widget.channel['config'] as Map<String, dynamic>? ?? {};
    final type = widget.channel['channel_type'] as String;
    String txt = '';
    if (type == 'email') {
      txt = config['email'] ?? '';
    } else if (type == 'whatsapp') {
      txt = config['phone'] ?? '';
    }
    _controller = TextEditingController(text: txt);
  }

  @override
  void didUpdateWidget(covariant _InlineChannelConfig oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel) {
      final config = widget.channel['config'] as Map<String, dynamic>? ?? {};
      final type = widget.channel['channel_type'] as String;
      String currentText = '';
      if (type == 'email') {
        currentText = config['email'] ?? '';
      } else if (type == 'whatsapp') {
        currentText = config['phone'] ?? '';
      }
      if (_controller.text != currentText) {
        _controller.text = currentText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final type = widget.channel['channel_type'] as String;
    final currentConfig = Map<String, dynamic>.from(widget.channel['config'] ?? {});
    
    if (type == 'email') {
      currentConfig['email'] = _controller.text.trim();
    } else if (type == 'whatsapp') {
      currentConfig['phone'] = _controller.text.trim();
    }

    await widget.ref.read(notificationChannelsControllerProvider.notifier).updateChannelConfig(type, currentConfig);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${type == 'email' ? 'Email' : 'WhatsApp'} address saved.'),
          backgroundColor: AppColors.secondary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.channel['channel_type'] as String;
    final config = widget.channel['config'] as Map<String, dynamic>? ?? {};

    if (type == 'telegram') {
      final chatId = config['chat_id'];
      final isBound = chatId != null && chatId.toString().isNotEmpty;

      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isBound ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                  color: isBound ? AppColors.success : AppColors.warning,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  isBound ? 'Status: Linked' : 'Status: Unlinked',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isBound ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Link our Telegram Bot to receive validity alerts directly.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await HapticHelper.lightTick();
                  final userId = widget.userId;
                  if (userId == null) return;
                  final botUrl = 'https://t.me/KeepSimsShieldBot?start=bind_$userId';
                  final uri = Uri.parse(botUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.telegram, color: Colors.white, size: 16),
                label: const Text(
                  'Link Telegram Bot',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22D3EE),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    String hint = type == 'email' ? 'e.g. user@domain.com' : 'e.g. +96891234567';
    IconData icon = type == 'email' ? Icons.alternate_email : Icons.phone;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _controller,
                keyboardType: type == 'email' ? TextInputType.emailAddress : TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: AppColors.textTertiaryDark, fontSize: 13),
                  prefixIcon: Icon(icon, color: AppColors.textSecondaryDark, size: 16),
                  filled: true,
                  fillColor: AppColors.darkCard,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.darkBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 40,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
