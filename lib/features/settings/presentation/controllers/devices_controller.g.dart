// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'devices_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DevicesController)
final devicesControllerProvider = DevicesControllerProvider._();

final class DevicesControllerProvider
    extends $AsyncNotifierProvider<DevicesController, List<RegisteredDevice>> {
  DevicesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devicesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devicesControllerHash();

  @$internal
  @override
  DevicesController create() => DevicesController();
}

String _$devicesControllerHash() => r'2546842ae4b622be08b7e2672e6ae914996907c9';

abstract class _$DevicesController
    extends $AsyncNotifier<List<RegisteredDevice>> {
  FutureOr<List<RegisteredDevice>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<RegisteredDevice>>, List<RegisteredDevice>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<RegisteredDevice>>,
                List<RegisteredDevice>
              >,
              AsyncValue<List<RegisteredDevice>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
