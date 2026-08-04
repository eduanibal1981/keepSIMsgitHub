// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_offers_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// I1: the offers a SIM line can actually buy.
///
/// Prefer this over [apiOffers] anywhere a line id exists. [apiOffers] switches
/// on `carriers.api_provider` in Dart and so can only ever see one supplier —
/// and it saw the wrong one for DTOne, listing offers that
/// `request_instant_refill` was guaranteed to refuse. `list_refill_offers`
/// unions every enabled supplier and applies the same ranking the purchase RPC
/// re-applies, so what is listed is what can be bought.

@ProviderFor(lineRefillOffers)
final lineRefillOffersProvider = LineRefillOffersFamily._();

/// I1: the offers a SIM line can actually buy.
///
/// Prefer this over [apiOffers] anywhere a line id exists. [apiOffers] switches
/// on `carriers.api_provider` in Dart and so can only ever see one supplier —
/// and it saw the wrong one for DTOne, listing offers that
/// `request_instant_refill` was guaranteed to refuse. `list_refill_offers`
/// unions every enabled supplier and applies the same ranking the purchase RPC
/// re-applies, so what is listed is what can be bought.

final class LineRefillOffersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          FutureOr<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  /// I1: the offers a SIM line can actually buy.
  ///
  /// Prefer this over [apiOffers] anywhere a line id exists. [apiOffers] switches
  /// on `carriers.api_provider` in Dart and so can only ever see one supplier —
  /// and it saw the wrong one for DTOne, listing offers that
  /// `request_instant_refill` was guaranteed to refuse. `list_refill_offers`
  /// unions every enabled supplier and applies the same ranking the purchase RPC
  /// re-applies, so what is listed is what can be bought.
  LineRefillOffersProvider._({
    required LineRefillOffersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'lineRefillOffersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lineRefillOffersHash();

  @override
  String toString() {
    return r'lineRefillOffersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Map<String, dynamic>>> create(Ref ref) {
    final argument = this.argument as String;
    return lineRefillOffers(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LineRefillOffersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lineRefillOffersHash() => r'4dbd8e6213207bad2eec1ab7845dbfeffa9a4cd5';

/// I1: the offers a SIM line can actually buy.
///
/// Prefer this over [apiOffers] anywhere a line id exists. [apiOffers] switches
/// on `carriers.api_provider` in Dart and so can only ever see one supplier —
/// and it saw the wrong one for DTOne, listing offers that
/// `request_instant_refill` was guaranteed to refuse. `list_refill_offers`
/// unions every enabled supplier and applies the same ranking the purchase RPC
/// re-applies, so what is listed is what can be bought.

final class LineRefillOffersFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Map<String, dynamic>>>,
          String
        > {
  LineRefillOffersFamily._()
    : super(
        retry: null,
        name: r'lineRefillOffersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// I1: the offers a SIM line can actually buy.
  ///
  /// Prefer this over [apiOffers] anywhere a line id exists. [apiOffers] switches
  /// on `carriers.api_provider` in Dart and so can only ever see one supplier —
  /// and it saw the wrong one for DTOne, listing offers that
  /// `request_instant_refill` was guaranteed to refuse. `list_refill_offers`
  /// unions every enabled supplier and applies the same ranking the purchase RPC
  /// re-applies, so what is listed is what can be bought.

  LineRefillOffersProvider call(String simLineId) =>
      LineRefillOffersProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'lineRefillOffersProvider';
}

/// Country+carrier lookup for the add-line flow, which has no SIM line id yet.
/// Resolves only the carrier's default supplier — see [lineRefillOffers].

@ProviderFor(apiOffers)
final apiOffersProvider = ApiOffersFamily._();

/// Country+carrier lookup for the add-line flow, which has no SIM line id yet.
/// Resolves only the carrier's default supplier — see [lineRefillOffers].

final class ApiOffersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          FutureOr<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  /// Country+carrier lookup for the add-line flow, which has no SIM line id yet.
  /// Resolves only the carrier's default supplier — see [lineRefillOffers].
  ApiOffersProvider._({
    required ApiOffersFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'apiOffersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$apiOffersHash();

  @override
  String toString() {
    return r'apiOffersProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Map<String, dynamic>>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return apiOffers(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ApiOffersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$apiOffersHash() => r'9d1cc0e017cadd2134b4dc29cd305f8d8cafbdb6';

/// Country+carrier lookup for the add-line flow, which has no SIM line id yet.
/// Resolves only the carrier's default supplier — see [lineRefillOffers].

final class ApiOffersFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Map<String, dynamic>>>,
          (String, String)
        > {
  ApiOffersFamily._()
    : super(
        retry: null,
        name: r'apiOffersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Country+carrier lookup for the add-line flow, which has no SIM line id yet.
  /// Resolves only the carrier's default supplier — see [lineRefillOffers].

  ApiOffersProvider call(String countryId, String carrierId) =>
      ApiOffersProvider._(argument: (countryId, carrierId), from: this);

  @override
  String toString() => r'apiOffersProvider';
}

/// Offers for a country+carrier via the carrier's default supplier.
///
/// Named for what it does, not for a supplier: the underlying repository call
/// resolves the provider from `carriers.api_provider`.

@ProviderFor(offersForCarrier)
final offersForCarrierProvider = OffersForCarrierFamily._();

/// Offers for a country+carrier via the carrier's default supplier.
///
/// Named for what it does, not for a supplier: the underlying repository call
/// resolves the provider from `carriers.api_provider`.

final class OffersForCarrierProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          FutureOr<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  /// Offers for a country+carrier via the carrier's default supplier.
  ///
  /// Named for what it does, not for a supplier: the underlying repository call
  /// resolves the provider from `carriers.api_provider`.
  OffersForCarrierProvider._({
    required OffersForCarrierFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'offersForCarrierProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$offersForCarrierHash();

  @override
  String toString() {
    return r'offersForCarrierProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Map<String, dynamic>>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return offersForCarrier(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is OffersForCarrierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$offersForCarrierHash() => r'e06199749876218a4b03904c138ec039b76a2458';

/// Offers for a country+carrier via the carrier's default supplier.
///
/// Named for what it does, not for a supplier: the underlying repository call
/// resolves the provider from `carriers.api_provider`.

final class OffersForCarrierFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Map<String, dynamic>>>,
          (String, String)
        > {
  OffersForCarrierFamily._()
    : super(
        retry: null,
        name: r'offersForCarrierProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Offers for a country+carrier via the carrier's default supplier.
  ///
  /// Named for what it does, not for a supplier: the underlying repository call
  /// resolves the provider from `carriers.api_provider`.

  OffersForCarrierProvider call(String countryId, String carrierId) =>
      OffersForCarrierProvider._(argument: (countryId, carrierId), from: this);

  @override
  String toString() => r'offersForCarrierProvider';
}
