// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'password_recovery_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PasswordRecoveryController)
final passwordRecoveryControllerProvider =
    PasswordRecoveryControllerProvider._();

final class PasswordRecoveryControllerProvider
    extends $AsyncNotifierProvider<PasswordRecoveryController, void> {
  PasswordRecoveryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'passwordRecoveryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$passwordRecoveryControllerHash();

  @$internal
  @override
  PasswordRecoveryController create() => PasswordRecoveryController();
}

String _$passwordRecoveryControllerHash() =>
    r'c4630278d2b06a32cf4da5b679218c50fa4eaa12';

abstract class _$PasswordRecoveryController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
