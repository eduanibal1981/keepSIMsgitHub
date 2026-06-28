// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_cache_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sharedPreferences)
final sharedPreferencesProvider = SharedPreferencesProvider._();

final class SharedPreferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<SharedPreferences>,
          SharedPreferences,
          FutureOr<SharedPreferences>
        >
    with
        $FutureModifier<SharedPreferences>,
        $FutureProvider<SharedPreferences> {
  SharedPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sharedPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sharedPreferencesHash();

  @$internal
  @override
  $FutureProviderElement<SharedPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SharedPreferences> create(Ref ref) {
    return sharedPreferences(ref);
  }
}

String _$sharedPreferencesHash() => r'50d46e3f8d9f32715d0f3efabdce724e4b2593b4';

@ProviderFor(localCacheService)
final localCacheServiceProvider = LocalCacheServiceProvider._();

final class LocalCacheServiceProvider
    extends
        $FunctionalProvider<
          LocalCacheService,
          LocalCacheService,
          LocalCacheService
        >
    with $Provider<LocalCacheService> {
  LocalCacheServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localCacheServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localCacheServiceHash();

  @$internal
  @override
  $ProviderElement<LocalCacheService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LocalCacheService create(Ref ref) {
    return localCacheService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalCacheService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalCacheService>(value),
    );
  }
}

String _$localCacheServiceHash() => r'92509e483dec92f4b4a3fe1f1d98feaf5e08fa02';
