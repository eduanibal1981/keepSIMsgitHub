import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';

const String kBiometricLockStorageKey = 'app_lock_biometric_enabled';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

class BiometricLockController extends Notifier<AsyncValue<bool>> {
  @override
  AsyncValue<bool> build() {
    _init();
    return const AsyncValue.loading();
  }

  Future<void> _init() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final val = await storage.read(key: kBiometricLockStorageKey);
      state = AsyncValue.data(val == 'true');
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Toggles the app-open lock.
  ///
  /// Enabling requires a successful biometric authentication before persisting.
  Future<bool> setLockEnabled(bool enable, {required String reason}) async {
    final storage = ref.read(secureStorageProvider);
    final biometricService = ref.read(biometricAuthServiceProvider);

    if (!enable) {
      await storage.write(key: kBiometricLockStorageKey, value: 'false');
      state = const AsyncValue.data(false);
      return true;
    }

    final isAvailable = await biometricService.isBiometricAvailable();
    if (!isAvailable) {
      await storage.write(key: kBiometricLockStorageKey, value: 'true');
      state = const AsyncValue.data(true);
      return true;
    }

    final authResult = await biometricService.authenticate(reason: reason);
    if (authResult == BiometricResult.success ||
        authResult == BiometricResult.unavailable) {
      await storage.write(key: kBiometricLockStorageKey, value: 'true');
      state = const AsyncValue.data(true);
      return true;
    }

    return false;
  }
}

final biometricLockControllerProvider =
    NotifierProvider<BiometricLockController, AsyncValue<bool>>(
  BiometricLockController.new,
);
