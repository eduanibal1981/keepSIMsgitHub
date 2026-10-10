import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/alert_alarm/controller/device_alarm_controller.dart';
import 'package:keep_sims/features/notifications/presentation/widgets/notification_permission_control.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/alarm_clock_preferences_sheet.dart';

class SetupDevicePermissions extends ConsumerWidget {
  const SetupDevicePermissions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarm = ref.watch(deviceAlarmControllerProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Device permissions',
          style: TextStyle(
            color: context.onSurfaceColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        const NotificationPermissionControl(),
        const Divider(height: 32),
        const _AccessDescription(
          icon: Icons.mic_none_outlined,
          title: 'Microphone',
          description: 'Requested when you make or answer a call.',
        ),
        if (alarm?.supported == true) ...[
          const Divider(height: 32),
          const _AccessDescription(
            icon: Icons.alarm_outlined,
            title: 'SIM alarm reminders',
            description: 'Ring on this device before a SIM expires.',
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                !alarm!.enabled
                    ? 'Not enabled'
                    : alarm.exactAlarmAllowed && alarm.notificationsAllowed
                    ? 'Ready'
                    : 'Permission needed',
                style: TextStyle(
                  color: context.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('onboarding-alarm-setup'),
                onPressed: () => AlarmClockPreferencesSheet.show(context),
                icon: const Icon(Icons.alarm_add_outlined, size: 18),
                label: const Text('Set up alarms'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AccessDescription extends StatelessWidget {
  const _AccessDescription({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: context.primaryColor, size: 24),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: context.onSurfaceColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: context.colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
