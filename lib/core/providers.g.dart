// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the [AuthContract] implementation.

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

/// Provides the [AuthContract] implementation.

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthContract, AuthContract, AuthContract>
    with $Provider<AuthContract> {
  /// Provides the [AuthContract] implementation.
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthContract> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthContract create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthContract value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthContract>(value),
    );
  }
}

String _$authRepositoryHash() => r'9fb27787d792c45e75056c4229faf3868506a783';

/// Recovery has a separate, short-lived client with no persisted sign-in session.

@ProviderFor(passwordRecoveryRepository)
final passwordRecoveryRepositoryProvider =
    PasswordRecoveryRepositoryProvider._();

/// Recovery has a separate, short-lived client with no persisted sign-in session.

final class PasswordRecoveryRepositoryProvider
    extends
        $FunctionalProvider<
          PasswordRecoveryContract,
          PasswordRecoveryContract,
          PasswordRecoveryContract
        >
    with $Provider<PasswordRecoveryContract> {
  /// Recovery has a separate, short-lived client with no persisted sign-in session.
  PasswordRecoveryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'passwordRecoveryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$passwordRecoveryRepositoryHash();

  @$internal
  @override
  $ProviderElement<PasswordRecoveryContract> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PasswordRecoveryContract create(Ref ref) {
    return passwordRecoveryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PasswordRecoveryContract value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PasswordRecoveryContract>(value),
    );
  }
}

String _$passwordRecoveryRepositoryHash() =>
    r'df93b4c84b8df71b2c77fad13ee9853200eb0b2e';

/// Provides the [ProfileContract] implementation.

@ProviderFor(profileRepository)
final profileRepositoryProvider = ProfileRepositoryProvider._();

/// Provides the [ProfileContract] implementation.

final class ProfileRepositoryProvider
    extends
        $FunctionalProvider<ProfileContract, ProfileContract, ProfileContract>
    with $Provider<ProfileContract> {
  /// Provides the [ProfileContract] implementation.
  ProfileRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProfileContract> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProfileContract create(Ref ref) {
    return profileRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileContract value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileContract>(value),
    );
  }
}

String _$profileRepositoryHash() => r'8ed23eb60f3b0ccfbc6df7c8b040f7c778137dc3';

/// Provides the [WalletContract] implementation.

@ProviderFor(walletRepository)
final walletRepositoryProvider = WalletRepositoryProvider._();

/// Provides the [WalletContract] implementation.

final class WalletRepositoryProvider
    extends $FunctionalProvider<WalletContract, WalletContract, WalletContract>
    with $Provider<WalletContract> {
  /// Provides the [WalletContract] implementation.
  WalletRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'walletRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$walletRepositoryHash();

  @$internal
  @override
  $ProviderElement<WalletContract> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WalletContract create(Ref ref) {
    return walletRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WalletContract value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WalletContract>(value),
    );
  }
}

String _$walletRepositoryHash() => r'891bf4e81f5ff59763fcd8cdce04083831c101c5';

/// Provides the [ScheduledTopupContract] implementation.

@ProviderFor(scheduledTopupRepository)
final scheduledTopupRepositoryProvider = ScheduledTopupRepositoryProvider._();

/// Provides the [ScheduledTopupContract] implementation.

final class ScheduledTopupRepositoryProvider
    extends
        $FunctionalProvider<
          ScheduledTopupContract,
          ScheduledTopupContract,
          ScheduledTopupContract
        >
    with $Provider<ScheduledTopupContract> {
  /// Provides the [ScheduledTopupContract] implementation.
  ScheduledTopupRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scheduledTopupRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scheduledTopupRepositoryHash();

  @$internal
  @override
  $ProviderElement<ScheduledTopupContract> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ScheduledTopupContract create(Ref ref) {
    return scheduledTopupRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScheduledTopupContract value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScheduledTopupContract>(value),
    );
  }
}

String _$scheduledTopupRepositoryHash() =>
    r'60313af8239799f60a41d7bfde4fd6597088fd65';

/// Provides the [ReferralsContract] implementation.

@ProviderFor(referralsRepository)
final referralsRepositoryProvider = ReferralsRepositoryProvider._();

/// Provides the [ReferralsContract] implementation.

final class ReferralsRepositoryProvider
    extends
        $FunctionalProvider<
          ReferralsContract,
          ReferralsContract,
          ReferralsContract
        >
    with $Provider<ReferralsContract> {
  /// Provides the [ReferralsContract] implementation.
  ReferralsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'referralsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$referralsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReferralsContract> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReferralsContract create(Ref ref) {
    return referralsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReferralsContract value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReferralsContract>(value),
    );
  }
}

String _$referralsRepositoryHash() =>
    r'2f2cf7f0212fddb5a3e7ce9094f300ccb458d0de';

/// Provides the [PaymentsContract] implementation.

@ProviderFor(paymentsRepository)
final paymentsRepositoryProvider = PaymentsRepositoryProvider._();

/// Provides the [PaymentsContract] implementation.

final class PaymentsRepositoryProvider
    extends
        $FunctionalProvider<
          PaymentsContract,
          PaymentsContract,
          PaymentsContract
        >
    with $Provider<PaymentsContract> {
  /// Provides the [PaymentsContract] implementation.
  PaymentsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentsRepositoryHash();

  @$internal
  @override
  $ProviderElement<PaymentsContract> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PaymentsContract create(Ref ref) {
    return paymentsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaymentsContract value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaymentsContract>(value),
    );
  }
}

String _$paymentsRepositoryHash() =>
    r'79c17e437340c74561c5ef922ed61c9251c7215a';

@ProviderFor(offlineRefillRepository)
final offlineRefillRepositoryProvider = OfflineRefillRepositoryProvider._();

final class OfflineRefillRepositoryProvider
    extends
        $FunctionalProvider<
          OfflineRefillContract,
          OfflineRefillContract,
          OfflineRefillContract
        >
    with $Provider<OfflineRefillContract> {
  OfflineRefillRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineRefillRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineRefillRepositoryHash();

  @$internal
  @override
  $ProviderElement<OfflineRefillContract> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OfflineRefillContract create(Ref ref) {
    return offlineRefillRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfflineRefillContract value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfflineRefillContract>(value),
    );
  }
}

String _$offlineRefillRepositoryHash() =>
    r'e08e65332050b91ddcd08591b0d861af13408b15';

/// Provides the [SupportContract] implementation.

@ProviderFor(supportRepository)
final supportRepositoryProvider = SupportRepositoryProvider._();

/// Provides the [SupportContract] implementation.

final class SupportRepositoryProvider
    extends
        $FunctionalProvider<SupportContract, SupportContract, SupportContract>
    with $Provider<SupportContract> {
  /// Provides the [SupportContract] implementation.
  SupportRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supportRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supportRepositoryHash();

  @$internal
  @override
  $ProviderElement<SupportContract> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SupportContract create(Ref ref) {
    return supportRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupportContract value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupportContract>(value),
    );
  }
}

String _$supportRepositoryHash() => r'9b8488064a58b2407e1c01376fec9edbcbdf8a1f';
