// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sim_line_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$simLineDetailControllerHash() =>
    r'4f2a80b18bcaf71b5a492ecbdcd6d22a3db353c1';

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

abstract class _$SimLineDetailController
    extends BuildlessAutoDisposeAsyncNotifier<SimLineDetailState> {
  late final String id;

  FutureOr<SimLineDetailState> build(String id);
}

/// See also [SimLineDetailController].
@ProviderFor(SimLineDetailController)
const simLineDetailControllerProvider = SimLineDetailControllerFamily();

/// See also [SimLineDetailController].
class SimLineDetailControllerFamily
    extends Family<AsyncValue<SimLineDetailState>> {
  /// See also [SimLineDetailController].
  const SimLineDetailControllerFamily();

  /// See also [SimLineDetailController].
  SimLineDetailControllerProvider call(String id) {
    return SimLineDetailControllerProvider(id);
  }

  @override
  SimLineDetailControllerProvider getProviderOverride(
    covariant SimLineDetailControllerProvider provider,
  ) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'simLineDetailControllerProvider';
}

/// See also [SimLineDetailController].
class SimLineDetailControllerProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          SimLineDetailController,
          SimLineDetailState
        > {
  /// See also [SimLineDetailController].
  SimLineDetailControllerProvider(String id)
    : this._internal(
        () => SimLineDetailController()..id = id,
        from: simLineDetailControllerProvider,
        name: r'simLineDetailControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$simLineDetailControllerHash,
        dependencies: SimLineDetailControllerFamily._dependencies,
        allTransitiveDependencies:
            SimLineDetailControllerFamily._allTransitiveDependencies,
        id: id,
      );

  SimLineDetailControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  FutureOr<SimLineDetailState> runNotifierBuild(
    covariant SimLineDetailController notifier,
  ) {
    return notifier.build(id);
  }

  @override
  Override overrideWith(SimLineDetailController Function() create) {
    return ProviderOverride(
      origin: this,
      override: SimLineDetailControllerProvider._internal(
        () => create()..id = id,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<
    SimLineDetailController,
    SimLineDetailState
  >
  createElement() {
    return _SimLineDetailControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SimLineDetailControllerProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SimLineDetailControllerRef
    on AutoDisposeAsyncNotifierProviderRef<SimLineDetailState> {
  /// The parameter `id` of this provider.
  String get id;
}

class _SimLineDetailControllerProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          SimLineDetailController,
          SimLineDetailState
        >
    with SimLineDetailControllerRef {
  _SimLineDetailControllerProviderElement(super.provider);

  @override
  String get id => (origin as SimLineDetailControllerProvider).id;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
