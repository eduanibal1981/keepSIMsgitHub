// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'household_spend_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The owner's consolidated view: every member, cap, and month-to-date spend.

@ProviderFor(householdSpendSummary)
final householdSpendSummaryProvider = HouseholdSpendSummaryProvider._();

/// The owner's consolidated view: every member, cap, and month-to-date spend.

final class HouseholdSpendSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HouseholdSpendRow>>,
          List<HouseholdSpendRow>,
          FutureOr<List<HouseholdSpendRow>>
        >
    with
        $FutureModifier<List<HouseholdSpendRow>>,
        $FutureProvider<List<HouseholdSpendRow>> {
  /// The owner's consolidated view: every member, cap, and month-to-date spend.
  HouseholdSpendSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'householdSpendSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$householdSpendSummaryHash();

  @$internal
  @override
  $FutureProviderElement<List<HouseholdSpendRow>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<HouseholdSpendRow>> create(Ref ref) {
    return householdSpendSummary(ref);
  }
}

String _$householdSpendSummaryHash() =>
    r'014c0df177020fe80d1b0df5d5d16d6ab7df332d';

/// The member's side: which households have funded them, and the headroom left.

@ProviderFor(myHouseholdAllowances)
final myHouseholdAllowancesProvider = MyHouseholdAllowancesProvider._();

/// The member's side: which households have funded them, and the headroom left.

final class MyHouseholdAllowancesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HouseholdAllowance>>,
          List<HouseholdAllowance>,
          FutureOr<List<HouseholdAllowance>>
        >
    with
        $FutureModifier<List<HouseholdAllowance>>,
        $FutureProvider<List<HouseholdAllowance>> {
  /// The member's side: which households have funded them, and the headroom left.
  MyHouseholdAllowancesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myHouseholdAllowancesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myHouseholdAllowancesHash();

  @$internal
  @override
  $FutureProviderElement<List<HouseholdAllowance>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<HouseholdAllowance>> create(Ref ref) {
    return myHouseholdAllowances(ref);
  }
}

String _$myHouseholdAllowancesHash() =>
    r'fad4141881f7f46a49b93fb7b8fb3b58ddeb8717';

@ProviderFor(HouseholdCapController)
final householdCapControllerProvider = HouseholdCapControllerProvider._();

final class HouseholdCapControllerProvider
    extends $AsyncNotifierProvider<HouseholdCapController, void> {
  HouseholdCapControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'householdCapControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$householdCapControllerHash();

  @$internal
  @override
  HouseholdCapController create() => HouseholdCapController();
}

String _$householdCapControllerHash() =>
    r'53aaa3b447b7a22387a54e4c8631d372c85e9f9e';

abstract class _$HouseholdCapController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
