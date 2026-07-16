// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the current auth state as an [AsyncValue<UserProfile?>].
///
/// - `AsyncData(profile)` → user is signed in
/// - `AsyncData(null)` → user is not signed in
/// - `AsyncLoading` → checking auth state
/// - `AsyncError` → something went wrong

@ProviderFor(AuthController)
final authControllerProvider = AuthControllerProvider._();

/// Provides the current auth state as an [AsyncValue<UserProfile?>].
///
/// - `AsyncData(profile)` → user is signed in
/// - `AsyncData(null)` → user is not signed in
/// - `AsyncLoading` → checking auth state
/// - `AsyncError` → something went wrong
final class AuthControllerProvider
    extends $AsyncNotifierProvider<AuthController, UserProfile?> {
  /// Provides the current auth state as an [AsyncValue<UserProfile?>].
  ///
  /// - `AsyncData(profile)` → user is signed in
  /// - `AsyncData(null)` → user is not signed in
  /// - `AsyncLoading` → checking auth state
  /// - `AsyncError` → something went wrong
  AuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authControllerHash();

  @$internal
  @override
  AuthController create() => AuthController();
}

String _$authControllerHash() => r'2a294e1a4f7195343f1a79271425edc62542646c';

/// Provides the current auth state as an [AsyncValue<UserProfile?>].
///
/// - `AsyncData(profile)` → user is signed in
/// - `AsyncData(null)` → user is not signed in
/// - `AsyncLoading` → checking auth state
/// - `AsyncError` → something went wrong

abstract class _$AuthController extends $AsyncNotifier<UserProfile?> {
  FutureOr<UserProfile?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<UserProfile?>, UserProfile?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UserProfile?>, UserProfile?>,
              AsyncValue<UserProfile?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
