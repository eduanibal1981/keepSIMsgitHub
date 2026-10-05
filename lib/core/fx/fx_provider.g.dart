// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fx_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The caller's display-currency context.
///
/// Never throws into the UI: money has to render even when this call fails, so
/// any error degrades to plain USD rather than blanking a wallet balance.

@ProviderFor(FxController)
final fxControllerProvider = FxControllerProvider._();

/// The caller's display-currency context.
///
/// Never throws into the UI: money has to render even when this call fails, so
/// any error degrades to plain USD rather than blanking a wallet balance.
final class FxControllerProvider
    extends $AsyncNotifierProvider<FxController, FxContext> {
  /// The caller's display-currency context.
  ///
  /// Never throws into the UI: money has to render even when this call fails, so
  /// any error degrades to plain USD rather than blanking a wallet balance.
  FxControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fxControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fxControllerHash();

  @$internal
  @override
  FxController create() => FxController();
}

String _$fxControllerHash() => r'5515ea2fdfd2a5b65978eaf30cdc3a08cfcd4001';

/// The caller's display-currency context.
///
/// Never throws into the UI: money has to render even when this call fails, so
/// any error degrades to plain USD rather than blanking a wallet balance.

abstract class _$FxController extends $AsyncNotifier<FxContext> {
  FutureOr<FxContext> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<FxContext>, FxContext>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FxContext>, FxContext>,
              AsyncValue<FxContext>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
