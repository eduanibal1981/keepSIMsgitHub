import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';

/// Hashes a 4-digit transaction PIN using the app salt.
String hashTransactionPin(String pin) {
  final bytes = utf8.encode('${pin}SIM_SHIELD_SALT_2026');
  var hash = 0;
  for (var byte in bytes) {
    hash = (hash * 31 + byte) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16);
}

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

  /// Confirms payment interactively.
  /// 1. If [transactionPinHash] is set, prompts for the 4-digit Transaction PIN
  ///    (with optional biometric shortcut if [biometricEnabled]).
  /// 2. If no PIN is set, but [biometricEnabled] is true, prompts OS biometrics.
  /// 3. If neither PIN nor biometric is configured (or biometric is unavailable/fails),
  ///    falls back to typing [confirmationToken] (e.g. last 4 digits of SIM phone number).
  Future<bool> confirmPaymentInteractive(
    BuildContext context, {
    required String reason,
    String? confirmationToken,
    String? transactionPinHash,
    bool biometricEnabled = true,
    Widget? amountPreview,
    Duration gracePeriod = const Duration(seconds: 60),
  }) async {
    if (_lastSuccessfulPaymentAuth != null) {
      final elapsed = DateTime.now().difference(_lastSuccessfulPaymentAuth!);
      if (elapsed < gracePeriod) {
        return true;
      }
    }

    if (!context.mounted) return false;

    // 1. If user configured a Transaction PIN
    if (transactionPinHash != null && transactionPinHash.isNotEmpty) {
      final isBioAvailable =
          biometricEnabled && await _service.isBiometricAvailable();

      if (!context.mounted) return false;

      final pinResult = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _PinPaymentConfirmationSheet(
          reason: reason,
          expectedPinHash: transactionPinHash,
          amountPreview: amountPreview,
          isBiometricAvailable: isBioAvailable,
          onBiometricRequested: isBioAvailable
              ? () async {
                  final bioResult = await _service.authenticate(reason: reason);
                  return bioResult == BiometricResult.success;
                }
              : null,
        ),
      );

      if (pinResult == true) {
        _lastSuccessfulPaymentAuth = DateTime.now();
        return true;
      }
      return false;
    }

    // 2. If user has Biometric Security enabled (and no PIN set)
    if (biometricEnabled) {
      final isBioAvailable = await _service.isBiometricAvailable();
      if (isBioAvailable) {
        final result = await _service.authenticate(reason: reason);
        if (result == BiometricResult.success) {
          _lastSuccessfulPaymentAuth = DateTime.now();
          return true;
        } else if (result == BiometricResult.cancelled ||
            result == BiometricResult.lockedOut) {
          return false;
        }
        // If unavailable or failed, fallback to confirmationToken below
      }
    }

    // 3. Fallback: If no Transaction PIN and no Biometric (or biometric unavailable/failed)
    // require typing the last 4 digits of the phone number
    if (confirmationToken != null && confirmationToken.isNotEmpty) {
      if (!context.mounted) return false;

      final approved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _TypedPaymentConfirmationDialog(
          reason: reason,
          token: confirmationToken,
          amountPreview: amountPreview,
          onAuthorized: () {
            _lastSuccessfulPaymentAuth = DateTime.now();
          },
        ),
      );
      return approved ?? false;
    }

    return false;
  }
}

/// Bottom sheet prompt for verifying the 4-digit Transaction PIN.
class _PinPaymentConfirmationSheet extends StatefulWidget {
  final String reason;
  final String expectedPinHash;
  final Widget? amountPreview;
  final bool isBiometricAvailable;
  final Future<bool> Function()? onBiometricRequested;

  const _PinPaymentConfirmationSheet({
    required this.reason,
    required this.expectedPinHash,
    this.amountPreview,
    this.isBiometricAvailable = false,
    this.onBiometricRequested,
  });

  @override
  State<_PinPaymentConfirmationSheet> createState() =>
      _PinPaymentConfirmationSheetState();
}

class _PinPaymentConfirmationSheetState
    extends State<_PinPaymentConfirmationSheet> {
  String _pinInput = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.isBiometricAvailable && widget.onBiometricRequested != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleBiometric();
      });
    }
  }

  void _onKeypadTap(String val) {
    if (_pinInput.length >= 4) return;
    setState(() {
      _pinInput += val;
      _errorMessage = '';
    });
    _checkPin();
  }

  void _onBackspace() {
    if (_pinInput.isEmpty) return;
    setState(() {
      _pinInput = _pinInput.substring(0, _pinInput.length - 1);
      _errorMessage = '';
    });
  }

  void _checkPin() {
    if (_pinInput.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), () async {
        if (!mounted) return;
        final hashed = hashTransactionPin(_pinInput);
        if (hashed == widget.expectedPinHash) {
          await HapticHelper.successFeedback();
          if (mounted) Navigator.pop(context, true);
        } else {
          await HapticHelper.errorFeedback();
          if (mounted) {
            setState(() {
              _pinInput = '';
              _errorMessage = 'Incorrect PIN. Please try again.';
            });
          }
        }
      });
    }
  }

  Future<void> _handleBiometric() async {
    if (widget.onBiometricRequested == null) return;
    await HapticHelper.lightTick();
    final ok = await widget.onBiometricRequested!();
    if (ok && mounted) {
      await HapticHelper.successFeedback();
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final sheetBg = isDark
        ? const Color(0xFF0F172A)
        : context.scaffoldBackgroundColor;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: context.onSurfaceColor.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: context.onSurfaceColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 20),

            // Header Row with Lock and Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD946EF).withValues(alpha: 0.1),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lock_outline_rounded,
                        color: Color(0xFFD946EF),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaction PIN',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: context.onSurfaceColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.reason,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: context.onSurfaceColor.withValues(
                              alpha: 0.65,
                            ),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: context.onSurfaceColor.withValues(alpha: 0.6),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),

            if (widget.amountPreview != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: widget.amountPreview!,
              ),
            ],

            const SizedBox(height: 24),

            // 4 Circle Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isEntered = index < _pinInput.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEntered
                        ? const Color(0xFFD946EF)
                        : Colors.transparent,
                    border: Border.all(
                      color: isEntered
                          ? const Color(0xFFD946EF)
                          : context.onSurfaceColor.withValues(alpha: 0.25),
                      width: 2,
                    ),
                    boxShadow: isEntered
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFFD946EF,
                              ).withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),

            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ] else
              const SizedBox(height: 14),

            const SizedBox(height: 10),

            // Keypad container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : context.onSurfaceColor.withValues(alpha: 0.03),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(
                    color: context.onSurfaceColor.withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  for (var row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                  ]) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: row.map((val) {
                        return _buildKeypadBtn(val, () => _onKeypadTap(val));
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (widget.onBiometricRequested != null)
                        _buildKeypadBtn(
                          'biometric',
                          _handleBiometric,
                          icon: Icons.fingerprint_rounded,
                          isAction: true,
                        )
                      else
                        const SizedBox(width: 68, height: 68),
                      _buildKeypadBtn('0', () => _onKeypadTap('0')),
                      _buildKeypadBtn(
                        '⌫',
                        _onBackspace,
                        icon: Icons.backspace_outlined,
                        isAction: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadBtn(
    String label,
    VoidCallback onTap, {
    IconData? icon,
    bool isAction = false,
  }) {
    final isDark = context.isDarkMode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await HapticHelper.lightTick();
          onTap();
        },
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isAction
                ? context.onSurfaceColor.withValues(alpha: 0.04)
                : (isDark
                      ? context.onSurfaceColor.withValues(alpha: 0.08)
                      : context.cardColor),
            boxShadow: (!isAction && !isDark)
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
            border: Border.all(
              color: isAction
                  ? Colors.transparent
                  : context.onSurfaceColor.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, size: 24, color: const Color(0xFFD946EF))
                : Text(
                    label,
                    style: TextStyle(
                      color: context.onSurfaceColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Typed confirmation dialog shown when biometrics and PIN are unavailable and
/// a specific confirmation token (e.g. last 4 digits of SIM) is required.
class _TypedPaymentConfirmationDialog extends StatefulWidget {
  final String reason;
  final String token;
  final Widget? amountPreview;
  final VoidCallback onAuthorized;

  const _TypedPaymentConfirmationDialog({
    required this.reason,
    required this.token,
    this.amountPreview,
    required this.onAuthorized,
  });

  @override
  State<_TypedPaymentConfirmationDialog> createState() =>
      _TypedPaymentConfirmationDialogState();
}

class _TypedPaymentConfirmationDialogState
    extends State<_TypedPaymentConfirmationDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final matches =
          _controller.text.trim().toUpperCase() == widget.token.toUpperCase();
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
      backgroundColor: context.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Security Confirmation',
            style: AppTextStyles.titleMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.reason,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.onSurfaceColor.withValues(alpha: 0.75),
            ),
          ),
          if (widget.amountPreview != null) widget.amountPreview!,
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.pin_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'To confirm, please enter the last 4 digits of the phone number (${widget.token}).',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            inputFormatters: isNumeric
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            maxLength: widget.token.length,
            style: TextStyle(
              fontSize: 22,
              letterSpacing: 6,
              fontWeight: FontWeight.bold,
              color: context.onSurfaceColor,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              hintStyle: TextStyle(
                fontSize: 22,
                letterSpacing: 6,
                color: context.onSurfaceColor.withValues(alpha: 0.3),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: context.onSurfaceColor.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: context.onSurfaceColor.withValues(alpha: 0.7),
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: _matches
              ? () {
                  widget.onAuthorized();
                  Navigator.pop(context, true);
                }
              : null,
          child: const Text(
            'Confirm Refill',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _guard.clearGraceWindow();
    }
  }
}
