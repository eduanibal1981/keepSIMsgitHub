// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The KeepSIMs service fee, as a percentage of a refill's base cost.
///
/// Read from `system_configs.APP_FEE_PERCENT` instead of a constant so the
/// price quoted in the UI is the price `calculate_topup_fees` debits. These
/// were two hardcoded numbers that silently disagreed — the client quoted 3%
/// while the trigger charged 5%, so every refill cost more than it displayed.
/// A power user can change the row from the Supabase dashboard and both the
/// quote and the debit follow it with no redeploy.
///
/// The trigger is always the authority on what is actually charged; this only
/// decides what the user is shown before they confirm.

@ProviderFor(appFeePercent)
final appFeePercentProvider = AppFeePercentProvider._();

/// The KeepSIMs service fee, as a percentage of a refill's base cost.
///
/// Read from `system_configs.APP_FEE_PERCENT` instead of a constant so the
/// price quoted in the UI is the price `calculate_topup_fees` debits. These
/// were two hardcoded numbers that silently disagreed — the client quoted 3%
/// while the trigger charged 5%, so every refill cost more than it displayed.
/// A power user can change the row from the Supabase dashboard and both the
/// quote and the debit follow it with no redeploy.
///
/// The trigger is always the authority on what is actually charged; this only
/// decides what the user is shown before they confirm.

final class AppFeePercentProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// The KeepSIMs service fee, as a percentage of a refill's base cost.
  ///
  /// Read from `system_configs.APP_FEE_PERCENT` instead of a constant so the
  /// price quoted in the UI is the price `calculate_topup_fees` debits. These
  /// were two hardcoded numbers that silently disagreed — the client quoted 3%
  /// while the trigger charged 5%, so every refill cost more than it displayed.
  /// A power user can change the row from the Supabase dashboard and both the
  /// quote and the debit follow it with no redeploy.
  ///
  /// The trigger is always the authority on what is actually charged; this only
  /// decides what the user is shown before they confirm.
  AppFeePercentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appFeePercentProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appFeePercentHash();

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    return appFeePercent(ref);
  }
}

String _$appFeePercentHash() => r'3ef7ad79cecd31c5a4db6b43b8c00e62d4672321';
