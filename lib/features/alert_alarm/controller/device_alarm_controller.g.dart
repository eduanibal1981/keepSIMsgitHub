// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_alarm_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DeviceAlarmController)
final deviceAlarmControllerProvider = DeviceAlarmControllerProvider._();

final class DeviceAlarmControllerProvider
    extends $AsyncNotifierProvider<DeviceAlarmController, DeviceAlarmStatus> {
  DeviceAlarmControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceAlarmControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceAlarmControllerHash();

  @$internal
  @override
  DeviceAlarmController create() => DeviceAlarmController();
}

String _$deviceAlarmControllerHash() =>
    r'26c07784fb0bc7df9b1e8b62237cb4af39815d9a';

abstract class _$DeviceAlarmController
    extends $AsyncNotifier<DeviceAlarmStatus> {
  FutureOr<DeviceAlarmStatus> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<DeviceAlarmStatus>, DeviceAlarmStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DeviceAlarmStatus>, DeviceAlarmStatus>,
              AsyncValue<DeviceAlarmStatus>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
