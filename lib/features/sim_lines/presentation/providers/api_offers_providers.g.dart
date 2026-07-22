// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_offers_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(apiOffers)
final apiOffersProvider = ApiOffersFamily._();

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

String _$apiOffersHash() => r'd6fab28df19478ca3b52a457a50b29b25085b7ad';

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

  ApiOffersProvider call(String countryId, String carrierId) =>
      ApiOffersProvider._(argument: (countryId, carrierId), from: this);

  @override
  String toString() => r'apiOffersProvider';
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

@ProviderFor(dingOffers)
final dingOffersProvider = DingOffersFamily._();

final class DingOffersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          FutureOr<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  DingOffersProvider._({
    required DingOffersFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'dingOffersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dingOffersHash();

  @override
  String toString() {
    return r'dingOffersProvider'
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
    return dingOffers(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is DingOffersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dingOffersHash() => r'86eda54bd73b13af14b6f6c1897c1f8307158373';

final class DingOffersFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Map<String, dynamic>>>,
          (String, String)
        > {
  DingOffersFamily._()
    : super(
        retry: null,
        name: r'dingOffersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DingOffersProvider call(String countryId, String carrierId) =>
      DingOffersProvider._(argument: (countryId, carrierId), from: this);

  @override
  String toString() => r'dingOffersProvider';
}

@ProviderFor(dtconnectOffers)
final dtconnectOffersProvider = DtconnectOffersFamily._();

final class DtconnectOffersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          FutureOr<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  DtconnectOffersProvider._({
    required DtconnectOffersFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'dtconnectOffersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dtconnectOffersHash();

  @override
  String toString() {
    return r'dtconnectOffersProvider'
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
    return dtconnectOffers(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is DtconnectOffersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dtconnectOffersHash() => r'0be271a699ea6741d208e6f25b702ac7b8cbee92';

final class DtconnectOffersFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Map<String, dynamic>>>,
          (String, String)
        > {
  DtconnectOffersFamily._()
    : super(
        retry: null,
        name: r'dtconnectOffersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DtconnectOffersProvider call(String countryId, String carrierId) =>
      DtconnectOffersProvider._(argument: (countryId, carrierId), from: this);

  @override
  String toString() => r'dtconnectOffersProvider';
}

@ProviderFor(reloadlyOffers)
final reloadlyOffersProvider = ReloadlyOffersFamily._();

final class ReloadlyOffersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          FutureOr<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  ReloadlyOffersProvider._({
    required ReloadlyOffersFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'reloadlyOffersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reloadlyOffersHash();

  @override
  String toString() {
    return r'reloadlyOffersProvider'
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
    return reloadlyOffers(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ReloadlyOffersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reloadlyOffersHash() => r'b7fdbbad214c89ad1f156a657d5f22b9d4e3ca7b';

final class ReloadlyOffersFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Map<String, dynamic>>>,
          (String, String)
        > {
  ReloadlyOffersFamily._()
    : super(
        retry: null,
        name: r'reloadlyOffersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReloadlyOffersProvider call(String countryId, String carrierId) =>
      ReloadlyOffersProvider._(argument: (countryId, carrierId), from: this);

  @override
  String toString() => r'reloadlyOffersProvider';
}
