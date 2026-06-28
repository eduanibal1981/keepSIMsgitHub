// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ConnectivityService)
final connectivityServiceProvider = ConnectivityServiceProvider._();

final class ConnectivityServiceProvider
    extends $NotifierProvider<ConnectivityService, NetworkStatus> {
  ConnectivityServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityServiceHash();

  @$internal
  @override
  ConnectivityService create() => ConnectivityService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkStatus>(value),
    );
  }
}

String _$connectivityServiceHash() =>
    r'761fb6617e328492c913a40bfb1e5b774b56a2d2';

abstract class _$ConnectivityService extends $Notifier<NetworkStatus> {
  NetworkStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<NetworkStatus, NetworkStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NetworkStatus, NetworkStatus>,
              NetworkStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
