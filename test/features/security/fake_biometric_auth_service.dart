import 'package:keep_sims/core/services/biometric_auth_service.dart';

class FakeBiometricAuthService implements BiometricAuthService {
  bool isAvailable;
  BiometricResult nextResult;
  int authCount = 0;
  String? lastReason;

  FakeBiometricAuthService({
    this.isAvailable = true,
    this.nextResult = BiometricResult.success,
  });

  @override
  Future<bool> isBiometricAvailable() async {
    return isAvailable;
  }

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    authCount++;
    lastReason = reason;
    return nextResult;
  }
}
