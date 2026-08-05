import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Confirms payment interactively. If biometrics are unavailable (e.g. on emulator
  /// without enrolled fingerprint), displays an interactive mock authorization dialog
  /// so developers/testers can authorize actions explicitly.
  Future<bool> confirmPaymentInteractive(
    BuildContext context, {
    required String reason,
    Duration gracePeriod = const Duration(seconds: 60),
  }) async {
    final result = await confirmPayment(reason: reason, gracePeriod: gracePeriod);

    if (result == BiometricResult.success) {
      return true;
    }

    if (result == BiometricResult.unavailable) {
      final approved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.fingerprint_rounded, color: Color(0xFF0070BA), size: 28),
              SizedBox(width: 10),
              Text('Security Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reason, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0070BA).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF0070BA).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.developer_mode_rounded, color: Color(0xFF0070BA), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Device biometrics unavailable (Emulator Mode). Press Authorize to confirm.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF0070BA), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0070BA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _lastSuccessfulPaymentAuth = DateTime.now();
                Navigator.pop(ctx, true);
              },
              child: const Text('Authorize Payment'),
            ),
          ],
        ),
      );
      return approved ?? false;
    }

    return false;
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
