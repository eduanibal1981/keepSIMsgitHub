// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'esim_provider_factory.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the correct EsimRepository implementation.
/// Currently defaults to EsimGoRepositoryImpl, but can be expanded
/// to select different providers based on country or user preferences.

@ProviderFor(esimRepository)
final esimRepositoryProvider = EsimRepositoryProvider._();

/// Provides the correct EsimRepository implementation.
/// Currently defaults to EsimGoRepositoryImpl, but can be expanded
/// to select different providers based on country or user preferences.

final class EsimRepositoryProvider
    extends $FunctionalProvider<EsimRepository, EsimRepository, EsimRepository>
    with $Provider<EsimRepository> {
  /// Provides the correct EsimRepository implementation.
  /// Currently defaults to EsimGoRepositoryImpl, but can be expanded
  /// to select different providers based on country or user preferences.
  EsimRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'esimRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$esimRepositoryHash();

  @$internal
  @override
  $ProviderElement<EsimRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EsimRepository create(Ref ref) {
    return esimRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EsimRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EsimRepository>(value),
    );
  }
}

String _$esimRepositoryHash() => r'5193da5db4f595339f3d88757c8da37062c474c9';
