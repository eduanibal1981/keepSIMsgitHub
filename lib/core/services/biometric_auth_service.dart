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
  /// without enrolled fingerprint), displays an interactive confirmation dialog.
  /// If [confirmationToken] is provided, requires typing the token (e.g. last 4 digits of SIM).
  Future<bool> confirmPaymentInteractive(
    BuildContext context, {
    required String reason,
    String? confirmationToken,
    Duration gracePeriod = const Duration(seconds: 60),
  }) async {
    final result = await confirmPayment(reason: reason, gracePeriod: gracePeriod);

    if (result == BiometricResult.success) {
      return true;
    }

    if (result == BiometricResult.unavailable) {
      if (!context.mounted) return false;

      if (confirmationToken != null && confirmationToken.isNotEmpty) {
        final approved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _TypedPaymentConfirmationDialog(
            reason: reason,
            token: confirmationToken,
            onAuthorized: () {
              _lastSuccessfulPaymentAuth = DateTime.now();
            },
          ),
        );
        return approved ?? false;
      }

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

/// Typed confirmation dialog shown when biometrics are unavailable and a specific confirmation token (e.g. last 4 digits of SIM) is required.
class _TypedPaymentConfirmationDialog extends StatefulWidget {
  final String reason;
  final String token;
  final VoidCallback onAuthorized;

  const _TypedPaymentConfirmationDialog({
    required this.reason,
    required this.token,
    required this.onAuthorized,
  });

  @override
  State<_TypedPaymentConfirmationDialog> createState() => _TypedPaymentConfirmationDialogState();
}

class _TypedPaymentConfirmationDialogState extends State<_TypedPaymentConfirmationDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final matches = _controller.text.trim().toUpperCase() == widget.token.toUpperCase();
      if (matches != _matches) {
        setState(() => _matches = matches);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNumeric = int.tryParse(widget.token) != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF0070BA), size: 28),
          SizedBox(width: 10),
          Text('Security Confirmation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.reason, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0070BA).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF0070BA).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.pin_outlined, color: Color(0xFF0070BA), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Biometrics unavailable. Type "${widget.token}" (last digits of SIM) to authorize.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0070BA), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            inputFormatters: isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null,
            maxLength: widget.token.length,
            style: const TextStyle(fontSize: 18, letterSpacing: 4, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              hintText: widget.token,
              hintStyle: TextStyle(fontSize: 18, letterSpacing: 4, color: Colors.grey.withValues(alpha: 0.5)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0070BA), width: 2),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0070BA),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _matches
              ? () {
                  widget.onAuthorized();
                  Navigator.pop(context, true);
                }
              : null,
          child: const Text('Confirm Payment'),
        ),
      ],
    );
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
