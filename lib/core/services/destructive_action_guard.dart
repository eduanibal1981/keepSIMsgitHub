import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

/// The token the owner has to type when the device has no lock enrolled.
///
/// Last four digits of the number being deleted, so the prompt is answerable
/// from the number already on screen. Numbers with fewer than four digits use
/// whatever digits they carry; a number with none falls back to a literal word.
String destructiveConfirmationToken(String phoneNumber) {
  final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 'DELETE';
  if (digits.length <= 4) return digits;
  return digits.substring(digits.length - 4);
}

/// Confirmation gate for irreversible, non-payment actions.
///
/// Deliberately NOT [PaymentAuthGuard]. That guard suppresses its prompt for 60
/// seconds after any successful auth, so a refill followed by a mistaken delete
/// tap would destroy the line without prompting at all — exactly the accident
/// this gate exists to stop. A destructive action prompts every single time.
class DestructiveActionGuard {
  final BiometricAuthService _service;

  DestructiveActionGuard(this._service);

  /// Returns true only when the owner actively confirmed.
  ///
  /// Prompts for biometrics or the device credential. When the device has no
  /// lock enrolled at all the OS has no credential to check
  /// ([BiometricResult.unavailable]), so this falls back to typing
  /// [confirmationToken] rather than passing silently — friction that a stray
  /// tap will not clear. There is no path that returns true without the person
  /// holding the phone doing something deliberate.
  Future<bool> confirmDestructiveAction(
    BuildContext context, {
    required String reason,
    required String confirmationToken,
  }) async {
    final result = await _service.authenticate(reason: reason);

    if (result == BiometricResult.success) {
      return true;
    }

    // cancelled / failed / lockedOut are all refusals.
    if (result != BiometricResult.unavailable) {
      return false;
    }

    if (!context.mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TypedConfirmationDialog(token: confirmationToken),
    );
    return confirmed ?? false;
  }
}

/// Fallback prompt shown only when the device has no biometric or screen lock.
class _TypedConfirmationDialog extends StatefulWidget {
  final String token;

  const _TypedConfirmationDialog({required this.token});

  @override
  State<_TypedConfirmationDialog> createState() =>
      _TypedConfirmationDialogState();
}

class _TypedConfirmationDialogState extends State<_TypedConfirmationDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final matches = _controller.text.trim().toUpperCase() ==
          widget.token.toUpperCase();
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
    final l10n = AppLocalizations.of(context)!;
    final isNumeric = int.tryParse(widget.token) != null;

    return AlertDialog(
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: context.dividerColor),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.confirmDeletionTitle,
              style: AppTextStyles.headlineSmall.copyWith(
                color: context.onSurfaceColor,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.noDeviceLockConfirmBody(widget.token),
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.onSurfaceColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            inputFormatters: isNumeric
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            maxLength: widget.token.length,
            style: AppTextStyles.bodyLarge.copyWith(
              color: context.onSurfaceColor,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: l10n.typeToConfirmHint(widget.token),
              hintStyle: AppTextStyles.bodyLarge.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.3),
                letterSpacing: 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            l10n.cancel,
            style: TextStyle(
              color: context.onSurfaceColor.withValues(alpha: 0.6),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            disabledBackgroundColor: AppColors.error.withValues(alpha: 0.3),
          ),
          child: Text(
            l10n.deleteButton,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Riverpod provider for [DestructiveActionGuard].
///
/// No lifecycle observer, unlike [paymentAuthGuardProvider] — there is no grace
/// window to clear because the guard never caches a successful auth.
final destructiveActionGuardProvider = Provider<DestructiveActionGuard>((ref) {
  return DestructiveActionGuard(ref.watch(biometricAuthServiceProvider));
});
