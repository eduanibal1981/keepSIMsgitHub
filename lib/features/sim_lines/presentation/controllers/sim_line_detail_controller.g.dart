// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sim_line_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SimLineDetailController)
final simLineDetailControllerProvider = SimLineDetailControllerFamily._();

final class SimLineDetailControllerProvider
    extends
        $AsyncNotifierProvider<SimLineDetailController, SimLineDetailState> {
  SimLineDetailControllerProvider._({
    required SimLineDetailControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'simLineDetailControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$simLineDetailControllerHash();

  @override
  String toString() {
    return r'simLineDetailControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SimLineDetailController create() => SimLineDetailController();

  @override
  bool operator ==(Object other) {
    return other is SimLineDetailControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$simLineDetailControllerHash() =>
    r'036d94c1b2e4556c0b7304b02de92a1ac16bcb5f';

final class SimLineDetailControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SimLineDetailController,
          AsyncValue<SimLineDetailState>,
          SimLineDetailState,
          FutureOr<SimLineDetailState>,
          String
        > {
  SimLineDetailControllerFamily._()
    : super(
        retry: null,
        name: r'simLineDetailControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SimLineDetailControllerProvider call(String id) =>
      SimLineDetailControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'simLineDetailControllerProvider';
}

abstract class _$SimLineDetailController
    extends $AsyncNotifier<SimLineDetailState> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<SimLineDetailState> build(String id);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<SimLineDetailState>, SimLineDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SimLineDetailState>, SimLineDetailState>,
              AsyncValue<SimLineDetailState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
