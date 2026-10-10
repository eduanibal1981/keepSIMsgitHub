import 'package:keep_sims/core/result.dart';

abstract interface class PasswordRecoveryContract {
  Future<Result<void>> sendCode(String email);
  Future<Result<void>> verifyCode(String email, String code);
  Future<Result<void>> resetPassword(String password);
}
