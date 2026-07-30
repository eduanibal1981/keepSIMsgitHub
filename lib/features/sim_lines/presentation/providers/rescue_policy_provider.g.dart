// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rescue_policy_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The policy for one line, or null when the owner has never touched it.

@ProviderFor(rescuePolicyForLine)
final rescuePolicyForLineProvider = RescuePolicyForLineFamily._();

/// The policy for one line, or null when the owner has never touched it.

final class RescuePolicyForLineProvider
    extends
        $FunctionalProvider<
          AsyncValue<LineRescuePolicy?>,
          LineRescuePolicy?,
          FutureOr<LineRescuePolicy?>
        >
    with
        $FutureModifier<LineRescuePolicy?>,
        $FutureProvider<LineRescuePolicy?> {
  /// The policy for one line, or null when the owner has never touched it.
  RescuePolicyForLineProvider._({
    required RescuePolicyForLineFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'rescuePolicyForLineProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rescuePolicyForLineHash();

  @override
  String toString() {
    return r'rescuePolicyForLineProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<LineRescuePolicy?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LineRescuePolicy?> create(Ref ref) {
    final argument = this.argument as String;
    return rescuePolicyForLine(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RescuePolicyForLineProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rescuePolicyForLineHash() =>
    r'd8bd3a42ded5f1f26506881143a260b0aa4cf09e';

/// The policy for one line, or null when the owner has never touched it.

final class RescuePolicyForLineFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<LineRescuePolicy?>, String> {
  RescuePolicyForLineFamily._()
    : super(
        retry: null,
        name: r'rescuePolicyForLineProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The policy for one line, or null when the owner has never touched it.

  RescuePolicyForLineProvider call(String simLineId) =>
      RescuePolicyForLineProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'rescuePolicyForLineProvider';
}

@ProviderFor(RescuePolicyController)
final rescuePolicyControllerProvider = RescuePolicyControllerProvider._();

final class RescuePolicyControllerProvider
    extends $AsyncNotifierProvider<RescuePolicyController, void> {
  RescuePolicyControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rescuePolicyControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rescuePolicyControllerHash();

  @$internal
  @override
  RescuePolicyController create() => RescuePolicyController();
}

String _$rescuePolicyControllerHash() =>
    r'06c084546b4cfe209964fdacf5b111b68f249b5d';

abstract class _$RescuePolicyController extends $AsyncNotifier<void> {
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
