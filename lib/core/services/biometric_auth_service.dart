import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Typed outcomes of a biometric authentication attempt.
enum BiometricResult {
  /// Prompt completed successfully.
  success,

  /// Device lacks biometric/credential hardware or nothing is enrolled.
  /// Callers should proceed silently (mandatory-if-enrolled behavior).
  unavailable,

  /// User explicitly cancelled or dismissed the OS prompt.
  cancelled,

  /// Authentication failed (e.g. non-matching fingerprint/face attempt).
  failed,

  /// OS locked biometrics due to too many failed attempts.
  lockedOut,
}

/// Abstract contract for biometric operations.
abstract class BiometricAuthService {
  /// Checks whether biometric or device credential authentication is available and enrolled.
  Future<bool> isBiometricAvailable();

  /// Prompts the user with the OS biometric / passcode dialog.
  Future<BiometricResult> authenticate({required String reason});
}

/// Real implementation wrapping [LocalAuthentication].
class LocalAuthBiometricServiceImpl implements BiometricAuthService {
  final LocalAuthentication _auth;

  LocalAuthBiometricServiceImpl({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    final available = await isBiometricAvailable();
    if (!available) {
      return BiometricResult.unavailable;
    }

    try {
      final success = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      return success ? BiometricResult.success : BiometricResult.cancelled;
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      if (code.contains('lockout') || code.contains('permanentlylockedout')) {
        return BiometricResult.lockedOut;
      } else if (code.contains('notavailable') ||
          code.contains('notenrolled') ||
          code.contains('passcodenotset')) {
        return BiometricResult.unavailable;
      }
      return BiometricResult.failed;
    } catch (_) {
      return BiometricResult.failed;
    }
  }
}

/// Guard for user-initiated payments with an in-memory grace window.
class PaymentAuthGuard {
  final BiometricAuthService _service;
  DateTime? _lastSuccessfulPaymentAuth;

  PaymentAuthGuard(this._service);

  /// Resets the grace window timestamp.
  void clearGraceWindow() {
    _lastSuccessfulPaymentAuth = null;
  }

  /// Confirms a payment transaction using biometric authentication if enrolled.
  ///
  /// Suppresses prompt if a successful auth occurred within the [gracePeriod] (default: 60s).
  Future<BiometricResult> confirmPayment({
    required String reason,
    Duration gracePeriod = const Duration(seconds: 60),
  }) async {
    if (_lastSuccessfulPaymentAuth != null) {
      final elapsed = DateTime.now().difference(_lastSuccessfulPaymentAuth!);
      if (elapsed < gracePeriod) {
        return BiometricResult.success;
      }
    }

    final available = await _service.isBiometricAvailable();
    if (!available) {
      return BiometricResult.unavailable;
    }

    final result = await _service.authenticate(reason: reason);
    if (result == BiometricResult.success) {
      _lastSuccessfulPaymentAuth = DateTime.now();
    }
    return result;
  }
}

/// Riverpod provider for [BiometricAuthService].
final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return LocalAuthBiometricServiceImpl();
});

/// Riverpod provider for [PaymentAuthGuard] (kept alive across screens for grace period).
final paymentAuthGuardProvider = Provider<PaymentAuthGuard>((ref) {
  final service = ref.watch(biometricAuthServiceProvider);
  final guard = PaymentAuthGuard(service);

  final binding = WidgetsBinding.instance;
  try {
    final observer = _PaymentAuthGuardLifecycleObserver(guard);
    binding.addObserver(observer);
    ref.onDispose(() => binding.removeObserver(observer));
  } catch (_) {
    // WidgetsBinding not initialized in unit tests
  }

  return guard;
});

class _PaymentAuthGuardLifecycleObserver extends WidgetsBindingObserver {
  final PaymentAuthGuard _guard;
  _PaymentAuthGuardLifecycleObserver(this._guard);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _guard.clearGraceWindow();
    }
  }
}
