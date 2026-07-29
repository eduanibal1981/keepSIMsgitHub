// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'price_watch_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every watch the signed-in user has, auto-derived ones included.

@ProviderFor(priceWatches)
final priceWatchesProvider = PriceWatchesProvider._();

/// Every watch the signed-in user has, auto-derived ones included.

final class PriceWatchesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<OfferPriceWatch>>,
          List<OfferPriceWatch>,
          FutureOr<List<OfferPriceWatch>>
        >
    with
        $FutureModifier<List<OfferPriceWatch>>,
        $FutureProvider<List<OfferPriceWatch>> {
  /// Every watch the signed-in user has, auto-derived ones included.
  PriceWatchesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'priceWatchesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$priceWatchesHash();

  @$internal
  @override
  $FutureProviderElement<List<OfferPriceWatch>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<OfferPriceWatch>> create(Ref ref) {
    return priceWatches(ref);
  }
}

String _$priceWatchesHash() => r'91ba6e23ca9b7ace8cbf35851ff9f18b401ee4d4';

/// The watch covering one eSIM destination, or null when it is not watched.
/// Drives the bell toggle on the plans screen.

@ProviderFor(esimWatchForCountry)
final esimWatchForCountryProvider = EsimWatchForCountryFamily._();

/// The watch covering one eSIM destination, or null when it is not watched.
/// Drives the bell toggle on the plans screen.

final class EsimWatchForCountryProvider
    extends
        $FunctionalProvider<
          AsyncValue<OfferPriceWatch?>,
          OfferPriceWatch?,
          FutureOr<OfferPriceWatch?>
        >
    with $FutureModifier<OfferPriceWatch?>, $FutureProvider<OfferPriceWatch?> {
  /// The watch covering one eSIM destination, or null when it is not watched.
  /// Drives the bell toggle on the plans screen.
  EsimWatchForCountryProvider._({
    required EsimWatchForCountryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'esimWatchForCountryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$esimWatchForCountryHash();

  @override
  String toString() {
    return r'esimWatchForCountryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<OfferPriceWatch?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<OfferPriceWatch?> create(Ref ref) {
    final argument = this.argument as String;
    return esimWatchForCountry(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EsimWatchForCountryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$esimWatchForCountryHash() =>
    r'58c2bd6a882caf905704e5c300a5ada77d6a6710';

/// The watch covering one eSIM destination, or null when it is not watched.
/// Drives the bell toggle on the plans screen.

final class EsimWatchForCountryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<OfferPriceWatch?>, String> {
  EsimWatchForCountryFamily._()
    : super(
        retry: null,
        name: r'esimWatchForCountryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The watch covering one eSIM destination, or null when it is not watched.
  /// Drives the bell toggle on the plans screen.

  EsimWatchForCountryProvider call(String countryCode) =>
      EsimWatchForCountryProvider._(argument: countryCode, from: this);

  @override
  String toString() => r'esimWatchForCountryProvider';
}

/// Whether the user has consented to the `promo` category.
///
/// Price-drop alerts are `promo`, and `detect_offer_price_drops()` writes
/// nothing at all without an enabled row — so a watch list with promo off is
/// silent by design. The UI has to say that out loud, or the feature looks
/// broken.

@ProviderFor(promoConsent)
final promoConsentProvider = PromoConsentProvider._();

/// Whether the user has consented to the `promo` category.
///
/// Price-drop alerts are `promo`, and `detect_offer_price_drops()` writes
/// nothing at all without an enabled row — so a watch list with promo off is
/// silent by design. The UI has to say that out loud, or the feature looks
/// broken.

final class PromoConsentProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether the user has consented to the `promo` category.
  ///
  /// Price-drop alerts are `promo`, and `detect_offer_price_drops()` writes
  /// nothing at all without an enabled row — so a watch list with promo off is
  /// silent by design. The UI has to say that out loud, or the feature looks
  /// broken.
  PromoConsentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'promoConsentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$promoConsentHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return promoConsent(ref);
  }
}

String _$promoConsentHash() => r'2289ef3134610999e845283a02dc8fd41364d5de';

@ProviderFor(PriceWatchController)
final priceWatchControllerProvider = PriceWatchControllerProvider._();

final class PriceWatchControllerProvider
    extends $AsyncNotifierProvider<PriceWatchController, void> {
  PriceWatchControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'priceWatchControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$priceWatchControllerHash();

  @$internal
  @override
  PriceWatchController create() => PriceWatchController();
}

String _$priceWatchControllerHash() =>
    r'340bb6053d95d6d8e443b1e5c6cf30859bd78b23';

abstract class _$PriceWatchController extends $AsyncNotifier<void> {
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
