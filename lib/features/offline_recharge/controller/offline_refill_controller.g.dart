// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_refill_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$carrierUssdSuggestionsHash() =>
    r'fcd373a72b262a1293eab05d73ff9aa11f954fa3';

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

/// See also [carrierUssdSuggestions].
@ProviderFor(carrierUssdSuggestions)
const carrierUssdSuggestionsProvider = CarrierUssdSuggestionsFamily();

/// See also [carrierUssdSuggestions].
class CarrierUssdSuggestionsFamily
    extends Family<AsyncValue<List<CarrierUssdSuggestion>>> {
  /// See also [carrierUssdSuggestions].
  const CarrierUssdSuggestionsFamily();

  /// See also [carrierUssdSuggestions].
  CarrierUssdSuggestionsProvider call(String carrierId) {
    return CarrierUssdSuggestionsProvider(carrierId);
  }

  @override
  CarrierUssdSuggestionsProvider getProviderOverride(
    covariant CarrierUssdSuggestionsProvider provider,
  ) {
    return call(provider.carrierId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'carrierUssdSuggestionsProvider';
}

/// See also [carrierUssdSuggestions].
class CarrierUssdSuggestionsProvider
    extends AutoDisposeFutureProvider<List<CarrierUssdSuggestion>> {
  /// See also [carrierUssdSuggestions].
  CarrierUssdSuggestionsProvider(String carrierId)
    : this._internal(
        (ref) =>
            carrierUssdSuggestions(ref as CarrierUssdSuggestionsRef, carrierId),
        from: carrierUssdSuggestionsProvider,
        name: r'carrierUssdSuggestionsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$carrierUssdSuggestionsHash,
        dependencies: CarrierUssdSuggestionsFamily._dependencies,
        allTransitiveDependencies:
            CarrierUssdSuggestionsFamily._allTransitiveDependencies,
        carrierId: carrierId,
      );

  CarrierUssdSuggestionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.carrierId,
  }) : super.internal();

  final String carrierId;

  @override
  Override overrideWith(
    FutureOr<List<CarrierUssdSuggestion>> Function(
      CarrierUssdSuggestionsRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CarrierUssdSuggestionsProvider._internal(
        (ref) => create(ref as CarrierUssdSuggestionsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        carrierId: carrierId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<CarrierUssdSuggestion>>
  createElement() {
    return _CarrierUssdSuggestionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CarrierUssdSuggestionsProvider &&
        other.carrierId == carrierId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, carrierId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CarrierUssdSuggestionsRef
    on AutoDisposeFutureProviderRef<List<CarrierUssdSuggestion>> {
  /// The parameter `carrierId` of this provider.
  String get carrierId;
}

class _CarrierUssdSuggestionsProviderElement
    extends AutoDisposeFutureProviderElement<List<CarrierUssdSuggestion>>
    with CarrierUssdSuggestionsRef {
  _CarrierUssdSuggestionsProviderElement(super.provider);

  @override
  String get carrierId => (origin as CarrierUssdSuggestionsProvider).carrierId;
}

String _$offlineRefillControllerHash() =>
    r'843def57553bf8e7e323ff173361de0f83f9a473';

/// See also [OfflineRefillController].
@ProviderFor(OfflineRefillController)
final offlineRefillControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      OfflineRefillController,
      OfflineRefillSettings
    >.internal(
      OfflineRefillController.new,
      name: r'offlineRefillControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$offlineRefillControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$OfflineRefillController =
    AutoDisposeAsyncNotifier<OfflineRefillSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
