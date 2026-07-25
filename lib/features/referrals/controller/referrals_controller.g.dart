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
    extends $AsyncNotifierProvider<ReferralsController, ReferralSummary> {
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
    r'4fde85f33cd69fceb4b9bdfc00d20a8f57c46998';

abstract class _$ReferralsController extends $AsyncNotifier<ReferralSummary> {
  FutureOr<ReferralSummary> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ReferralSummary>, ReferralSummary>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ReferralSummary>, ReferralSummary>,
              AsyncValue<ReferralSummary>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
