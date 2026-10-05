import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import '../contract/device_alarm_contract.dart';
import '../model/device_alarm_model.dart';

class DeviceAlarmRepository implements DeviceAlarmContract {
  DeviceAlarmRepository({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.keep_sims/alert_alarm');
  final MethodChannel _channel;
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<Result<T>> _call<T>(
    String method,
    Map<String, dynamic>? arguments,
    T Function(dynamic) decode,
  ) async {
    try {
      return Success(
        decode(await _channel.invokeMethod<dynamic>(method, arguments)),
      );
    } on PlatformException catch (error) {
      return Failure(
        AppFailure.server(
          message: error.message ?? 'The device alarm could not be updated.',
        ),
      );
    } on MissingPluginException {
      return const Failure(
        AppFailure.server(
          message: 'Device alarms are unavailable in this app build.',
        ),
      );
    } catch (_) {
      return const Failure(
        AppFailure.unknown(message: 'The device alarm could not be updated.'),
      );
    }
  }

  @override
  Future<Result<DeviceAlarmStatus>> status(String? userId) async {
    if (!_supported) return const Success(DeviceAlarmStatus());
    return _call(
      'status',
      {'userId': userId},
      (raw) =>
          DeviceAlarmStatus.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  @override
  Future<Result<void>> setEnabled(String userId, bool enabled) =>
      _call('setEnabled', {'userId': userId, 'enabled': enabled}, (_) {});

  @override
  Future<Result<void>> setAlarmTime(String userId, int hour, int minute) =>
      _call('setAlarmTime', {
        'userId': userId,
        'hour': hour,
        'minute': minute,
      }, (_) {});

  @override
  Future<Result<void>> synchronize(
    String userId,
    List<DeviceAlarmSchedule> schedules,
  ) => _call('synchronize', {
    'userId': userId,
    'schedules': schedules.map((s) => s.toJson()).toList(),
  }, (_) {});

  @override
  Future<Result<void>> clear() async {
    if (!_supported) return const Success(null);
    return _call('clear', null, (_) {});
  }

  @override
  Future<Result<void>> openPermissionSettings() =>
      _call('openPermissionSettings', null, (_) {});
}
