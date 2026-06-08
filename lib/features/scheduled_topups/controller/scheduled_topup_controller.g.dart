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

String _$scheduledNotifyForLineHash() =>
    r'ad73ec7b2268ac403a3b5fae313aaa3143cd1e68';

/// Helper provider to get Notify schedule for a specific SIM line.
///
/// Copied from [scheduledNotifyForLine].
@ProviderFor(scheduledNotifyForLine)
const scheduledNotifyForLineProvider = ScheduledNotifyForLineFamily();

/// Helper provider to get Notify schedule for a specific SIM line.
///
/// Copied from [scheduledNotifyForLine].
class ScheduledNotifyForLineFamily extends Family<ScheduledTopup?> {
  /// Helper provider to get Notify schedule for a specific SIM line.
  ///
  /// Copied from [scheduledNotifyForLine].
  const ScheduledNotifyForLineFamily();

  /// Helper provider to get Notify schedule for a specific SIM line.
  ///
  /// Copied from [scheduledNotifyForLine].
  ScheduledNotifyForLineProvider call(String simLineId) {
    return ScheduledNotifyForLineProvider(simLineId);
  }

  @override
  ScheduledNotifyForLineProvider getProviderOverride(
    covariant ScheduledNotifyForLineProvider provider,
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
  String? get name => r'scheduledNotifyForLineProvider';
}

/// Helper provider to get Notify schedule for a specific SIM line.
///
/// Copied from [scheduledNotifyForLine].
class ScheduledNotifyForLineProvider
    extends AutoDisposeProvider<ScheduledTopup?> {
  /// Helper provider to get Notify schedule for a specific SIM line.
  ///
  /// Copied from [scheduledNotifyForLine].
  ScheduledNotifyForLineProvider(String simLineId)
    : this._internal(
        (ref) =>
            scheduledNotifyForLine(ref as ScheduledNotifyForLineRef, simLineId),
        from: scheduledNotifyForLineProvider,
        name: r'scheduledNotifyForLineProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$scheduledNotifyForLineHash,
        dependencies: ScheduledNotifyForLineFamily._dependencies,
        allTransitiveDependencies:
            ScheduledNotifyForLineFamily._allTransitiveDependencies,
        simLineId: simLineId,
      );

  ScheduledNotifyForLineProvider._internal(
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
    ScheduledTopup? Function(ScheduledNotifyForLineRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ScheduledNotifyForLineProvider._internal(
        (ref) => create(ref as ScheduledNotifyForLineRef),
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
    return _ScheduledNotifyForLineProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduledNotifyForLineProvider &&
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
mixin ScheduledNotifyForLineRef on AutoDisposeProviderRef<ScheduledTopup?> {
  /// The parameter `simLineId` of this provider.
  String get simLineId;
}

class _ScheduledNotifyForLineProviderElement
    extends AutoDisposeProviderElement<ScheduledTopup?>
    with ScheduledNotifyForLineRef {
  _ScheduledNotifyForLineProviderElement(super.provider);

  @override
  String get simLineId => (origin as ScheduledNotifyForLineProvider).simLineId;
}

String _$scheduledRefillForLineHash() =>
    r'cb4743a289873d277ba8d519da82e720b551915b';

/// Helper provider to get Refill schedule for a specific SIM line.
///
/// Copied from [scheduledRefillForLine].
@ProviderFor(scheduledRefillForLine)
const scheduledRefillForLineProvider = ScheduledRefillForLineFamily();

/// Helper provider to get Refill schedule for a specific SIM line.
///
/// Copied from [scheduledRefillForLine].
class ScheduledRefillForLineFamily extends Family<ScheduledTopup?> {
  /// Helper provider to get Refill schedule for a specific SIM line.
  ///
  /// Copied from [scheduledRefillForLine].
  const ScheduledRefillForLineFamily();

  /// Helper provider to get Refill schedule for a specific SIM line.
  ///
  /// Copied from [scheduledRefillForLine].
  ScheduledRefillForLineProvider call(String simLineId) {
    return ScheduledRefillForLineProvider(simLineId);
  }

  @override
  ScheduledRefillForLineProvider getProviderOverride(
    covariant ScheduledRefillForLineProvider provider,
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
  String? get name => r'scheduledRefillForLineProvider';
}

/// Helper provider to get Refill schedule for a specific SIM line.
///
/// Copied from [scheduledRefillForLine].
class ScheduledRefillForLineProvider
    extends AutoDisposeProvider<ScheduledTopup?> {
  /// Helper provider to get Refill schedule for a specific SIM line.
  ///
  /// Copied from [scheduledRefillForLine].
  ScheduledRefillForLineProvider(String simLineId)
    : this._internal(
        (ref) =>
            scheduledRefillForLine(ref as ScheduledRefillForLineRef, simLineId),
        from: scheduledRefillForLineProvider,
        name: r'scheduledRefillForLineProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$scheduledRefillForLineHash,
        dependencies: ScheduledRefillForLineFamily._dependencies,
        allTransitiveDependencies:
            ScheduledRefillForLineFamily._allTransitiveDependencies,
        simLineId: simLineId,
      );

  ScheduledRefillForLineProvider._internal(
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
    ScheduledTopup? Function(ScheduledRefillForLineRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ScheduledRefillForLineProvider._internal(
        (ref) => create(ref as ScheduledRefillForLineRef),
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
    return _ScheduledRefillForLineProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduledRefillForLineProvider &&
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
mixin ScheduledRefillForLineRef on AutoDisposeProviderRef<ScheduledTopup?> {
  /// The parameter `simLineId` of this provider.
  String get simLineId;
}

class _ScheduledRefillForLineProviderElement
    extends AutoDisposeProviderElement<ScheduledTopup?>
    with ScheduledRefillForLineRef {
  _ScheduledRefillForLineProviderElement(super.provider);

  @override
  String get simLineId => (origin as ScheduledRefillForLineProvider).simLineId;
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
String _$simLineExecutionsHistoryHash() =>
    r'12861408def54248878aac9b24efea8b462243dc';

abstract class _$SimLineExecutionsHistory
    extends BuildlessAutoDisposeAsyncNotifier<List<TopupExecution>> {
  late final String simLineId;

  FutureOr<List<TopupExecution>> build(String simLineId);
}

/// Paginated execution history provider.
///
/// Copied from [SimLineExecutionsHistory].
@ProviderFor(SimLineExecutionsHistory)
const simLineExecutionsHistoryProvider = SimLineExecutionsHistoryFamily();

/// Paginated execution history provider.
///
/// Copied from [SimLineExecutionsHistory].
class SimLineExecutionsHistoryFamily
    extends Family<AsyncValue<List<TopupExecution>>> {
  /// Paginated execution history provider.
  ///
  /// Copied from [SimLineExecutionsHistory].
  const SimLineExecutionsHistoryFamily();

  /// Paginated execution history provider.
  ///
  /// Copied from [SimLineExecutionsHistory].
  SimLineExecutionsHistoryProvider call(String simLineId) {
    return SimLineExecutionsHistoryProvider(simLineId);
  }

  @override
  SimLineExecutionsHistoryProvider getProviderOverride(
    covariant SimLineExecutionsHistoryProvider provider,
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
  String? get name => r'simLineExecutionsHistoryProvider';
}

/// Paginated execution history provider.
///
/// Copied from [SimLineExecutionsHistory].
class SimLineExecutionsHistoryProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          SimLineExecutionsHistory,
          List<TopupExecution>
        > {
  /// Paginated execution history provider.
  ///
  /// Copied from [SimLineExecutionsHistory].
  SimLineExecutionsHistoryProvider(String simLineId)
    : this._internal(
        () => SimLineExecutionsHistory()..simLineId = simLineId,
        from: simLineExecutionsHistoryProvider,
        name: r'simLineExecutionsHistoryProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$simLineExecutionsHistoryHash,
        dependencies: SimLineExecutionsHistoryFamily._dependencies,
        allTransitiveDependencies:
            SimLineExecutionsHistoryFamily._allTransitiveDependencies,
        simLineId: simLineId,
      );

  SimLineExecutionsHistoryProvider._internal(
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
  FutureOr<List<TopupExecution>> runNotifierBuild(
    covariant SimLineExecutionsHistory notifier,
  ) {
    return notifier.build(simLineId);
  }

  @override
  Override overrideWith(SimLineExecutionsHistory Function() create) {
    return ProviderOverride(
      origin: this,
      override: SimLineExecutionsHistoryProvider._internal(
        () => create()..simLineId = simLineId,
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
  AutoDisposeAsyncNotifierProviderElement<
    SimLineExecutionsHistory,
    List<TopupExecution>
  >
  createElement() {
    return _SimLineExecutionsHistoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SimLineExecutionsHistoryProvider &&
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
mixin SimLineExecutionsHistoryRef
    on AutoDisposeAsyncNotifierProviderRef<List<TopupExecution>> {
  /// The parameter `simLineId` of this provider.
  String get simLineId;
}

class _SimLineExecutionsHistoryProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          SimLineExecutionsHistory,
          List<TopupExecution>
        >
    with SimLineExecutionsHistoryRef {
  _SimLineExecutionsHistoryProviderElement(super.provider);

  @override
  String get simLineId =>
      (origin as SimLineExecutionsHistoryProvider).simLineId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
