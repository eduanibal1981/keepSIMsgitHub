// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'household_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HouseholdController)
final householdControllerProvider = HouseholdControllerProvider._();

final class HouseholdControllerProvider
    extends $AsyncNotifierProvider<HouseholdController, HouseholdState> {
  HouseholdControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'householdControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$householdControllerHash();

  @$internal
  @override
  HouseholdController create() => HouseholdController();
}

String _$householdControllerHash() =>
    r'a7a15c2794aa8c2c929adb5bafee14c07f6d0f6e';

abstract class _$HouseholdController extends $AsyncNotifier<HouseholdState> {
  FutureOr<HouseholdState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<HouseholdState>, HouseholdState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<HouseholdState>, HouseholdState>,
              AsyncValue<HouseholdState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
