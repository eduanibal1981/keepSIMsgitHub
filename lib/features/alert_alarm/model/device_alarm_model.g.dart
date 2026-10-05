// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_alarm_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceAlarmStatus _$DeviceAlarmStatusFromJson(Map<String, dynamic> json) =>
    _DeviceAlarmStatus(
      supported: json['supported'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? false,
      exactAlarmAllowed: json['exactAlarmAllowed'] as bool? ?? false,
      notificationsAllowed: json['notificationsAllowed'] as bool? ?? false,
      scheduledCount: (json['scheduledCount'] as num?)?.toInt() ?? 0,
      timeZone: json['timeZone'] as String? ?? '',
      alarmHour: (json['alarmHour'] as num?)?.toInt() ?? 18,
      alarmMinute: (json['alarmMinute'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$DeviceAlarmStatusToJson(_DeviceAlarmStatus instance) =>
    <String, dynamic>{
      'supported': instance.supported,
      'enabled': instance.enabled,
      'exactAlarmAllowed': instance.exactAlarmAllowed,
      'notificationsAllowed': instance.notificationsAllowed,
      'scheduledCount': instance.scheduledCount,
      'timeZone': instance.timeZone,
      'alarmHour': instance.alarmHour,
      'alarmMinute': instance.alarmMinute,
    };

_DeviceAlarmSchedule _$DeviceAlarmScheduleFromJson(Map<String, dynamic> json) =>
    _DeviceAlarmSchedule(
      simLineId: json['simLineId'] as String,
      cycleToken: json['cycleToken'] as String,
      cutoffMillis: (json['cutoffMillis'] as num).toInt(),
    );

Map<String, dynamic> _$DeviceAlarmScheduleToJson(
  _DeviceAlarmSchedule instance,
) => <String, dynamic>{
  'simLineId': instance.simLineId,
  'cycleToken': instance.cycleToken,
  'cutoffMillis': instance.cutoffMillis,
};
