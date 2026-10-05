import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/alert_alarm/contract/device_alarm_contract.dart';
import 'package:keep_sims/features/alert_alarm/controller/device_alarm_controller.dart';
import 'package:keep_sims/features/alert_alarm/model/device_alarm_model.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_alert_clock_state.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/sim_line_alert_clock_provider.dart';

void main() {
  final cutoff = DateTime.utc(2027, 1, 10, 14);
  const lines = [
    SimLine(
      id: 'ready',
      userId: 'owner',
      phoneNumber: '+96891111111',
      status: 'active',
    ),
    SimLine(
      id: 'paused',
      userId: 'owner',
      phoneNumber: '+96892222222',
      status: 'active',
      protectionPaused: true,
    ),
    SimLine(
      id: 'date',
      userId: 'owner',
      phoneNumber: '+96893333333',
      status: 'active',
    ),
    SimLine(
      id: 'inactive',
      userId: 'owner',
      phoneNumber: '+96894444444',
      status: 'inactive',
    ),
  ];
  final clocks = {
    for (final line in lines)
      line.id: SimLineAlertClockState(
        simLineId: line.id,
        userId: 'owner',
        state: line.id == 'date' ? 'needs_activity_date' : 'eligible',
        deactivationCutoffAt: cutoff,
        alertCycleToken: 'cycle-${line.id}',
      ),
  };

  Future<ProviderContainer> prepare(
    _Repo repo, {
    bool signedIn = true,
    bool clocksFail = false,
    bool foreignClock = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => _Auth(signedIn)),
        simLinesControllerProvider.overrideWith(() => _Lines(lines)),
        deviceAlarmRepositoryProvider.overrideWithValue(repo),
        simLineAlertClockForLineProvider.overrideWith((ref, id) async {
          if (clocksFail) throw StateError('Offline');
          if (foreignClock) {
            return SimLineAlertClockState(
              simLineId: id,
              userId: 'another-owner',
              state: 'eligible',
              deactivationCutoffAt: cutoff,
              alertCycleToken: 'foreign-cycle',
            );
          }
          return clocks[id];
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    await container.read(simLinesControllerProvider.future);
    for (final line in lines) {
      try {
        await container.read(simLineAlertClockForLineProvider(line.id).future);
      } catch (_) {}
    }
    return container;
  }

  test('only active eligible unpaused SIMs arm device reminders', () async {
    final repo = _Repo();
    final container = await prepare(repo);
    await container.read(deviceAlarmControllerProvider.future);
    expect(repo.synced.map((s) => s.simLineId), ['ready']);
    expect(repo.synced.single.cutoffMillis, cutoff.millisecondsSinceEpoch);
    expect(repo.owner, 'owner');
  });
  test('disabled device preference does not schedule alarms', () async {
    final repo = _Repo()..enabled = false;
    final container = await prepare(repo);
    await container.read(deviceAlarmControllerProvider.future);
    expect(repo.syncs, 0);
  });
  test('a cached clock from another account cannot arm a reminder', () async {
    final repo = _Repo();
    final container = await prepare(repo, foreignClock: true);
    await container.read(deviceAlarmControllerProvider.future);
    expect(repo.synced, isEmpty);
  });
  test(
    'failed readiness fetch preserves existing alarms rather than erasing them',
    () async {
      final repo = _Repo();
      final container = await prepare(repo, clocksFail: true);
      await container.read(deviceAlarmControllerProvider.future);
      expect(repo.syncs, 0);
      expect(repo.clears, 0);
    },
  );
  test('logout clears device schedules and opt-in', () async {
    final repo = _Repo();
    final container = await prepare(repo, signedIn: false);
    await container.read(deviceAlarmControllerProvider.future);
    expect(repo.clears, 1);
    expect(repo.enabled, isFalse);
  });

  test('setting alarm time updates repository and reflects in controller', () async {
    final repo = _Repo();
    final container = await prepare(repo);
    await container.read(deviceAlarmControllerProvider.future);
    expect(container.read(deviceAlarmControllerProvider).value?.alarmHour, 18);
    expect(container.read(deviceAlarmControllerProvider).value?.alarmMinute, 0);

    await container
        .read(deviceAlarmControllerProvider.notifier)
        .setAlarmTime(9, 30);

    final updated = await container.read(deviceAlarmControllerProvider.future);
    expect(repo.alarmHour, 9);
    expect(repo.alarmMinute, 30);
    expect(updated.alarmHour, 9);
    expect(updated.alarmMinute, 30);
  });
}

class _Repo implements DeviceAlarmContract {
  bool enabled = true;
  int syncs = 0;
  int clears = 0;
  int alarmHour = 18;
  int alarmMinute = 0;
  String? owner;
  List<DeviceAlarmSchedule> synced = [];
  @override
  Future<Result<DeviceAlarmStatus>> status(String? userId) async => Success(
    DeviceAlarmStatus(
      supported: true,
      enabled: enabled,
      exactAlarmAllowed: true,
      notificationsAllowed: true,
      scheduledCount: synced.length,
      alarmHour: alarmHour,
      alarmMinute: alarmMinute,
    ),
  );
  @override
  Future<Result<void>> synchronize(
    String userId,
    List<DeviceAlarmSchedule> schedules,
  ) async {
    syncs++;
    owner = userId;
    synced = schedules;
    return const Success(null);
  }

  @override
  Future<Result<void>> clear() async {
    clears++;
    enabled = false;
    return const Success(null);
  }

  @override
  Future<Result<void>> setEnabled(String userId, bool enabled) async {
    this.enabled = enabled;
    return const Success(null);
  }

  @override
  Future<Result<void>> setAlarmTime(String userId, int hour, int minute) async {
    alarmHour = hour;
    alarmMinute = minute;
    return const Success(null);
  }

  @override
  Future<Result<void>> openPermissionSettings() async => const Success(null);
}

class _Auth extends AuthController {
  _Auth(this.signedIn);
  final bool signedIn;
  @override
  FutureOr<UserProfile?> build() =>
      signedIn ? const UserProfile(id: 'owner') : null;
}

class _Lines extends SimLinesController {
  _Lines(this.lines);
  final List<SimLine> lines;
  @override
  FutureOr<List<SimLine>> build() => lines;
}
