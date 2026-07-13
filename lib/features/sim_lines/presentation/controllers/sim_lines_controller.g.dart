// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sim_lines_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SimLinesController)
final simLinesControllerProvider = SimLinesControllerProvider._();

final class SimLinesControllerProvider
    extends $AsyncNotifierProvider<SimLinesController, List<SimLine>> {
  SimLinesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'simLinesControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$simLinesControllerHash();

  @$internal
  @override
  SimLinesController create() => SimLinesController();
}

String _$simLinesControllerHash() =>
    r'e6020f502d32a9ebb0a43b743947c7b1fb396f08';

abstract class _$SimLinesController extends $AsyncNotifier<List<SimLine>> {
  FutureOr<List<SimLine>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<SimLine>>, List<SimLine>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<SimLine>>, List<SimLine>>,
              AsyncValue<List<SimLine>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(carriersForCountry)
final carriersForCountryProvider = CarriersForCountryFamily._();

final class CarriersForCountryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Carrier>>,
          List<Carrier>,
          FutureOr<List<Carrier>>
        >
    with $FutureModifier<List<Carrier>>, $FutureProvider<List<Carrier>> {
  CarriersForCountryProvider._({
    required CarriersForCountryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'carriersForCountryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$carriersForCountryHash();

  @override
  String toString() {
    return r'carriersForCountryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Carrier>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Carrier>> create(Ref ref) {
    final argument = this.argument as String;
    return carriersForCountry(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CarriersForCountryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$carriersForCountryHash() =>
    r'5bf84b68a0160d33be2656a6dca8d70ad839bf54';

final class CarriersForCountryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Carrier>>, String> {
  CarriersForCountryFamily._()
    : super(
        retry: null,
        name: r'carriersForCountryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CarriersForCountryProvider call(String countryId) =>
      CarriersForCountryProvider._(argument: countryId, from: this);

  @override
  String toString() => r'carriersForCountryProvider';
}

@ProviderFor(carrierRule)
final carrierRuleProvider = CarrierRuleFamily._();

final class CarrierRuleProvider
    extends
        $FunctionalProvider<
          AsyncValue<CarrierRule?>,
          CarrierRule?,
          FutureOr<CarrierRule?>
        >
    with $FutureModifier<CarrierRule?>, $FutureProvider<CarrierRule?> {
  CarrierRuleProvider._({
    required CarrierRuleFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'carrierRuleProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$carrierRuleHash();

  @override
  String toString() {
    return r'carrierRuleProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CarrierRule?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CarrierRule?> create(Ref ref) {
    final argument = this.argument as String;
    return carrierRule(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CarrierRuleProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$carrierRuleHash() => r'03a87a35965d28ec5ac15ffd35bc66b7f073acf7';

final class CarrierRuleFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CarrierRule?>, String> {
  CarrierRuleFamily._()
    : super(
        retry: null,
        name: r'carrierRuleProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CarrierRuleProvider call(String carrierId) =>
      CarrierRuleProvider._(argument: carrierId, from: this);

  @override
  String toString() => r'carrierRuleProvider';
}

@ProviderFor(simLineActivityLogs)
final simLineActivityLogsProvider = SimLineActivityLogsFamily._();

final class SimLineActivityLogsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LineActivityLog>>,
          List<LineActivityLog>,
          FutureOr<List<LineActivityLog>>
        >
    with
        $FutureModifier<List<LineActivityLog>>,
        $FutureProvider<List<LineActivityLog>> {
  SimLineActivityLogsProvider._({
    required SimLineActivityLogsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'simLineActivityLogsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$simLineActivityLogsHash();

  @override
  String toString() {
    return r'simLineActivityLogsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<LineActivityLog>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LineActivityLog>> create(Ref ref) {
    final argument = this.argument as String;
    return simLineActivityLogs(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SimLineActivityLogsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$simLineActivityLogsHash() =>
    r'638c0cd7f9ed1b6c0785ff4e591784ba64c8e4a6';

final class SimLineActivityLogsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<LineActivityLog>>, String> {
  SimLineActivityLogsFamily._()
    : super(
        retry: null,
        name: r'simLineActivityLogsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SimLineActivityLogsProvider call(String simLineId) =>
      SimLineActivityLogsProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'simLineActivityLogsProvider';
}

@ProviderFor(zenditOffers)
final zenditOffersProvider = ZenditOffersFamily._();

final class ZenditOffersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          FutureOr<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  ZenditOffersProvider._({
    required ZenditOffersFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'zenditOffersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$zenditOffersHash();

  @override
  String toString() {
    return r'zenditOffersProvider'
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
    return zenditOffers(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ZenditOffersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$zenditOffersHash() => r'd67ba175ba9b50c21bc18a9778d3f94c365704a1';

final class ZenditOffersFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Map<String, dynamic>>>,
          (String, String)
        > {
  ZenditOffersFamily._()
    : super(
        retry: null,
        name: r'zenditOffersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ZenditOffersProvider call(String countryId, String carrierId) =>
      ZenditOffersProvider._(argument: (countryId, carrierId), from: this);

  @override
  String toString() => r'zenditOffersProvider';
}

@ProviderFor(paymentMethods)
final paymentMethodsProvider = PaymentMethodsProvider._();

final class PaymentMethodsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PaymentMethod>>,
          List<PaymentMethod>,
          FutureOr<List<PaymentMethod>>
        >
    with
        $FutureModifier<List<PaymentMethod>>,
        $FutureProvider<List<PaymentMethod>> {
  PaymentMethodsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentMethodsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentMethodsHash();

  @$internal
  @override
  $FutureProviderElement<List<PaymentMethod>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PaymentMethod>> create(Ref ref) {
    return paymentMethods(ref);
  }
}

String _$paymentMethodsHash() => r'55c6258299ed1e93db7fd9dd90d5577beca57d0d';

@ProviderFor(supportedCountries)
final supportedCountriesProvider = SupportedCountriesProvider._();

final class SupportedCountriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Country>>,
          List<Country>,
          FutureOr<List<Country>>
        >
    with $FutureModifier<List<Country>>, $FutureProvider<List<Country>> {
  SupportedCountriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supportedCountriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supportedCountriesHash();

  @$internal
  @override
  $FutureProviderElement<List<Country>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Country>> create(Ref ref) {
    return supportedCountries(ref);
  }
}

String _$supportedCountriesHash() =>
    r'a25db646dc2dd8068078c7fd94561b4fb26ebfdf';
