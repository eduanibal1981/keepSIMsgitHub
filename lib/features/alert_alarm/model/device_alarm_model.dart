import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_alarm_model.freezed.dart';
part 'device_alarm_model.g.dart';

@freezed
abstract class DeviceAlarmStatus with _$DeviceAlarmStatus {
  const factory DeviceAlarmStatus({
    @Default(false) bool supported,
    @Default(false) bool enabled,
    @Default(false) bool exactAlarmAllowed,
    @Default(false) bool notificationsAllowed,
    @Default(0) int scheduledCount,
    @Default('') String timeZone,
    @Default(18) int alarmHour,
    @Default(0) int alarmMinute,
  }) = _DeviceAlarmStatus;

  factory DeviceAlarmStatus.fromJson(Map<String, dynamic> json) =>
      _$DeviceAlarmStatusFromJson(json);
}

@freezed
abstract class DeviceAlarmSchedule with _$DeviceAlarmSchedule {
  const factory DeviceAlarmSchedule({
    required String simLineId,
    required String cycleToken,
    required int cutoffMillis,
  }) = _DeviceAlarmSchedule;

  factory DeviceAlarmSchedule.fromJson(Map<String, dynamic> json) =>
      _$DeviceAlarmScheduleFromJson(json);
}
