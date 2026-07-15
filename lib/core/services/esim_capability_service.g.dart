// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'esim_capability_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod provider that caches the eSIM capability check result.
///
/// The result is evaluated once at app startup and kept alive for the
/// lifetime of the process — eSIM hardware support does not change
/// at runtime.

@ProviderFor(EsimCapabilityService)
final esimCapabilityServiceProvider = EsimCapabilityServiceProvider._();

/// Riverpod provider that caches the eSIM capability check result.
///
/// The result is evaluated once at app startup and kept alive for the
/// lifetime of the process — eSIM hardware support does not change
/// at runtime.
final class EsimCapabilityServiceProvider
    extends $AsyncNotifierProvider<EsimCapabilityService, bool> {
  /// Riverpod provider that caches the eSIM capability check result.
  ///
  /// The result is evaluated once at app startup and kept alive for the
  /// lifetime of the process — eSIM hardware support does not change
  /// at runtime.
  EsimCapabilityServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'esimCapabilityServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$esimCapabilityServiceHash();

  @$internal
  @override
  EsimCapabilityService create() => EsimCapabilityService();
}

String _$esimCapabilityServiceHash() =>
    r'20bc75e3e2848055a290768e8365ecf33d8060ba';

/// Riverpod provider that caches the eSIM capability check result.
///
/// The result is evaluated once at app startup and kept alive for the
/// lifetime of the process — eSIM hardware support does not change
/// at runtime.

abstract class _$EsimCapabilityService extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
