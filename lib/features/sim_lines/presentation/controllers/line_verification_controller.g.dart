// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'line_verification_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$lineVerificationControllerHash() =>
    r'1cb36f26cd0d28bf12e1df82d9106f8316e96d0c';

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

abstract class _$LineVerificationController
    extends BuildlessAutoDisposeNotifier<LineVerificationState> {
  late final String simLineId;

  LineVerificationState build(String simLineId);
}

/// See also [LineVerificationController].
@ProviderFor(LineVerificationController)
const lineVerificationControllerProvider = LineVerificationControllerFamily();

/// See also [LineVerificationController].
class LineVerificationControllerFamily extends Family<LineVerificationState> {
  /// See also [LineVerificationController].
  const LineVerificationControllerFamily();

  /// See also [LineVerificationController].
  LineVerificationControllerProvider call(String simLineId) {
    return LineVerificationControllerProvider(simLineId);
  }

  @override
  LineVerificationControllerProvider getProviderOverride(
    covariant LineVerificationControllerProvider provider,
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
  String? get name => r'lineVerificationControllerProvider';
}

/// See also [LineVerificationController].
class LineVerificationControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          LineVerificationController,
          LineVerificationState
        > {
  /// See also [LineVerificationController].
  LineVerificationControllerProvider(String simLineId)
    : this._internal(
        () => LineVerificationController()..simLineId = simLineId,
        from: lineVerificationControllerProvider,
        name: r'lineVerificationControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$lineVerificationControllerHash,
        dependencies: LineVerificationControllerFamily._dependencies,
        allTransitiveDependencies:
            LineVerificationControllerFamily._allTransitiveDependencies,
        simLineId: simLineId,
      );

  LineVerificationControllerProvider._internal(
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
  LineVerificationState runNotifierBuild(
    covariant LineVerificationController notifier,
  ) {
    return notifier.build(simLineId);
  }

  @override
  Override overrideWith(LineVerificationController Function() create) {
    return ProviderOverride(
      origin: this,
      override: LineVerificationControllerProvider._internal(
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
  AutoDisposeNotifierProviderElement<
    LineVerificationController,
    LineVerificationState
  >
  createElement() {
    return _LineVerificationControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LineVerificationControllerProvider &&
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
mixin LineVerificationControllerRef
    on AutoDisposeNotifierProviderRef<LineVerificationState> {
  /// The parameter `simLineId` of this provider.
  String get simLineId;
}

class _LineVerificationControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          LineVerificationController,
          LineVerificationState
        >
    with LineVerificationControllerRef {
  _LineVerificationControllerProviderElement(super.provider);

  @override
  String get simLineId =>
      (origin as LineVerificationControllerProvider).simLineId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
