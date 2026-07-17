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

/// Percentage part of the premium margin, applied to the refill's cost.
///
/// Stated rather than hidden: it used to live inside `inapp_pricing` labelled as
/// a PayPal fee, charged once per refill against a bill PayPal issues once a
/// year. `system_configs.PREMIUM_MARGIN_PERCENT` — one row, no app update.

@ProviderFor(premiumMarginPercent)
final premiumMarginPercentProvider = PremiumMarginPercentProvider._();

/// Percentage part of the premium margin, applied to the refill's cost.
///
/// Stated rather than hidden: it used to live inside `inapp_pricing` labelled as
/// a PayPal fee, charged once per refill against a bill PayPal issues once a
/// year. `system_configs.PREMIUM_MARGIN_PERCENT` — one row, no app update.

final class PremiumMarginPercentProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// Percentage part of the premium margin, applied to the refill's cost.
  ///
  /// Stated rather than hidden: it used to live inside `inapp_pricing` labelled as
  /// a PayPal fee, charged once per refill against a bill PayPal issues once a
  /// year. `system_configs.PREMIUM_MARGIN_PERCENT` — one row, no app update.
  PremiumMarginPercentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'premiumMarginPercentProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$premiumMarginPercentHash();

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    return premiumMarginPercent(ref);
  }
}

String _$premiumMarginPercentHash() =>
    r'294ef4db0eb7b6d8669974ff38aa2c23903ca74a';

/// Flat part of the premium margin, per refill.
///
/// The margin needs both parts: the flat component is worth ~2.6% of a $277 plan
/// but ~41% of a $13 one, so a single percentage cannot express it. Capped well
/// above any sane value rather than at 100, since this is dollars, not a rate.

@ProviderFor(premiumMarginPerRefillUsd)
final premiumMarginPerRefillUsdProvider = PremiumMarginPerRefillUsdProvider._();

/// Flat part of the premium margin, per refill.
///
/// The margin needs both parts: the flat component is worth ~2.6% of a $277 plan
/// but ~41% of a $13 one, so a single percentage cannot express it. Capped well
/// above any sane value rather than at 100, since this is dollars, not a rate.

final class PremiumMarginPerRefillUsdProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// Flat part of the premium margin, per refill.
  ///
  /// The margin needs both parts: the flat component is worth ~2.6% of a $277 plan
  /// but ~41% of a $13 one, so a single percentage cannot express it. Capped well
  /// above any sane value rather than at 100, since this is dollars, not a rate.
  PremiumMarginPerRefillUsdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'premiumMarginPerRefillUsdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$premiumMarginPerRefillUsdHash();

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    return premiumMarginPerRefillUsd(ref);
  }
}

String _$premiumMarginPerRefillUsdHash() =>
    r'812dec90ee252a2de078d94ce60bae8e35611c44';

/// One gateway's fees, straight from `payment_gateways` — the single source of
/// truth for what a gateway charges.
///
/// Nothing should hardcode a rate or bake one into a stored column: the whole
/// point of the table is that renegotiating a rate is one row change with no app
/// update. Returns null when the gateway is missing or inactive, so callers must
/// decide what that means rather than silently pricing at zero.

@ProviderFor(paymentGateway)
final paymentGatewayProvider = PaymentGatewayFamily._();

/// One gateway's fees, straight from `payment_gateways` — the single source of
/// truth for what a gateway charges.
///
/// Nothing should hardcode a rate or bake one into a stored column: the whole
/// point of the table is that renegotiating a rate is one row change with no app
/// update. Returns null when the gateway is missing or inactive, so callers must
/// decide what that means rather than silently pricing at zero.

final class PaymentGatewayProvider
    extends
        $FunctionalProvider<
          AsyncValue<PaymentMethod?>,
          PaymentMethod?,
          FutureOr<PaymentMethod?>
        >
    with $FutureModifier<PaymentMethod?>, $FutureProvider<PaymentMethod?> {
  /// One gateway's fees, straight from `payment_gateways` — the single source of
  /// truth for what a gateway charges.
  ///
  /// Nothing should hardcode a rate or bake one into a stored column: the whole
  /// point of the table is that renegotiating a rate is one row change with no app
  /// update. Returns null when the gateway is missing or inactive, so callers must
  /// decide what that means rather than silently pricing at zero.
  PaymentGatewayProvider._({
    required PaymentGatewayFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'paymentGatewayProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$paymentGatewayHash();

  @override
  String toString() {
    return r'paymentGatewayProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PaymentMethod?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PaymentMethod?> create(Ref ref) {
    final argument = this.argument as String;
    return paymentGateway(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PaymentGatewayProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$paymentGatewayHash() => r'd21ccbf4da5de7734ab0e5f326d373964e43afbe';

/// One gateway's fees, straight from `payment_gateways` — the single source of
/// truth for what a gateway charges.
///
/// Nothing should hardcode a rate or bake one into a stored column: the whole
/// point of the table is that renegotiating a rate is one row change with no app
/// update. Returns null when the gateway is missing or inactive, so callers must
/// decide what that means rather than silently pricing at zero.

final class PaymentGatewayFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PaymentMethod?>, String> {
  PaymentGatewayFamily._()
    : super(
        retry: null,
        name: r'paymentGatewayProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One gateway's fees, straight from `payment_gateways` — the single source of
  /// truth for what a gateway charges.
  ///
  /// Nothing should hardcode a rate or bake one into a stored column: the whole
  /// point of the table is that renegotiating a rate is one row change with no app
  /// update. Returns null when the gateway is missing or inactive, so callers must
  /// decide what that means rather than silently pricing at zero.

  PaymentGatewayProvider call(String code) =>
      PaymentGatewayProvider._(argument: code, from: this);

  @override
  String toString() => r'paymentGatewayProvider';
}
