// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appRouterHash() => r'57eb23a44eb7a01671f7683fedb63e48b04c3526';

/// Provides the app's GoRouter instance with auth-based redirects.
///
/// Copied from [appRouter].
@ProviderFor(appRouter)
final appRouterProvider = AutoDisposeProvider<GoRouter>.internal(
  appRouter,
  name: r'appRouterProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appRouterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppRouterRef = AutoDisposeProviderRef<GoRouter>;
String _$splashCompletedHash() => r'e7593a4ebf31d2994b23da76b399932fbf19c1e7';

/// See also [SplashCompleted].
@ProviderFor(SplashCompleted)
final splashCompletedProvider =
    AutoDisposeNotifierProvider<SplashCompleted, bool>.internal(
      SplashCompleted.new,
      name: r'splashCompletedProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$splashCompletedHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SplashCompleted = AutoDisposeNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
