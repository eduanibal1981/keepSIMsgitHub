// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_voucher_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(voucherVault)
final voucherVaultProvider = VoucherVaultProvider._();

final class VoucherVaultProvider
    extends $FunctionalProvider<VoucherVault, VoucherVault, VoucherVault>
    with $Provider<VoucherVault> {
  VoucherVaultProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voucherVaultProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voucherVaultHash();

  @$internal
  @override
  $ProviderElement<VoucherVault> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VoucherVault create(Ref ref) {
    return voucherVault(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoucherVault value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoucherVault>(value),
    );
  }
}

String _$voucherVaultHash() => r'1642b8a7ff83bb1b98dc35d8eef1668f0da80789';

@ProviderFor(offlineVoucherRepository)
final offlineVoucherRepositoryProvider = OfflineVoucherRepositoryProvider._();

final class OfflineVoucherRepositoryProvider
    extends
        $FunctionalProvider<
          OfflineVoucherRepository,
          OfflineVoucherRepository,
          OfflineVoucherRepository
        >
    with $Provider<OfflineVoucherRepository> {
  OfflineVoucherRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineVoucherRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineVoucherRepositoryHash();

  @$internal
  @override
  $ProviderElement<OfflineVoucherRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OfflineVoucherRepository create(Ref ref) {
    return offlineVoucherRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfflineVoucherRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfflineVoucherRepository>(value),
    );
  }
}

String _$offlineVoucherRepositoryHash() =>
    r'd5c82148ab9404d347e2743615b9a61270588eb2';

/// The server's voucher picture. Kept separate from the on-device vault so a
/// screen can render "you owe $2.50" from the cache with no signal while the
/// PIN itself never leaves the keystore.

@ProviderFor(OfflineVoucherStateController)
final offlineVoucherStateControllerProvider =
    OfflineVoucherStateControllerProvider._();

/// The server's voucher picture. Kept separate from the on-device vault so a
/// screen can render "you owe $2.50" from the cache with no signal while the
/// PIN itself never leaves the keystore.
final class OfflineVoucherStateControllerProvider
    extends
        $AsyncNotifierProvider<
          OfflineVoucherStateController,
          OfflineVoucherState
        > {
  /// The server's voucher picture. Kept separate from the on-device vault so a
  /// screen can render "you owe $2.50" from the cache with no signal while the
  /// PIN itself never leaves the keystore.
  OfflineVoucherStateControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineVoucherStateControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineVoucherStateControllerHash();

  @$internal
  @override
  OfflineVoucherStateController create() => OfflineVoucherStateController();
}

String _$offlineVoucherStateControllerHash() =>
    r'55984358bb5261786f744bc7418700f3e9e1f175';

/// The server's voucher picture. Kept separate from the on-device vault so a
/// screen can render "you owe $2.50" from the cache with no signal while the
/// PIN itself never leaves the keystore.

abstract class _$OfflineVoucherStateController
    extends $AsyncNotifier<OfflineVoucherState> {
  FutureOr<OfflineVoucherState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<OfflineVoucherState>, OfflineVoucherState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<OfflineVoucherState>, OfflineVoucherState>,
              AsyncValue<OfflineVoucherState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Everything in the keystore. Reads fine with no network — this is what the
/// emergency card renders from when there is no signal at all.

@ProviderFor(storedVouchers)
final storedVouchersProvider = StoredVouchersProvider._();

/// Everything in the keystore. Reads fine with no network — this is what the
/// emergency card renders from when there is no signal at all.

final class StoredVouchersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StoredVoucher>>,
          List<StoredVoucher>,
          FutureOr<List<StoredVoucher>>
        >
    with
        $FutureModifier<List<StoredVoucher>>,
        $FutureProvider<List<StoredVoucher>> {
  /// Everything in the keystore. Reads fine with no network — this is what the
  /// emergency card renders from when there is no signal at all.
  StoredVouchersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storedVouchersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storedVouchersHash();

  @$internal
  @override
  $FutureProviderElement<List<StoredVoucher>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<StoredVoucher>> create(Ref ref) {
    return storedVouchers(ref);
  }
}

String _$storedVouchersHash() => r'e6222541e9d2491ffe9e59850f45a8e3c3bfbea9';

/// The voucher held for one line, or null.

@ProviderFor(storedVoucher)
final storedVoucherProvider = StoredVoucherFamily._();

/// The voucher held for one line, or null.

final class StoredVoucherProvider
    extends
        $FunctionalProvider<
          AsyncValue<StoredVoucher?>,
          StoredVoucher?,
          FutureOr<StoredVoucher?>
        >
    with $FutureModifier<StoredVoucher?>, $FutureProvider<StoredVoucher?> {
  /// The voucher held for one line, or null.
  StoredVoucherProvider._({
    required StoredVoucherFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'storedVoucherProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$storedVoucherHash();

  @override
  String toString() {
    return r'storedVoucherProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<StoredVoucher?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<StoredVoucher?> create(Ref ref) {
    final argument = this.argument as String;
    return storedVoucher(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StoredVoucherProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$storedVoucherHash() => r'70666d0aa893c66ab2fc376974c4eee7354dccbe';

/// The voucher held for one line, or null.

final class StoredVoucherFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<StoredVoucher?>, String> {
  StoredVoucherFamily._()
    : super(
        retry: null,
        name: r'storedVoucherProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The voucher held for one line, or null.

  StoredVoucherProvider call(String simLineId) =>
      StoredVoucherProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'storedVoucherProvider';
}

/// Reveals a PIN. Local-only and deliberately not part of the state
/// controller: it is the one action that must work with the radio off, so it
/// touches no provider that can await the network.

@ProviderFor(VoucherRevealController)
final voucherRevealControllerProvider = VoucherRevealControllerProvider._();

/// Reveals a PIN. Local-only and deliberately not part of the state
/// controller: it is the one action that must work with the radio off, so it
/// touches no provider that can await the network.
final class VoucherRevealControllerProvider
    extends $AsyncNotifierProvider<VoucherRevealController, void> {
  /// Reveals a PIN. Local-only and deliberately not part of the state
  /// controller: it is the one action that must work with the radio off, so it
  /// touches no provider that can await the network.
  VoucherRevealControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voucherRevealControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voucherRevealControllerHash();

  @$internal
  @override
  VoucherRevealController create() => VoucherRevealController();
}

String _$voucherRevealControllerHash() =>
    r'b3d8a63a4a058a4fe74bea467dea1e0ee668cbb4';

/// Reveals a PIN. Local-only and deliberately not part of the state
/// controller: it is the one action that must work with the radio off, so it
/// touches no provider that can await the network.

abstract class _$VoucherRevealController extends $AsyncNotifier<void> {
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
