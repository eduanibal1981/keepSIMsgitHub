import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/alert_alarm/controller/device_alarm_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/sim_line_alert_clock_provider.dart';
import 'manual_recharge_dialog.dart';

class AlarmClockPreferencesSheet extends ConsumerStatefulWidget {
  const AlarmClockPreferencesSheet({super.key, this.simLineId});
  final String? simLineId;

  static Future<void> show(BuildContext context, {String? simLineId}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: context.cardColor,
        builder: (_) => AlarmClockPreferencesSheet(simLineId: simLineId),
      );

  @override
  ConsumerState<AlarmClockPreferencesSheet> createState() =>
      _AlarmClockPreferencesSheetState();
}

class _AlarmClockPreferencesSheetState
    extends ConsumerState<AlarmClockPreferencesSheet> {
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(simLineAlertClockForLineProvider);
      }
    });
  }

  Future<void> _change(bool enabled) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(deviceAlarmControllerProvider.notifier)
          .setEnabled(enabled);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e
              .toString()
              .replaceFirst('StateError: ', '')
              .replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    int currentHour,
    int currentMinute,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
      helpText: 'SELECT ALARM TIME',
    );
    if (picked == null ||
        (picked.hour == currentHour && picked.minute == currentMinute)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(deviceAlarmControllerProvider.notifier)
          .setAlarmTime(picked.hour, picked.minute);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e
              .toString()
              .replaceFirst('StateError: ', '')
              .replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(deviceAlarmControllerProvider);
    final lines = ref.watch(simLinesControllerProvider);
    final alarmHour = status.value?.alarmHour ?? 18;
    final alarmMinute = status.value?.alarmMinute ?? 0;
    final timeFormatted = DateFormat.jm().format(
      DateTime(2026, 1, 1, alarmHour, alarmMinute),
    );
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.alarm_outlined, color: context.primaryColor),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Alarm Clock',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last line of defense',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'An independent device reminder for a SIM that is approaching its estimated deactivation cutoff.',
                      style: TextStyle(
                        color: context.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    status.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Could not check device alarm readiness.'),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(deviceAlarmControllerProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                      data: (s) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!s.supported)
                            const Text(
                              'Device ringing is currently supported on Android. Your existing deactivation clock and notification channels remain available on this device.',
                            )
                          else ...[
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enable on this device'),
                              value: s.enabled,
                              activeTrackColor: context.primaryColor,
                              onChanged: _saving ? null : _change,
                            ),
                            Text(
                              s.enabled
                                  ? '${s.scheduledCount} ${s.scheduledCount == 1 ? 'SIM reminder' : 'SIM reminders'} scheduled'
                                  : 'Off • Enable to schedule eligible SIM reminders',
                              style: TextStyle(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _saving
                                    ? null
                                    : () => _pickTime(
                                          context,
                                          s.alarmHour,
                                          s.alarmMinute,
                                        ),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: context.colorScheme.outlineVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        color: context.primaryColor,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Reminder time',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'Rings at this local time 48+ hours before cutoff',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: context.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: context.primaryColor
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              timeFormatted,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: context.primaryColor,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.edit_outlined,
                                              size: 14,
                                              color: context.primaryColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (!s.exactAlarmAllowed ||
                                !s.notificationsAllowed) ...[
                              const SizedBox(height: 8),
                              Text(
                                !s.exactAlarmAllowed
                                    ? 'Allow alarms and reminders to schedule the $timeFormatted alarm.'
                                    : 'Allow notifications and sound for the SIM protection alarm.',
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(
                                          deviceAlarmControllerProvider
                                              .notifier,
                                        )
                                        .openPermissionSettings();
                                  } catch (_) {
                                    if (mounted) {
                                      setState(
                                        () => _error =
                                            'Could not open device settings.',
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.settings_outlined),
                                label: const Text('Open device settings'),
                              ),
                            ],
                            if (s.timeZone.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Device time zone: ${s.timeZone}',
                                  style: TextStyle(
                                    color: context.colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          style: TextStyle(color: context.colorScheme.error),
                        ),
                      ),
                    const Divider(height: 28),
                    const Text(
                      'When it rings',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'At the latest $timeFormatted that is at least 48 hours before the estimated cutoff. If that time has already passed when you enable it, an eligible reminder is scheduled promptly instead. Each SIM cycle rings once.',
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This alarm is separate from routine quiet hours. Device permissions, alarm volume and Do Not Disturb still apply. It uses the last synchronized SIM data; open the app after a recharge outside KeepSIMs to update it.',
                      style: TextStyle(
                        color: context.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const Divider(height: 28),
                    const Text(
                      'SIM readiness',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    lines.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text(
                        'Could not load your SIMs. Please try again.',
                      ),
                      data: (all) {
                        final selected = all
                            .where(
                              (line) =>
                                  widget.simLineId == null ||
                                  line.id == widget.simLineId,
                            )
                            .toList();
                        if (selected.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Add a SIM to set up deactivation protection.',
                            ),
                          );
                        }
                        return Column(
                          children: selected
                              .map((line) => _LineReadiness(line: line))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineReadiness extends ConsumerWidget {
  const _LineReadiness({required this.line});
  final SimLine line;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = ref.watch(simLineAlertClockForLineProvider(line.id));
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.nickname ?? line.phoneNumber,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          clock.when(
            loading: () => const Text('Checking readiness…'),
            error: (_, _) => TextButton(
              onPressed: () =>
                  ref.invalidate(simLineAlertClockForLineProvider(line.id)),
              child: const Text('Retry readiness check'),
            ),
            data: (c) {
              final reason = line.protectionPaused
                  ? 'Protection paused'
                  : switch (c?.state) {
                      'eligible' =>
                        c?.deactivationCutoffAt == null
                            ? 'Estimated cutoff unavailable'
                            : 'Estimated cutoff: ${(c!.precision == 'date' ? DateFormat.yMMMd() : DateFormat.yMMMd().add_jm()).format(c.deactivationCutoffAt!.toLocal())}',
                      'needs_activity_date' => 'Last recharge date needed',
                      'needs_amount' => 'Qualifying recharge amount needed',
                      'needs_qualifying_usage' => 'Qualifying SIM usage needed',
                      'stale_rule' => 'Carrier policy needs verification',
                      'missing_rule' => 'Carrier policy unavailable',
                      'carrier_deactivated' => 'Carrier reports deactivation',
                      'inactive_line' => 'SIM is inactive',
                      _ => 'Deactivation estimate unavailable',
                    };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    reason,
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  if (!line.protectionPaused && c?.isNeedsActivityDate == true)
                    TextButton.icon(
                      onPressed: () async {
                        await ManualRechargeDialog.show(
                          context: context,
                          simLine: line,
                        );
                        ref.invalidate(
                          simLineAlertClockForLineProvider(line.id),
                        );
                      },
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('Record last recharge'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
