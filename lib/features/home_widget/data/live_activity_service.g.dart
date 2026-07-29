// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_activity_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(liveActivityService)
final liveActivityServiceProvider = LiveActivityServiceProvider._();

final class LiveActivityServiceProvider
    extends
        $FunctionalProvider<
          LiveActivityService,
          LiveActivityService,
          LiveActivityService
        >
    with $Provider<LiveActivityService> {
  LiveActivityServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'liveActivityServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$liveActivityServiceHash();

  @$internal
  @override
  $ProviderElement<LiveActivityService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LiveActivityService create(Ref ref) {
    return liveActivityService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LiveActivityService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LiveActivityService>(value),
    );
  }
}

String _$liveActivityServiceHash() =>
    r'19ba8dee05cfe48e4e54213da2a57b79f885477a';
