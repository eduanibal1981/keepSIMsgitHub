// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payments_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PaymentsController)
final paymentsControllerProvider = PaymentsControllerProvider._();

final class PaymentsControllerProvider
    extends $AsyncNotifierProvider<PaymentsController, PaymentsState> {
  PaymentsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentsControllerHash();

  @$internal
  @override
  PaymentsController create() => PaymentsController();
}

String _$paymentsControllerHash() =>
    r'025cd3e7d5ed4d40b976fa84064a0a7724a89b72';

abstract class _$PaymentsController extends $AsyncNotifier<PaymentsState> {
  FutureOr<PaymentsState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PaymentsState>, PaymentsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PaymentsState>, PaymentsState>,
              AsyncValue<PaymentsState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
