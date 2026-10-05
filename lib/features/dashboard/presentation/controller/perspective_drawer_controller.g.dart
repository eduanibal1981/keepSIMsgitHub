// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'perspective_drawer_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PerspectiveDrawerController)
final perspectiveDrawerControllerProvider =
    PerspectiveDrawerControllerProvider._();

final class PerspectiveDrawerControllerProvider
    extends $NotifierProvider<PerspectiveDrawerController, bool> {
  PerspectiveDrawerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'perspectiveDrawerControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$perspectiveDrawerControllerHash();

  @$internal
  @override
  PerspectiveDrawerController create() => PerspectiveDrawerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$perspectiveDrawerControllerHash() =>
    r'9330ae50b84dfb1e8ebb5447799365ecd6711cfb';

abstract class _$PerspectiveDrawerController extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
