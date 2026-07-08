// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PrivacyController)
final privacyControllerProvider = PrivacyControllerProvider._();

final class PrivacyControllerProvider
    extends $AsyncNotifierProvider<PrivacyController, bool> {
  PrivacyControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privacyControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privacyControllerHash();

  @$internal
  @override
  PrivacyController create() => PrivacyController();
}

String _$privacyControllerHash() => r'9d0f7add8466dc05356753ba991c3de96aabafc3';

abstract class _$PrivacyController extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
