// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referrals_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReferralsController)
final referralsControllerProvider = ReferralsControllerProvider._();

final class ReferralsControllerProvider
    extends $AsyncNotifierProvider<ReferralsController, ReferralsState> {
  ReferralsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'referralsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$referralsControllerHash();

  @$internal
  @override
  ReferralsController create() => ReferralsController();
}

String _$referralsControllerHash() =>
    r'6539c7488aee6e80a96e2439ddf4b7af5aea0fdb';

abstract class _$ReferralsController extends $AsyncNotifier<ReferralsState> {
  FutureOr<ReferralsState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ReferralsState>, ReferralsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ReferralsState>, ReferralsState>,
              AsyncValue<ReferralsState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
