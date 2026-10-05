import 'package:keep_sims/core/result.dart';
import '../model/device_alarm_model.dart';

abstract interface class DeviceAlarmContract {
  Future<Result<DeviceAlarmStatus>> status(String? userId);
  Future<Result<void>> setEnabled(String userId, bool enabled);
  Future<Result<void>> setAlarmTime(String userId, int hour, int minute);
  Future<Result<void>> synchronize(
    String userId,
    List<DeviceAlarmSchedule> schedules,
  );
  Future<Result<void>> clear();
  Future<Result<void>> openPermissionSettings();
}
