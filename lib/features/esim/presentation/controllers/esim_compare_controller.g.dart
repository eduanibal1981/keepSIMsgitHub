// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'esim_compare_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The filter set currently applied on the compare screen.
///
/// Held separately from the results so changing a filter re-runs the *query*
/// rather than rebuilding a list in memory. With 5,412 bundles the filtering
/// has to happen in SQL, so the filters are an input to the fetch, not a
/// post-processing step.

@ProviderFor(EsimCompareFilters)
final esimCompareFiltersProvider = EsimCompareFiltersProvider._();

/// The filter set currently applied on the compare screen.
///
/// Held separately from the results so changing a filter re-runs the *query*
/// rather than rebuilding a list in memory. With 5,412 bundles the filtering
/// has to happen in SQL, so the filters are an input to the fetch, not a
/// post-processing step.
final class EsimCompareFiltersProvider
    extends $NotifierProvider<EsimCompareFilters, CompareFilters> {
  /// The filter set currently applied on the compare screen.
  ///
  /// Held separately from the results so changing a filter re-runs the *query*
  /// rather than rebuilding a list in memory. With 5,412 bundles the filtering
  /// has to happen in SQL, so the filters are an input to the fetch, not a
  /// post-processing step.
  EsimCompareFiltersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'esimCompareFiltersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$esimCompareFiltersHash();

  @$internal
  @override
  EsimCompareFilters create() => EsimCompareFilters();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CompareFilters value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CompareFilters>(value),
    );
  }
}

String _$esimCompareFiltersHash() =>
    r'e32553836e23e4c8d84e407af182250c5445dd0c';

/// The filter set currently applied on the compare screen.
///
/// Held separately from the results so changing a filter re-runs the *query*
/// rather than rebuilding a list in memory. With 5,412 bundles the filtering
/// has to happen in SQL, so the filters are an input to the fetch, not a
/// post-processing step.

abstract class _$EsimCompareFilters extends $Notifier<CompareFilters> {
  CompareFilters build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CompareFilters, CompareFilters>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CompareFilters, CompareFilters>,
              CompareFilters,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The comparison results for one destination.

@ProviderFor(EsimCompare)
final esimCompareProvider = EsimCompareFamily._();

/// The comparison results for one destination.
final class EsimCompareProvider
    extends $AsyncNotifierProvider<EsimCompare, List<CompareOffer>> {
  /// The comparison results for one destination.
  EsimCompareProvider._({
    required EsimCompareFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'esimCompareProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$esimCompareHash();

  @override
  String toString() {
    return r'esimCompareProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  EsimCompare create() => EsimCompare();

  @override
  bool operator ==(Object other) {
    return other is EsimCompareProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$esimCompareHash() => r'60d13e9356cda466548472e9f10d9ba991d2ee86';

/// The comparison results for one destination.

final class EsimCompareFamily extends $Family
    with
        $ClassFamilyOverride<
          EsimCompare,
          AsyncValue<List<CompareOffer>>,
          List<CompareOffer>,
          FutureOr<List<CompareOffer>>,
          String
        > {
  EsimCompareFamily._()
    : super(
        retry: null,
        name: r'esimCompareProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The comparison results for one destination.

  EsimCompareProvider call(String countryIsoCode) =>
      EsimCompareProvider._(argument: countryIsoCode, from: this);

  @override
  String toString() => r'esimCompareProvider';
}

/// The comparison results for one destination.

abstract class _$EsimCompare extends $AsyncNotifier<List<CompareOffer>> {
  late final _$args = ref.$arg as String;
  String get countryIsoCode => _$args;

  FutureOr<List<CompareOffer>> build(String countryIsoCode);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<CompareOffer>>, List<CompareOffer>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<CompareOffer>>, List<CompareOffer>>,
              AsyncValue<List<CompareOffer>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The durations, data sizes and price floor/ceiling this destination sells.
///
/// Deliberately keyed by country and NOT watched by [EsimCompare]: the filter
/// sheet needs it to draw its choices, but the result list must not re-fetch
/// when it arrives. Keeping them separate is also why a slow bounds call can
/// never delay the offers.

@ProviderFor(esimCompareBounds)
final esimCompareBoundsProvider = EsimCompareBoundsFamily._();

/// The durations, data sizes and price floor/ceiling this destination sells.
///
/// Deliberately keyed by country and NOT watched by [EsimCompare]: the filter
/// sheet needs it to draw its choices, but the result list must not re-fetch
/// when it arrives. Keeping them separate is also why a slow bounds call can
/// never delay the offers.

final class EsimCompareBoundsProvider
    extends
        $FunctionalProvider<
          AsyncValue<CompareBounds>,
          CompareBounds,
          FutureOr<CompareBounds>
        >
    with $FutureModifier<CompareBounds>, $FutureProvider<CompareBounds> {
  /// The durations, data sizes and price floor/ceiling this destination sells.
  ///
  /// Deliberately keyed by country and NOT watched by [EsimCompare]: the filter
  /// sheet needs it to draw its choices, but the result list must not re-fetch
  /// when it arrives. Keeping them separate is also why a slow bounds call can
  /// never delay the offers.
  EsimCompareBoundsProvider._({
    required EsimCompareBoundsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'esimCompareBoundsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$esimCompareBoundsHash();

  @override
  String toString() {
    return r'esimCompareBoundsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CompareBounds> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CompareBounds> create(Ref ref) {
    final argument = this.argument as String;
    return esimCompareBounds(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EsimCompareBoundsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$esimCompareBoundsHash() => r'631c6e6a70c885b2bfbb2de6ce0c50b85f48a97e';

/// The durations, data sizes and price floor/ceiling this destination sells.
///
/// Deliberately keyed by country and NOT watched by [EsimCompare]: the filter
/// sheet needs it to draw its choices, but the result list must not re-fetch
/// when it arrives. Keeping them separate is also why a slow bounds call can
/// never delay the offers.

final class EsimCompareBoundsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CompareBounds>, String> {
  EsimCompareBoundsFamily._()
    : super(
        retry: null,
        name: r'esimCompareBoundsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The durations, data sizes and price floor/ceiling this destination sells.
  ///
  /// Deliberately keyed by country and NOT watched by [EsimCompare]: the filter
  /// sheet needs it to draw its choices, but the result list must not re-fetch
  /// when it arrives. Keeping them separate is also why a slow bounds call can
  /// never delay the offers.

  EsimCompareBoundsProvider call(String countryIsoCode) =>
      EsimCompareBoundsProvider._(argument: countryIsoCode, from: this);

  @override
  String toString() => r'esimCompareBoundsProvider';
}

/// Records an outbound partner click and hands back the tracked URL.
///
/// Returns the envelope rather than a bare String so the caller has to deal
/// with refusal. There is no fallback to an untracked partner link: sending
/// someone to a partner without attribution earns nothing and is worse than
/// not showing the offer.

@ProviderFor(affiliateClick)
final affiliateClickProvider = AffiliateClickFamily._();

/// Records an outbound partner click and hands back the tracked URL.
///
/// Returns the envelope rather than a bare String so the caller has to deal
/// with refusal. There is no fallback to an untracked partner link: sending
/// someone to a partner without attribution earns nothing and is worse than
/// not showing the offer.

final class AffiliateClickProvider
    extends
        $FunctionalProvider<
          AsyncValue<AffiliateClickResult>,
          AffiliateClickResult,
          FutureOr<AffiliateClickResult>
        >
    with
        $FutureModifier<AffiliateClickResult>,
        $FutureProvider<AffiliateClickResult> {
  /// Records an outbound partner click and hands back the tracked URL.
  ///
  /// Returns the envelope rather than a bare String so the caller has to deal
  /// with refusal. There is no fallback to an untracked partner link: sending
  /// someone to a partner without attribution earns nothing and is worse than
  /// not showing the offer.
  AffiliateClickProvider._({
    required AffiliateClickFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'affiliateClickProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$affiliateClickHash();

  @override
  String toString() {
    return r'affiliateClickProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<AffiliateClickResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AffiliateClickResult> create(Ref ref) {
    final argument = this.argument as (String, String);
    return affiliateClick(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is AffiliateClickProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$affiliateClickHash() => r'f7bf28a974c54aa6e2f653f3d6849ec3f64beb0d';

/// Records an outbound partner click and hands back the tracked URL.
///
/// Returns the envelope rather than a bare String so the caller has to deal
/// with refusal. There is no fallback to an untracked partner link: sending
/// someone to a partner without attribution earns nothing and is worse than
/// not showing the offer.

final class AffiliateClickFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<AffiliateClickResult>,
          (String, String)
        > {
  AffiliateClickFamily._()
    : super(
        retry: null,
        name: r'affiliateClickProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Records an outbound partner click and hands back the tracked URL.
  ///
  /// Returns the envelope rather than a bare String so the caller has to deal
  /// with refusal. There is no fallback to an untracked partner link: sending
  /// someone to a partner without attribution earns nothing and is worse than
  /// not showing the offer.

  AffiliateClickProvider call(String offerId, String countryCode) =>
      AffiliateClickProvider._(argument: (offerId, countryCode), from: this);

  @override
  String toString() => r'affiliateClickProvider';
}
