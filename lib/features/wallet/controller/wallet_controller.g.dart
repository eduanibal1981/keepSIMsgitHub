// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WalletController)
final walletControllerProvider = WalletControllerProvider._();

final class WalletControllerProvider
    extends $AsyncNotifierProvider<WalletController, WalletState> {
  WalletControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'walletControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$walletControllerHash();

  @$internal
  @override
  WalletController create() => WalletController();
}

String _$walletControllerHash() => r'59dc6b439f9bf72d928db9df16f6bd87ed94ec6c';

abstract class _$WalletController extends $AsyncNotifier<WalletState> {
  FutureOr<WalletState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<WalletState>, WalletState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<WalletState>, WalletState>,
              AsyncValue<WalletState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
