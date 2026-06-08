// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sim_lines_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$supportedCountriesHash() =>
    r'70bfcd26d8c531ed5804bd12b519011c6f929ac1';

/// See also [supportedCountries].
@ProviderFor(supportedCountries)
final supportedCountriesProvider =
    AutoDisposeFutureProvider<List<Country>>.internal(
      supportedCountries,
      name: r'supportedCountriesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$supportedCountriesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SupportedCountriesRef = AutoDisposeFutureProviderRef<List<Country>>;
String _$carriersForCountryHash() =>
    r'b8dbcc9128fc84e8e1874a37162a1104399a8e92';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [carriersForCountry].
@ProviderFor(carriersForCountry)
const carriersForCountryProvider = CarriersForCountryFamily();

/// See also [carriersForCountry].
class CarriersForCountryFamily extends Family<AsyncValue<List<Carrier>>> {
  /// See also [carriersForCountry].
  const CarriersForCountryFamily();

  /// See also [carriersForCountry].
  CarriersForCountryProvider call(String countryId) {
    return CarriersForCountryProvider(countryId);
  }

  @override
  CarriersForCountryProvider getProviderOverride(
    covariant CarriersForCountryProvider provider,
  ) {
    return call(provider.countryId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'carriersForCountryProvider';
}

/// See also [carriersForCountry].
class CarriersForCountryProvider
    extends AutoDisposeFutureProvider<List<Carrier>> {
  /// See also [carriersForCountry].
  CarriersForCountryProvider(String countryId)
    : this._internal(
        (ref) => carriersForCountry(ref as CarriersForCountryRef, countryId),
        from: carriersForCountryProvider,
        name: r'carriersForCountryProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$carriersForCountryHash,
        dependencies: CarriersForCountryFamily._dependencies,
        allTransitiveDependencies:
            CarriersForCountryFamily._allTransitiveDependencies,
        countryId: countryId,
      );

  CarriersForCountryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.countryId,
  }) : super.internal();

  final String countryId;

  @override
  Override overrideWith(
    FutureOr<List<Carrier>> Function(CarriersForCountryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CarriersForCountryProvider._internal(
        (ref) => create(ref as CarriersForCountryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        countryId: countryId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Carrier>> createElement() {
    return _CarriersForCountryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CarriersForCountryProvider && other.countryId == countryId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, countryId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CarriersForCountryRef on AutoDisposeFutureProviderRef<List<Carrier>> {
  /// The parameter `countryId` of this provider.
  String get countryId;
}

class _CarriersForCountryProviderElement
    extends AutoDisposeFutureProviderElement<List<Carrier>>
    with CarriersForCountryRef {
  _CarriersForCountryProviderElement(super.provider);

  @override
  String get countryId => (origin as CarriersForCountryProvider).countryId;
}

String _$simLineActivityLogsHash() =>
    r'e44c4e8afe24bf4c29f2bad20db784c72c129622';

/// See also [simLineActivityLogs].
@ProviderFor(simLineActivityLogs)
const simLineActivityLogsProvider = SimLineActivityLogsFamily();

/// See also [simLineActivityLogs].
class SimLineActivityLogsFamily
    extends Family<AsyncValue<List<LineActivityLog>>> {
  /// See also [simLineActivityLogs].
  const SimLineActivityLogsFamily();

  /// See also [simLineActivityLogs].
  SimLineActivityLogsProvider call(String simLineId) {
    return SimLineActivityLogsProvider(simLineId);
  }

  @override
  SimLineActivityLogsProvider getProviderOverride(
    covariant SimLineActivityLogsProvider provider,
  ) {
    return call(provider.simLineId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'simLineActivityLogsProvider';
}

/// See also [simLineActivityLogs].
class SimLineActivityLogsProvider
    extends AutoDisposeFutureProvider<List<LineActivityLog>> {
  /// See also [simLineActivityLogs].
  SimLineActivityLogsProvider(String simLineId)
    : this._internal(
        (ref) => simLineActivityLogs(ref as SimLineActivityLogsRef, simLineId),
        from: simLineActivityLogsProvider,
        name: r'simLineActivityLogsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$simLineActivityLogsHash,
        dependencies: SimLineActivityLogsFamily._dependencies,
        allTransitiveDependencies:
            SimLineActivityLogsFamily._allTransitiveDependencies,
        simLineId: simLineId,
      );

  SimLineActivityLogsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.simLineId,
  }) : super.internal();

  final String simLineId;

  @override
  Override overrideWith(
    FutureOr<List<LineActivityLog>> Function(SimLineActivityLogsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SimLineActivityLogsProvider._internal(
        (ref) => create(ref as SimLineActivityLogsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        simLineId: simLineId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<LineActivityLog>> createElement() {
    return _SimLineActivityLogsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SimLineActivityLogsProvider && other.simLineId == simLineId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, simLineId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SimLineActivityLogsRef
    on AutoDisposeFutureProviderRef<List<LineActivityLog>> {
  /// The parameter `simLineId` of this provider.
  String get simLineId;
}

class _SimLineActivityLogsProviderElement
    extends AutoDisposeFutureProviderElement<List<LineActivityLog>>
    with SimLineActivityLogsRef {
  _SimLineActivityLogsProviderElement(super.provider);

  @override
  String get simLineId => (origin as SimLineActivityLogsProvider).simLineId;
}

String _$simLinesControllerHash() =>
    r'e167c540ad4303fe51f8470564b6106672b9f5ab';

/// See also [SimLinesController].
@ProviderFor(SimLinesController)
final simLinesControllerProvider =
    AsyncNotifierProvider<SimLinesController, List<SimLine>>.internal(
      SimLinesController.new,
      name: r'simLinesControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$simLinesControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SimLinesController = AsyncNotifier<List<SimLine>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
