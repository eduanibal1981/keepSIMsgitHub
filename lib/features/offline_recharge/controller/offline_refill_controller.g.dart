// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_refill_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OfflineRefillController)
final offlineRefillControllerProvider = OfflineRefillControllerProvider._();

final class OfflineRefillControllerProvider
    extends
        $AsyncNotifierProvider<OfflineRefillController, OfflineRefillSettings> {
  OfflineRefillControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineRefillControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineRefillControllerHash();

  @$internal
  @override
  OfflineRefillController create() => OfflineRefillController();
}

String _$offlineRefillControllerHash() =>
    r'843def57553bf8e7e323ff173361de0f83f9a473';

abstract class _$OfflineRefillController
    extends $AsyncNotifier<OfflineRefillSettings> {
  FutureOr<OfflineRefillSettings> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<OfflineRefillSettings>, OfflineRefillSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<OfflineRefillSettings>,
                OfflineRefillSettings
              >,
              AsyncValue<OfflineRefillSettings>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(carrierUssdSuggestions)
final carrierUssdSuggestionsProvider = CarrierUssdSuggestionsFamily._();

final class CarrierUssdSuggestionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CarrierUssdSuggestion>>,
          List<CarrierUssdSuggestion>,
          FutureOr<List<CarrierUssdSuggestion>>
        >
    with
        $FutureModifier<List<CarrierUssdSuggestion>>,
        $FutureProvider<List<CarrierUssdSuggestion>> {
  CarrierUssdSuggestionsProvider._({
    required CarrierUssdSuggestionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'carrierUssdSuggestionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$carrierUssdSuggestionsHash();

  @override
  String toString() {
    return r'carrierUssdSuggestionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<CarrierUssdSuggestion>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CarrierUssdSuggestion>> create(Ref ref) {
    final argument = this.argument as String;
    return carrierUssdSuggestions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CarrierUssdSuggestionsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$carrierUssdSuggestionsHash() =>
    r'7bde1e71e773d06be5381762585323a40eb3a791';

final class CarrierUssdSuggestionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<CarrierUssdSuggestion>>,
          String
        > {
  CarrierUssdSuggestionsFamily._()
    : super(
        retry: null,
        name: r'carrierUssdSuggestionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CarrierUssdSuggestionsProvider call(String carrierId) =>
      CarrierUssdSuggestionsProvider._(argument: carrierId, from: this);

  @override
  String toString() => r'carrierUssdSuggestionsProvider';
}

/// The locally-queued offline refills, reconciled against the server on build
/// (C4). Drives the per-channel status chips: a refill is queued locally the
/// moment the user launches WhatsApp / SMS / the dialer, then resolves to
/// confirmed / failed / timed-out as the channel's webhook creates (or never
/// creates) the matching `topup_executions` row.

@ProviderFor(PendingOfflineRefillsController)
final pendingOfflineRefillsControllerProvider =
    PendingOfflineRefillsControllerProvider._();

/// The locally-queued offline refills, reconciled against the server on build
/// (C4). Drives the per-channel status chips: a refill is queued locally the
/// moment the user launches WhatsApp / SMS / the dialer, then resolves to
/// confirmed / failed / timed-out as the channel's webhook creates (or never
/// creates) the matching `topup_executions` row.
final class PendingOfflineRefillsControllerProvider
    extends
        $AsyncNotifierProvider<
          PendingOfflineRefillsController,
          List<PendingOfflineRefill>
        > {
  /// The locally-queued offline refills, reconciled against the server on build
  /// (C4). Drives the per-channel status chips: a refill is queued locally the
  /// moment the user launches WhatsApp / SMS / the dialer, then resolves to
  /// confirmed / failed / timed-out as the channel's webhook creates (or never
  /// creates) the matching `topup_executions` row.
  PendingOfflineRefillsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingOfflineRefillsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingOfflineRefillsControllerHash();

  @$internal
  @override
  PendingOfflineRefillsController create() => PendingOfflineRefillsController();
}

String _$pendingOfflineRefillsControllerHash() =>
    r'628b14698788a133aa3635ac0c94bf719fdda5db';

/// The locally-queued offline refills, reconciled against the server on build
/// (C4). Drives the per-channel status chips: a refill is queued locally the
/// moment the user launches WhatsApp / SMS / the dialer, then resolves to
/// confirmed / failed / timed-out as the channel's webhook creates (or never
/// creates) the matching `topup_executions` row.

abstract class _$PendingOfflineRefillsController
    extends $AsyncNotifier<List<PendingOfflineRefill>> {
  FutureOr<List<PendingOfflineRefill>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<PendingOfflineRefill>>,
              List<PendingOfflineRefill>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<PendingOfflineRefill>>,
                List<PendingOfflineRefill>
              >,
              AsyncValue<List<PendingOfflineRefill>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
