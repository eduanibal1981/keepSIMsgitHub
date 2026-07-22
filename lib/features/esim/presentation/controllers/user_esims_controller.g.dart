// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_esims_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UserEsimsController)
final userEsimsControllerProvider = UserEsimsControllerProvider._();

final class UserEsimsControllerProvider
    extends $AsyncNotifierProvider<UserEsimsController, List<UserEsim>> {
  UserEsimsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userEsimsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userEsimsControllerHash();

  @$internal
  @override
  UserEsimsController create() => UserEsimsController();
}

String _$userEsimsControllerHash() =>
    r'97b5d73904e3472ade0968d93f5decfb8230ea23';

abstract class _$UserEsimsController extends $AsyncNotifier<List<UserEsim>> {
  FutureOr<List<UserEsim>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<UserEsim>>, List<UserEsim>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<UserEsim>>, List<UserEsim>>,
              AsyncValue<List<UserEsim>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(EsimOrderHistoryController)
final esimOrderHistoryControllerProvider =
    EsimOrderHistoryControllerProvider._();

final class EsimOrderHistoryControllerProvider
    extends
        $AsyncNotifierProvider<EsimOrderHistoryController, List<EsimOrder>> {
  EsimOrderHistoryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'esimOrderHistoryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$esimOrderHistoryControllerHash();

  @$internal
  @override
  EsimOrderHistoryController create() => EsimOrderHistoryController();
}

String _$esimOrderHistoryControllerHash() =>
    r'9850480764e84ba8ca934118560bbaa686721b53';

abstract class _$EsimOrderHistoryController
    extends $AsyncNotifier<List<EsimOrder>> {
  FutureOr<List<EsimOrder>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<EsimOrder>>, List<EsimOrder>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<EsimOrder>>, List<EsimOrder>>,
              AsyncValue<List<EsimOrder>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(esimOrderLive)
final esimOrderLiveProvider = EsimOrderLiveFamily._();

final class EsimOrderLiveProvider
    extends
        $FunctionalProvider<
          AsyncValue<EsimOrder?>,
          EsimOrder?,
          Stream<EsimOrder?>
        >
    with $FutureModifier<EsimOrder?>, $StreamProvider<EsimOrder?> {
  EsimOrderLiveProvider._({
    required EsimOrderLiveFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'esimOrderLiveProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$esimOrderLiveHash();

  @override
  String toString() {
    return r'esimOrderLiveProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<EsimOrder?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<EsimOrder?> create(Ref ref) {
    final argument = this.argument as String;
    return esimOrderLive(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EsimOrderLiveProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$esimOrderLiveHash() => r'51a66073457a94db515c0e462e14da47f1d41d66';

final class EsimOrderLiveFamily extends $Family
    with $FunctionalFamilyOverride<Stream<EsimOrder?>, String> {
  EsimOrderLiveFamily._()
    : super(
        retry: null,
        name: r'esimOrderLiveProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EsimOrderLiveProvider call(String orderId) =>
      EsimOrderLiveProvider._(argument: orderId, from: this);

  @override
  String toString() => r'esimOrderLiveProvider';
}
