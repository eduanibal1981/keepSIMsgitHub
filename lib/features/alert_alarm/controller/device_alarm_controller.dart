import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/sim_line_alert_clock_provider.dart';
import '../contract/device_alarm_contract.dart';
import '../model/device_alarm_model.dart';
import '../repository/device_alarm_repository.dart';

part 'device_alarm_controller.g.dart';

final deviceAlarmRepositoryProvider = Provider<DeviceAlarmContract>(
  (ref) => DeviceAlarmRepository(),
);

@Riverpod(keepAlive: true)
class DeviceAlarmController extends _$DeviceAlarmController {
  static const String _prefHourKey = 'device_alarm_pref_hour';
  static const String _prefMinuteKey = 'device_alarm_pref_minute';

  @override
  Future<DeviceAlarmStatus> build() async {
    final auth = ref.watch(authControllerProvider);
    final userId = auth.value?.id;
    final repo = ref.watch(deviceAlarmRepositoryProvider);
    if (userId == null && !auth.isLoading && !auth.hasError) {
      _unwrap(await repo.clear());
      return _unwrap(await repo.status(null));
    }
    final lines = ref.watch(simLinesControllerProvider);
    final schedules = <DeviceAlarmSchedule>[];
    var complete = lines.hasValue && !lines.isLoading && !lines.hasError;
    for (final line in lines.value ?? []) {
      final clock = ref.watch(simLineAlertClockForLineProvider(line.id));
      if (clock.isLoading || clock.hasError) complete = false;
      final c = clock.value;
      if (line.protectionPaused ||
          line.userId != userId ||
          c?.userId != userId ||
          line.status != 'active' ||
          c?.isEligible != true ||
          c?.deactivationCutoffAt == null ||
          c?.alertCycleToken == null) {
        continue;
      }
      schedules.add(
        DeviceAlarmSchedule(
          simLineId: line.id,
          cycleToken: c!.alertCycleToken!,
          cutoffMillis: c.deactivationCutoffAt!.millisecondsSinceEpoch,
        ),
      );
    }
    var current = _unwrap(await repo.status(userId));
    if (userId != null && current.supported && current.enabled && complete) {
      _unwrap(await repo.synchronize(userId, schedules));
      current = _unwrap(await repo.status(userId));
    }
    if (userId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedHour = prefs.getInt('${_prefHourKey}_$userId');
        final savedMinute = prefs.getInt('${_prefMinuteKey}_$userId');
        if (savedHour != null && savedMinute != null) {
          if (current.alarmHour == 18 &&
              current.alarmMinute == 0 &&
              (savedHour != 18 || savedMinute != 0)) {
            current = current.copyWith(
              alarmHour: savedHour,
              alarmMinute: savedMinute,
            );
          }
        }
      } catch (_) {}
    }
    return current;
  }

  T _unwrap<T>(Result<T> result) => switch (result) {
    Success(data: final value) => value,
    Failure(error: final error) => throw StateError(error.message),
  };

  Future<void> setEnabled(bool enabled) async {
    final userId = ref.read(authControllerProvider).value?.id;
    if (userId == null) throw StateError('Sign in to configure your alarm.');
    _unwrap(
      await ref.read(deviceAlarmRepositoryProvider).setEnabled(userId, enabled),
    );
    ref.invalidateSelf();
  }

  Future<void> setAlarmTime(int hour, int minute) async {
    final userId = ref.read(authControllerProvider).value?.id;
    if (userId == null) throw StateError('Sign in to configure your alarm.');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${_prefHourKey}_$userId', hour);
      await prefs.setInt('${_prefMinuteKey}_$userId', minute);
    } catch (_) {}

    final result = await ref
        .read(deviceAlarmRepositoryProvider)
        .setAlarmTime(userId, hour, minute);

    if (result case Failure(error: final error)) {
      if (error.message.contains('unavailable in this app build')) {
        debugPrint(
          'Warning: Native alarm scheduler not updated in current APK build. Saved time locally.',
        );
      } else {
        throw StateError(error.message);
      }
    }
    ref.invalidateSelf();
  }

  Future<void> openPermissionSettings() async {
    _unwrap(
      await ref.read(deviceAlarmRepositoryProvider).openPermissionSettings(),
    );
  }
}
