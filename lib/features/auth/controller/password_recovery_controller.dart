import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';

part 'password_recovery_controller.g.dart';

@riverpod
class PasswordRecoveryController extends _$PasswordRecoveryController {
  @override
  FutureOr<void> build() {
    ref.watch(passwordRecoveryRepositoryProvider);
  }

  Future<bool> sendCode(String email) => _perform(
    () => ref.read(passwordRecoveryRepositoryProvider).sendCode(email),
  );

  Future<bool> verifyCode(String email, String code) => _perform(
    () => ref.read(passwordRecoveryRepositoryProvider).verifyCode(email, code),
  );

  Future<bool> resetPassword(String password) => _perform(
    () => ref.read(passwordRecoveryRepositoryProvider).resetPassword(password),
  );

  void clearError() => state = const AsyncValue.data(null);

  Future<bool> _perform(Future<Result<void>> Function() operation) async {
    if (state.isLoading) return false;
    state = const AsyncValue.loading();
    final result = await operation();
    if (!ref.mounted) return false;
    switch (result) {
      case Success():
        state = const AsyncValue.data(null);
        return true;
      case Failure(error: final failure):
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
    }
  }
}
