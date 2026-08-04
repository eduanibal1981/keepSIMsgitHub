// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'promo_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The adverts this user should see right now.
///
/// Targeting, the live window and the per-user dismissal are all decided
/// server-side by `get_active_promos()`. Nothing is filtered here on purpose:
/// a client that re-applies the targeting rule is a second copy of it, and the
/// two drift.

@ProviderFor(activePromos)
final activePromosProvider = ActivePromosProvider._();

/// The adverts this user should see right now.
///
/// Targeting, the live window and the per-user dismissal are all decided
/// server-side by `get_active_promos()`. Nothing is filtered here on purpose:
/// a client that re-applies the targeting rule is a second copy of it, and the
/// two drift.

final class ActivePromosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ActivePromo>>,
          List<ActivePromo>,
          FutureOr<List<ActivePromo>>
        >
    with
        $FutureModifier<List<ActivePromo>>,
        $FutureProvider<List<ActivePromo>> {
  /// The adverts this user should see right now.
  ///
  /// Targeting, the live window and the per-user dismissal are all decided
  /// server-side by `get_active_promos()`. Nothing is filtered here on purpose:
  /// a client that re-applies the targeting rule is a second copy of it, and the
  /// two drift.
  ActivePromosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activePromosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activePromosHash();

  @$internal
  @override
  $FutureProviderElement<List<ActivePromo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ActivePromo>> create(Ref ref) {
    return activePromos(ref);
  }
}

String _$activePromosHash() => r'788e5864263c2087afa786ec4a5200e0890833e5';

/// Hides a promo for this user, permanently. Invalidates the list so the card
/// disappears without a manual refresh.

@ProviderFor(PromoDismissal)
final promoDismissalProvider = PromoDismissalProvider._();

/// Hides a promo for this user, permanently. Invalidates the list so the card
/// disappears without a manual refresh.
final class PromoDismissalProvider
    extends $NotifierProvider<PromoDismissal, void> {
  /// Hides a promo for this user, permanently. Invalidates the list so the card
  /// disappears without a manual refresh.
  PromoDismissalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'promoDismissalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$promoDismissalHash();

  @$internal
  @override
  PromoDismissal create() => PromoDismissal();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$promoDismissalHash() => r'c10e87252dac8cdf3712afd62f33cfdf4a0a12a2';

/// Hides a promo for this user, permanently. Invalidates the list so the card
/// disappears without a manual refresh.

abstract class _$PromoDismissal extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
