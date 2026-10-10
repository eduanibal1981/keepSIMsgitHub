// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SplashCompleted)
final splashCompletedProvider = SplashCompletedProvider._();

final class SplashCompletedProvider
    extends $NotifierProvider<SplashCompleted, bool> {
  SplashCompletedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'splashCompletedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$splashCompletedHash();

  @$internal
  @override
  SplashCompleted create() => SplashCompleted();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$splashCompletedHash() => r'e7593a4ebf31d2994b23da76b399932fbf19c1e7';

abstract class _$SplashCompleted extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Provides the app's GoRouter instance with auth-based redirects.

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// Provides the app's GoRouter instance with auth-based redirects.

final class AppRouterProvider
    extends
        $FunctionalProvider<
          RouterConfig<Object>,
          RouterConfig<Object>,
          RouterConfig<Object>
        >
    with $Provider<RouterConfig<Object>> {
  /// Provides the app's GoRouter instance with auth-based redirects.
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<RouterConfig<Object>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RouterConfig<Object> create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RouterConfig<Object> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RouterConfig<Object>>(value),
    );
  }
}

String _$appRouterHash() => r'6e9ffd04eab2eccf7cb195c2c52a90d488db15c6';
