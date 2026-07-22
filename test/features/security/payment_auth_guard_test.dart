import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'fake_biometric_auth_service.dart';

void main() {
  group('PaymentAuthGuard Tests', () {
    late FakeBiometricAuthService fakeService;
    late PaymentAuthGuard guard;

    setUp(() {
      fakeService = FakeBiometricAuthService(isAvailable: true);
      guard = PaymentAuthGuard(fakeService);
    });

    test('returns success when authentication succeeds', () async {
      fakeService.nextResult = BiometricResult.success;
      final res = await guard.confirmPayment(reason: 'Test payment');
      expect(res, BiometricResult.success);
      expect(fakeService.authCount, 1);
    });

    test('returns unavailable when device lacks biometrics', () async {
      fakeService.isAvailable = false;
      final res = await guard.confirmPayment(reason: 'Test payment');
      expect(res, BiometricResult.unavailable);
      expect(fakeService.authCount, 0);
    });

    test('returns cancelled when user cancels prompt', () async {
      fakeService.nextResult = BiometricResult.cancelled;
      final res = await guard.confirmPayment(reason: 'Test payment');
      expect(res, BiometricResult.cancelled);
      expect(fakeService.authCount, 1);
    });

    test('returns lockedOut when biometrics are locked', () async {
      fakeService.nextResult = BiometricResult.lockedOut;
      final res = await guard.confirmPayment(reason: 'Test payment');
      expect(res, BiometricResult.lockedOut);
      expect(fakeService.authCount, 1);
    });

    test('enforces 60-second grace window on consecutive auths', () async {
      fakeService.nextResult = BiometricResult.success;

      final res1 = await guard.confirmPayment(reason: 'First payment');
      expect(res1, BiometricResult.success);
      expect(fakeService.authCount, 1);

      // Second payment within grace window should skip prompt
      final res2 = await guard.confirmPayment(reason: 'Second payment');
      expect(res2, BiometricResult.success);
      expect(fakeService.authCount, 1); // Not incremented

      // Clearing grace window requires prompt again
      guard.clearGraceWindow();
      final res3 = await guard.confirmPayment(reason: 'Third payment');
      expect(res3, BiometricResult.success);
      expect(fakeService.authCount, 2);
    });
  });
}
