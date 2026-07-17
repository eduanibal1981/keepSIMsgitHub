// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geo_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GeoController)
final geoControllerProvider = GeoControllerProvider._();

final class GeoControllerProvider
    extends $NotifierProvider<GeoController, GeoState> {
  GeoControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'geoControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$geoControllerHash();

  @$internal
  @override
  GeoController create() => GeoController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GeoState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GeoState>(value),
    );
  }
}

String _$geoControllerHash() => r'2b12e4b5f2b89c523ae624eea290d32260f59034';

abstract class _$GeoController extends $Notifier<GeoState> {
  GeoState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<GeoState, GeoState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GeoState, GeoState>,
              GeoState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
