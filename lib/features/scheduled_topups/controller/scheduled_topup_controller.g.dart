// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_topup_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$scheduledTopupForLineHash() =>
    r'7238c0ca411904cdf22aa5ab0047106465d1bcf7';

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

/// Helper provider to get schedule for a specific SIM line.
///
/// Copied from [scheduledTopupForLine].
@ProviderFor(scheduledTopupForLine)
const scheduledTopupForLineProvider = ScheduledTopupForLineFamily();

/// Helper provider to get schedule for a specific SIM line.
///
/// Copied from [scheduledTopupForLine].
class ScheduledTopupForLineFamily extends Family<ScheduledTopup?> {
  /// Helper provider to get schedule for a specific SIM line.
  ///
  /// Copied from [scheduledTopupForLine].
  const ScheduledTopupForLineFamily();

  /// Helper provider to get schedule for a specific SIM line.
  ///
  /// Copied from [scheduledTopupForLine].
  ScheduledTopupForLineProvider call(String simLineId) {
    return ScheduledTopupForLineProvider(simLineId);
  }

  @override
  ScheduledTopupForLineProvider getProviderOverride(
    covariant ScheduledTopupForLineProvider provider,
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
  String? get name => r'scheduledTopupForLineProvider';
}

/// Helper provider to get schedule for a specific SIM line.
///
/// Copied from [scheduledTopupForLine].
class ScheduledTopupForLineProvider
    extends AutoDisposeProvider<ScheduledTopup?> {
  /// Helper provider to get schedule for a specific SIM line.
  ///
  /// Copied from [scheduledTopupForLine].
  ScheduledTopupForLineProvider(String simLineId)
    : this._internal(
        (ref) =>
            scheduledTopupForLine(ref as ScheduledTopupForLineRef, simLineId),
        from: scheduledTopupForLineProvider,
        name: r'scheduledTopupForLineProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$scheduledTopupForLineHash,
        dependencies: ScheduledTopupForLineFamily._dependencies,
        allTransitiveDependencies:
            ScheduledTopupForLineFamily._allTransitiveDependencies,
        simLineId: simLineId,
      );

  ScheduledTopupForLineProvider._internal(
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
    ScheduledTopup? Function(ScheduledTopupForLineRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ScheduledTopupForLineProvider._internal(
        (ref) => create(ref as ScheduledTopupForLineRef),
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
  AutoDisposeProviderElement<ScheduledTopup?> createElement() {
    return _ScheduledTopupForLineProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduledTopupForLineProvider &&
        other.simLineId == simLineId;
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
mixin ScheduledTopupForLineRef on AutoDisposeProviderRef<ScheduledTopup?> {
  /// The parameter `simLineId` of this provider.
  String get simLineId;
}

class _ScheduledTopupForLineProviderElement
    extends AutoDisposeProviderElement<ScheduledTopup?>
    with ScheduledTopupForLineRef {
  _ScheduledTopupForLineProviderElement(super.provider);

  @override
  String get simLineId => (origin as ScheduledTopupForLineProvider).simLineId;
}

String _$topupExecutionsForLineHash() =>
    r'3e983e1d3adb91ebb30bbe661f9c81e9264924a2';

/// Family provider to watch execution history for a SIM Line.
///
/// Copied from [topupExecutionsForLine].
@ProviderFor(topupExecutionsForLine)
const topupExecutionsForLineProvider = TopupExecutionsForLineFamily();

/// Family provider to watch execution history for a SIM Line.
///
/// Copied from [topupExecutionsForLine].
class TopupExecutionsForLineFamily
    extends Family<AsyncValue<List<TopupExecution>>> {
  /// Family provider to watch execution history for a SIM Line.
  ///
  /// Copied from [topupExecutionsForLine].
  const TopupExecutionsForLineFamily();

  /// Family provider to watch execution history for a SIM Line.
  ///
  /// Copied from [topupExecutionsForLine].
  TopupExecutionsForLineProvider call(String simLineId) {
    return TopupExecutionsForLineProvider(simLineId);
  }

  @override
  TopupExecutionsForLineProvider getProviderOverride(
    covariant TopupExecutionsForLineProvider provider,
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
  String? get name => r'topupExecutionsForLineProvider';
}

/// Family provider to watch execution history for a SIM Line.
///
/// Copied from [topupExecutionsForLine].
class TopupExecutionsForLineProvider
    extends AutoDisposeFutureProvider<List<TopupExecution>> {
  /// Family provider to watch execution history for a SIM Line.
  ///
  /// Copied from [topupExecutionsForLine].
  TopupExecutionsForLineProvider(String simLineId)
    : this._internal(
        (ref) =>
            topupExecutionsForLine(ref as TopupExecutionsForLineRef, simLineId),
        from: topupExecutionsForLineProvider,
        name: r'topupExecutionsForLineProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$topupExecutionsForLineHash,
        dependencies: TopupExecutionsForLineFamily._dependencies,
        allTransitiveDependencies:
            TopupExecutionsForLineFamily._allTransitiveDependencies,
        simLineId: simLineId,
      );

  TopupExecutionsForLineProvider._internal(
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
    FutureOr<List<TopupExecution>> Function(TopupExecutionsForLineRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TopupExecutionsForLineProvider._internal(
        (ref) => create(ref as TopupExecutionsForLineRef),
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
  AutoDisposeFutureProviderElement<List<TopupExecution>> createElement() {
    return _TopupExecutionsForLineProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TopupExecutionsForLineProvider &&
        other.simLineId == simLineId;
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
mixin TopupExecutionsForLineRef
    on AutoDisposeFutureProviderRef<List<TopupExecution>> {
  /// The parameter `simLineId` of this provider.
  String get simLineId;
}

class _TopupExecutionsForLineProviderElement
    extends AutoDisposeFutureProviderElement<List<TopupExecution>>
    with TopupExecutionsForLineRef {
  _TopupExecutionsForLineProviderElement(super.provider);

  @override
  String get simLineId => (origin as TopupExecutionsForLineProvider).simLineId;
}

String _$scheduledTopupControllerHash() =>
    r'2e52dc6d9962e60732b9ff8837b62cc8633e17fa';

/// See also [ScheduledTopupController].
@ProviderFor(ScheduledTopupController)
final scheduledTopupControllerProvider =
    AsyncNotifierProvider<
      ScheduledTopupController,
      List<ScheduledTopup>
    >.internal(
      ScheduledTopupController.new,
      name: r'scheduledTopupControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$scheduledTopupControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ScheduledTopupController = AsyncNotifier<List<ScheduledTopup>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
