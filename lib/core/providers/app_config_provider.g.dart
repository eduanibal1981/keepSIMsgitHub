// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The authoritative refill fee rules from app_fee_rules, keyed by line tier.
/// Enforces C11: Free 7% ($0.50 min), Standard 5% ($0.30 min), Premium 3% ($0.10 min).

@ProviderFor(refillFeeRules)
final refillFeeRulesProvider = RefillFeeRulesProvider._();

/// The authoritative refill fee rules from app_fee_rules, keyed by line tier.
/// Enforces C11: Free 7% ($0.50 min), Standard 5% ($0.30 min), Premium 3% ($0.10 min).

final class RefillFeeRulesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, RefillTierFeeRule>>,
          Map<String, RefillTierFeeRule>,
          FutureOr<Map<String, RefillTierFeeRule>>
        >
    with
        $FutureModifier<Map<String, RefillTierFeeRule>>,
        $FutureProvider<Map<String, RefillTierFeeRule>> {
  /// The authoritative refill fee rules from app_fee_rules, keyed by line tier.
  /// Enforces C11: Free 7% ($0.50 min), Standard 5% ($0.30 min), Premium 3% ($0.10 min).
  RefillFeeRulesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'refillFeeRulesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$refillFeeRulesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, RefillTierFeeRule>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, RefillTierFeeRule>> create(Ref ref) {
    return refillFeeRules(ref);
  }
}

String _$refillFeeRulesHash() => r'ca0f95b142326f0f003f0ec4fe943222a578ceed';

/// The KeepSIMs service fee, as a percentage of a refill's base cost.
/// Default for Premium automation or fallback callers.

@ProviderFor(appFeePercent)
final appFeePercentProvider = AppFeePercentProvider._();

/// The KeepSIMs service fee, as a percentage of a refill's base cost.
/// Default for Premium automation or fallback callers.

final class AppFeePercentProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// The KeepSIMs service fee, as a percentage of a refill's base cost.
  /// Default for Premium automation or fallback callers.
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

String _$appFeePercentHash() => r'961e7f989fcc1406bfc7397e522abc37b6a55bbf';

/// The minimum dollar floor for the app fee.
/// Default for Premium automation or fallback callers.

@ProviderFor(minAppFeeUsd)
final minAppFeeUsdProvider = MinAppFeeUsdProvider._();

/// The minimum dollar floor for the app fee.
/// Default for Premium automation or fallback callers.

final class MinAppFeeUsdProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// The minimum dollar floor for the app fee.
  /// Default for Premium automation or fallback callers.
  MinAppFeeUsdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'minAppFeeUsdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$minAppFeeUsdHash();

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    return minAppFeeUsd(ref);
  }
}

String _$minAppFeeUsdHash() => r'a642eea26e409329cc925166f08e29a9418059fd';

/// The yearly per-line service fee both paid tiers carry.
///
/// Read from `system_configs.BASE_SERVICE_FEE_USD` (C3c) instead of the
/// hardcoded $2.50 that lived in three screens. The wallet-billed charge is
/// priced server-side by `pay_plan_fee_from_wallet` from the same row; this
/// value only decides what is displayed and what a PayPal fallback bills.
/// Zero and negative are refused like the RPC refuses them, so the quote and
/// the debit cannot disagree.

@ProviderFor(baseServiceFeeUsd)
final baseServiceFeeUsdProvider = BaseServiceFeeUsdProvider._();

/// The yearly per-line service fee both paid tiers carry.
///
/// Read from `system_configs.BASE_SERVICE_FEE_USD` (C3c) instead of the
/// hardcoded $2.50 that lived in three screens. The wallet-billed charge is
/// priced server-side by `pay_plan_fee_from_wallet` from the same row; this
/// value only decides what is displayed and what a PayPal fallback bills.
/// Zero and negative are refused like the RPC refuses them, so the quote and
/// the debit cannot disagree.

final class BaseServiceFeeUsdProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// The yearly per-line service fee both paid tiers carry.
  ///
  /// Read from `system_configs.BASE_SERVICE_FEE_USD` (C3c) instead of the
  /// hardcoded $2.50 that lived in three screens. The wallet-billed charge is
  /// priced server-side by `pay_plan_fee_from_wallet` from the same row; this
  /// value only decides what is displayed and what a PayPal fallback bills.
  /// Zero and negative are refused like the RPC refuses them, so the quote and
  /// the debit cannot disagree.
  BaseServiceFeeUsdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'baseServiceFeeUsdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$baseServiceFeeUsdHash();

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    return baseServiceFeeUsd(ref);
  }
}

String _$baseServiceFeeUsdHash() => r'169bbf3542dfaf4b8e1abdb44f1e6ae83fcd09bb';

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

/// Whether geolocation is allowed to write each line's home/travel mode.
///
/// The derivation itself (`resolveLineMode`) is pure and always runs; this row
/// decides whether the result is persisted. Off by default: turning it on
/// un-pauses the protection of every line whose country the user is not in,
/// which resumes schedules and makes those lines eligible for `run_auto_rescue`
/// — a live money decision that belongs to the owner, not to a deploy.
///
/// `system_configs.GEO_LINE_MODE_SYNC_ENABLED`. A failed read means off, so a
/// network blip cannot start writing modes.

@ProviderFor(geoLineModeSyncEnabled)
final geoLineModeSyncEnabledProvider = GeoLineModeSyncEnabledProvider._();

/// Whether geolocation is allowed to write each line's home/travel mode.
///
/// The derivation itself (`resolveLineMode`) is pure and always runs; this row
/// decides whether the result is persisted. Off by default: turning it on
/// un-pauses the protection of every line whose country the user is not in,
/// which resumes schedules and makes those lines eligible for `run_auto_rescue`
/// — a live money decision that belongs to the owner, not to a deploy.
///
/// `system_configs.GEO_LINE_MODE_SYNC_ENABLED`. A failed read means off, so a
/// network blip cannot start writing modes.

final class GeoLineModeSyncEnabledProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether geolocation is allowed to write each line's home/travel mode.
  ///
  /// The derivation itself (`resolveLineMode`) is pure and always runs; this row
  /// decides whether the result is persisted. Off by default: turning it on
  /// un-pauses the protection of every line whose country the user is not in,
  /// which resumes schedules and makes those lines eligible for `run_auto_rescue`
  /// — a live money decision that belongs to the owner, not to a deploy.
  ///
  /// `system_configs.GEO_LINE_MODE_SYNC_ENABLED`. A failed read means off, so a
  /// network blip cannot start writing modes.
  GeoLineModeSyncEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'geoLineModeSyncEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$geoLineModeSyncEnabledHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return geoLineModeSyncEnabled(ref);
  }
}

String _$geoLineModeSyncEnabledHash() =>
    r'd116fe1f157df2d234b401f31b02a81d49dc2cd9';

/// A contact number for the offline-recharge flow, from `system_configs`.
///
/// These were hardcoded Oman numbers in `offline_refill_screen.dart` (C3c).
/// The screen exists precisely for when the device is offline, so the last
/// good DB value is cached locally and served when the read fails; only a
/// fresh install that has never been online sees [fallback].

@ProviderFor(offlineContactNumber)
final offlineContactNumberProvider = OfflineContactNumberFamily._();

/// A contact number for the offline-recharge flow, from `system_configs`.
///
/// These were hardcoded Oman numbers in `offline_refill_screen.dart` (C3c).
/// The screen exists precisely for when the device is offline, so the last
/// good DB value is cached locally and served when the read fails; only a
/// fresh install that has never been online sees [fallback].

final class OfflineContactNumberProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// A contact number for the offline-recharge flow, from `system_configs`.
  ///
  /// These were hardcoded Oman numbers in `offline_refill_screen.dart` (C3c).
  /// The screen exists precisely for when the device is offline, so the last
  /// good DB value is cached locally and served when the read fails; only a
  /// fresh install that has never been online sees [fallback].
  OfflineContactNumberProvider._({
    required OfflineContactNumberFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'offlineContactNumberProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$offlineContactNumberHash();

  @override
  String toString() {
    return r'offlineContactNumberProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    final argument = this.argument as (String, String);
    return offlineContactNumber(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is OfflineContactNumberProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$offlineContactNumberHash() =>
    r'0b1a86107735c85194b2c4c73af3974f7ee79e85';

/// A contact number for the offline-recharge flow, from `system_configs`.
///
/// These were hardcoded Oman numbers in `offline_refill_screen.dart` (C3c).
/// The screen exists precisely for when the device is offline, so the last
/// good DB value is cached locally and served when the read fails; only a
/// fresh install that has never been online sees [fallback].

final class OfflineContactNumberFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, (String, String)> {
  OfflineContactNumberFamily._()
    : super(
        retry: null,
        name: r'offlineContactNumberProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// A contact number for the offline-recharge flow, from `system_configs`.
  ///
  /// These were hardcoded Oman numbers in `offline_refill_screen.dart` (C3c).
  /// The screen exists precisely for when the device is offline, so the last
  /// good DB value is cached locally and served when the read fails; only a
  /// fresh install that has never been online sees [fallback].

  OfflineContactNumberProvider call(String configKey, String fallback) =>
      OfflineContactNumberProvider._(
        argument: (configKey, fallback),
        from: this,
      );

  @override
  String toString() => r'offlineContactNumberProvider';
}

/// A per-channel offline-recharge message fee, from `system_configs`.
///
/// The official WhatsApp Business API, the SMS gateway and the Twilio voice
/// number each cost us per inbound message; that cost is passed to the wallet by
/// `calculate_topup_fees` when the refill's channel is set (C4). Keys:
/// `OFFLINE_WHATSAPP_MESSAGE_FEE_USD` / `OFFLINE_SMS_MESSAGE_FEE_USD` /
/// `OFFLINE_MISSED_CALL_FEE_USD`.
///
/// Cached locally like [offlineContactNumber] because this screen is *for* being
/// offline — the last good value is shown when the read fails. The DB trigger is
/// always the authority on what is actually debited; this only decides what the
/// card shows before the user acts.

@ProviderFor(offlineMessageFeeUsd)
final offlineMessageFeeUsdProvider = OfflineMessageFeeUsdFamily._();

/// A per-channel offline-recharge message fee, from `system_configs`.
///
/// The official WhatsApp Business API, the SMS gateway and the Twilio voice
/// number each cost us per inbound message; that cost is passed to the wallet by
/// `calculate_topup_fees` when the refill's channel is set (C4). Keys:
/// `OFFLINE_WHATSAPP_MESSAGE_FEE_USD` / `OFFLINE_SMS_MESSAGE_FEE_USD` /
/// `OFFLINE_MISSED_CALL_FEE_USD`.
///
/// Cached locally like [offlineContactNumber] because this screen is *for* being
/// offline — the last good value is shown when the read fails. The DB trigger is
/// always the authority on what is actually debited; this only decides what the
/// card shows before the user acts.

final class OfflineMessageFeeUsdProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// A per-channel offline-recharge message fee, from `system_configs`.
  ///
  /// The official WhatsApp Business API, the SMS gateway and the Twilio voice
  /// number each cost us per inbound message; that cost is passed to the wallet by
  /// `calculate_topup_fees` when the refill's channel is set (C4). Keys:
  /// `OFFLINE_WHATSAPP_MESSAGE_FEE_USD` / `OFFLINE_SMS_MESSAGE_FEE_USD` /
  /// `OFFLINE_MISSED_CALL_FEE_USD`.
  ///
  /// Cached locally like [offlineContactNumber] because this screen is *for* being
  /// offline — the last good value is shown when the read fails. The DB trigger is
  /// always the authority on what is actually debited; this only decides what the
  /// card shows before the user acts.
  OfflineMessageFeeUsdProvider._({
    required OfflineMessageFeeUsdFamily super.from,
    required (String, double) super.argument,
  }) : super(
         retry: null,
         name: r'offlineMessageFeeUsdProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$offlineMessageFeeUsdHash();

  @override
  String toString() {
    return r'offlineMessageFeeUsdProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    final argument = this.argument as (String, double);
    return offlineMessageFeeUsd(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is OfflineMessageFeeUsdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$offlineMessageFeeUsdHash() =>
    r'2115d59e4654d3018de41734ff67c27e252c60df';

/// A per-channel offline-recharge message fee, from `system_configs`.
///
/// The official WhatsApp Business API, the SMS gateway and the Twilio voice
/// number each cost us per inbound message; that cost is passed to the wallet by
/// `calculate_topup_fees` when the refill's channel is set (C4). Keys:
/// `OFFLINE_WHATSAPP_MESSAGE_FEE_USD` / `OFFLINE_SMS_MESSAGE_FEE_USD` /
/// `OFFLINE_MISSED_CALL_FEE_USD`.
///
/// Cached locally like [offlineContactNumber] because this screen is *for* being
/// offline — the last good value is shown when the read fails. The DB trigger is
/// always the authority on what is actually debited; this only decides what the
/// card shows before the user acts.

final class OfflineMessageFeeUsdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<double>, (String, double)> {
  OfflineMessageFeeUsdFamily._()
    : super(
        retry: null,
        name: r'offlineMessageFeeUsdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// A per-channel offline-recharge message fee, from `system_configs`.
  ///
  /// The official WhatsApp Business API, the SMS gateway and the Twilio voice
  /// number each cost us per inbound message; that cost is passed to the wallet by
  /// `calculate_topup_fees` when the refill's channel is set (C4). Keys:
  /// `OFFLINE_WHATSAPP_MESSAGE_FEE_USD` / `OFFLINE_SMS_MESSAGE_FEE_USD` /
  /// `OFFLINE_MISSED_CALL_FEE_USD`.
  ///
  /// Cached locally like [offlineContactNumber] because this screen is *for* being
  /// offline — the last good value is shown when the read fails. The DB trigger is
  /// always the authority on what is actually debited; this only decides what the
  /// card shows before the user acts.

  OfflineMessageFeeUsdProvider call(String configKey, double fallback) =>
      OfflineMessageFeeUsdProvider._(
        argument: (configKey, fallback),
        from: this,
      );

  @override
  String toString() => r'offlineMessageFeeUsdProvider';
}

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
