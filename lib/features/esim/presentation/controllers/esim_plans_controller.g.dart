// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'esim_plans_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EsimPlansController)
final esimPlansControllerProvider = EsimPlansControllerFamily._();

final class EsimPlansControllerProvider
    extends $AsyncNotifierProvider<EsimPlansController, List<EsimPlan>> {
  EsimPlansControllerProvider._({
    required EsimPlansControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'esimPlansControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$esimPlansControllerHash();

  @override
  String toString() {
    return r'esimPlansControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  EsimPlansController create() => EsimPlansController();

  @override
  bool operator ==(Object other) {
    return other is EsimPlansControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$esimPlansControllerHash() =>
    r'9b1e781ff64daac610a395264dcde50466a27635';

final class EsimPlansControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          EsimPlansController,
          AsyncValue<List<EsimPlan>>,
          List<EsimPlan>,
          FutureOr<List<EsimPlan>>,
          String
        > {
  EsimPlansControllerFamily._()
    : super(
        retry: null,
        name: r'esimPlansControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EsimPlansControllerProvider call(String countryIsoCode) =>
      EsimPlansControllerProvider._(argument: countryIsoCode, from: this);

  @override
  String toString() => r'esimPlansControllerProvider';
}

abstract class _$EsimPlansController extends $AsyncNotifier<List<EsimPlan>> {
  late final _$args = ref.$arg as String;
  String get countryIsoCode => _$args;

  FutureOr<List<EsimPlan>> build(String countryIsoCode);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<EsimPlan>>, List<EsimPlan>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<EsimPlan>>, List<EsimPlan>>,
              AsyncValue<List<EsimPlan>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
