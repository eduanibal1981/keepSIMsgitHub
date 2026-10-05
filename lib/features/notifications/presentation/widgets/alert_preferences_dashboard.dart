import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/alarm_clock_preferences_sheet.dart';
import 'package:keep_sims/features/alert_alarm/controller/device_alarm_controller.dart';
import 'package:keep_sims/features/notifications/data/models/channel_destination.dart';

/// The overview contains navigation only. Controls live in their own sheets.
class AlertPreferencesDashboard extends ConsumerStatefulWidget {
  const AlertPreferencesDashboard({
    super.key,
    required this.onChannel,
    required this.onTiming,
    required this.onAlertTypes,
  });

  final void Function(String type) onChannel;
  final void Function(bool weekly) onTiming;
  final VoidCallback onAlertTypes;

  @override
  ConsumerState<AlertPreferencesDashboard> createState() =>
      _AlertPreferencesDashboardState();
}

class _AlertPreferencesDashboardState
    extends ConsumerState<AlertPreferencesDashboard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationChannelsControllerProvider);
      ref.invalidate(notificationChannelCatalogProvider);
      ref.invalidate(userPreferencesControllerProvider);
      ref.invalidate(weeklyDigestConsentProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(notificationChannelsControllerProvider);
    final preferences = ref.watch(userPreferencesControllerProvider);
    final catalog = ref.watch(notificationChannelCatalogProvider);
    final consent = ref.watch(weeklyDigestConsentProvider);
    final alarm = ref.watch(deviceAlarmControllerProvider);
    final email = ref.watch(authControllerProvider).value?.email;
    final alarmHour = alarm.value?.alarmHour ?? 18;
    final alarmMinute = alarm.value?.alarmMinute ?? 0;
    final alarmTimeFormatted = DateFormat.jm().format(
      DateTime(2026, 1, 1, alarmHour, alarmMinute),
    );
    final enabled = (channels.value ?? [])
        .where((c) => c['is_enabled'] == true)
        .length;
    final prefs = preferences.value;
    final quiet =
        prefs?.quietHoursStart != null && prefs?.quietHoursEnd != null;
    final digest = prefs?.weeklyDigestEnabled == true && consent.value == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Text(
          'Choose how and when we notify you',
          style: TextStyle(
            color: context.colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        if (channels.hasValue)
          Text(
            '$enabled channel preferences enabled',
            style: TextStyle(
              color: context.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        const _Section('Alert channels'),
        channels.when(
          loading: () => const _Loading(),
          error: (_, _) => _LoadError(
            'Could not load channels',
            () => ref.invalidate(notificationChannelsControllerProvider),
          ),
          data: (rows) => _Group(
            children: [
              for (final type in ['push', 'email', 'whatsapp', 'telegram']) ...[
                if (type != 'push') const Divider(height: 1, indent: 56),
                Builder(
                  builder: (context) {
                    final matches = rows.where(
                      (c) => c['channel_type'] == type,
                    );
                    final row = matches.isEmpty ? null : matches.first;
                    final config = Map<String, dynamic>.from(
                      row?['config'] ?? {},
                    );
                    final state = channelOverviewState(
                      type,
                      row,
                      catalog.value?[type],
                      email,
                    );
                    final destination = channelDestination('whatsapp', config);
                    final subtitle = switch (type) {
                      'push' => 'Alerts on this device',
                      'email' => 'Critical SIM alerts by email',
                      'whatsapp' =>
                        destination.isEmpty
                            ? 'Add a destination number'
                            : 'Sends to $destination',
                      _ =>
                        config['binding_verified_at'] != null
                            ? 'Linked to your account'
                            : 'Link your account',
                    };
                    return PreferenceRow(
                      icon: switch (type) {
                        'push' => Icons.notifications_outlined,
                        'email' => Icons.mail_outline,
                        'whatsapp' => Icons.chat_bubble_outline,
                        _ => Icons.send_outlined,
                      },
                      title: switch (type) {
                        'push' => 'Push notifications',
                        'email' => 'Email alerts',
                        'whatsapp' => 'WhatsApp alerts',
                        _ => 'Telegram bot',
                      },
                      subtitle: subtitle,
                      status: state,
                      needsAttention:
                          state == 'Setup required' || state == 'Unavailable',
                      onTap: row == null ? null : () => widget.onChannel(type),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Email and WhatsApp apply to eligible Standard and Premium SIMs.',
          style: TextStyle(
            color: context.colorScheme.onSurfaceVariant,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const _Section('Last line of defense'),
        _Group(
          children: [
            PreferenceRow(
              icon: Icons.alarm_outlined,
              title: 'Alarm Clock',
              subtitle: '48+ hours before • $alarmTimeFormatted',
              status: alarm.when(
                data: (s) => !s.supported
                    ? 'Unavailable'
                    : !s.enabled
                    ? 'Off'
                    : !s.exactAlarmAllowed || !s.notificationsAllowed
                    ? 'Allow access'
                    : s.scheduledCount == 0
                    ? 'Not armed'
                    : 'Scheduled',
                loading: () => 'Checking',
                error: (_, _) => 'Retry',
              ),
              needsAttention:
                  alarm.hasError ||
                  (alarm.value?.enabled == true &&
                      alarm.value?.scheduledCount == 0),
              onTap: () => AlarmClockPreferencesSheet.show(context),
            ),
          ],
        ),
        const _Section('Quiet hours & schedule'),
        preferences.when(
          loading: () => const _Loading(),
          error: (_, _) => _LoadError(
            'Could not load schedule',
            () => ref.invalidate(userPreferencesControllerProvider),
          ),
          data: (prefs) => _Group(
            children: [
              PreferenceRow(
                icon: Icons.nights_stay_outlined,
                title: 'Quiet hours',
                subtitle: quiet
                    ? '${_time(context, prefs.quietHoursStart!)} – ${_time(context, prefs.quietHoursEnd!)}'
                    : 'Pause routine alerts',
                status: quiet ? 'On' : 'Off',
                onTap: () => widget.onTiming(false),
              ),
              const Divider(height: 1, indent: 56),
              PreferenceRow(
                icon: Icons.calendar_today_outlined,
                title: 'Weekly summary',
                subtitle: 'Sunday at 9:00 AM • Email',
                status: consent.isLoading
                    ? 'Checking'
                    : digest
                    ? 'On'
                    : prefs.weeklyDigestEnabled
                    ? 'Confirm'
                    : 'Off',
                needsAttention:
                    prefs.weeklyDigestEnabled && !digest && !consent.isLoading,
                onTap: () => widget.onTiming(true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Group(
          children: [
            PreferenceRow(
              icon: Icons.tune_outlined,
              title: 'Alert types & price watches',
              subtitle: 'Choose which events notify you',
              onTap: widget.onAlertTypes,
            ),
          ],
        ),
      ],
    );
  }

  String _time(BuildContext context, String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0,
    ).format(context);
  }
}

String channelOverviewState(
  String type,
  Map<String, dynamic>? channel,
  Map<String, dynamic>? catalog,
  String? accountEmail,
) {
  if (channel == null) return 'Not set';
  if (catalog?['is_globally_enabled'] == false) return 'Unavailable';
  if (channel['is_enabled'] != true) return 'Off';
  final config = Map<String, dynamic>.from(channel['config'] ?? {});
  final configured = switch (type) {
    'email' =>
        channelDestination('email', config, accountEmail: accountEmail).isNotEmpty,
    'whatsapp' => RegExp(
      r'^\+[1-9]\d{7,14}$',
    ).hasMatch(channelDestination('whatsapp', config)),
    'telegram' =>
      '${config['chat_id'] ?? ''}'.trim().isNotEmpty &&
          config['binding_verified_at'] != null,
    _ => true,
  };
  return configured ? 'On' : 'Setup required';
}

class PreferenceRow extends StatelessWidget {
  const PreferenceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.status,
    this.needsAttention = false,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? status;
  final bool needsAttention;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
    minTileHeight: 68,
    minLeadingWidth: 24,
    leading: Icon(icon, color: context.onSurfaceColor, size: 24),
    title: Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          height: 1.35,
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    ),
    trailing: SizedBox(
      width: 92,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (status != null)
            Expanded(
              child: Text(
                status!,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: needsAttention
                      ? (context.isDarkMode
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF92400E))
                      : status == 'On'
                      ? context.primaryColor
                      : context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    ),
    onTap: onTap,
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: context.isDarkMode
        ? context.colorScheme.surfaceContainer
        : Colors.white,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.onSurfaceColor,
      ),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError(this.message, this.retry);
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(message)),
      TextButton(onPressed: retry, child: const Text('Retry')),
    ],
  );
}
