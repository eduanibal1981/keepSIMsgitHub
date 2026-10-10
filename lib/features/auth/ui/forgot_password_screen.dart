import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import '../controller/password_recovery_controller.dart';

enum _RecoveryStep { email, code, password, complete }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _RecoveryStep _step = _RecoveryStep.email;
  bool _showPassword = false;
  Timer? _resendTimer;
  int _resendCooldown = 0;

  bool get _busy => ref.read(passwordRecoveryControllerProvider).isLoading;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _clearErrorIfAny() {
    if (ref.read(passwordRecoveryControllerProvider).hasError) {
      ref.read(passwordRecoveryControllerProvider.notifier).clearError();
    }
  }

  void _startCooldown() {
    _resendTimer?.cancel();
    _resendCooldown = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendCooldown--);
      if (_resendCooldown == 0) timer.cancel();
    });
  }

  Future<void> _submit({bool resend = false}) async {
    if (_busy || (!resend && !(_formKey.currentState?.validate() ?? false))) {
      return;
    }
    FocusScope.of(context).unfocus();
    final controller = ref.read(passwordRecoveryControllerProvider.notifier);
    final email = _emailController.text.trim();
    final sendingCode = resend || _step == _RecoveryStep.email;
    final success = sendingCode
        ? await controller.sendCode(email)
        : _step == _RecoveryStep.code
        ? await controller.verifyCode(email, _codeController.text.trim())
        : await controller.resetPassword(_passwordController.text);
    if (!mounted || !success) return;
    setState(() {
      if (sendingCode) {
        _codeController.clear();
        _step = _RecoveryStep.code;
        _startCooldown();
      } else if (_step == _RecoveryStep.code) {
        _resendTimer?.cancel();
        _step = _RecoveryStep.password;
      } else {
        _passwordController.clear();
        _confirmController.clear();
        _step = _RecoveryStep.complete;
      }
    });
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    final recoveryState = ref.watch(passwordRecoveryControllerProvider);
    final error = recoveryState.error?.toString();
    final secondary = context.isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final title = switch (_step) {
      _RecoveryStep.email => 'Forgot password?',
      _RecoveryStep.code => 'Check your email',
      _RecoveryStep.password => 'Set a new password',
      _RecoveryStep.complete => 'Password reset',
    };
    final subtitle = switch (_step) {
      _RecoveryStep.email =>
        'Enter your account email to receive a reset code.',
      _RecoveryStep.code =>
        'If an account exists for ${_emailController.text.trim()}, you will receive a reset code. Check your inbox and spam folder.',
      _RecoveryStep.password =>
        'Your email is verified. Choose a password with at least 8 characters.',
      _RecoveryStep.complete =>
        'Your password has been updated. Sign in with your new password.',
    };
    final buttonLabel = switch (_step) {
      _RecoveryStep.email =>
        _resendCooldown > 0
            ? 'Send code in ${_resendCooldown}s'
            : 'Send reset code',
      _RecoveryStep.code => 'Verify code',
      _RecoveryStep.password => 'Reset password',
      _RecoveryStep.complete => 'Back to sign in',
    };

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: context.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back to sign in',
            onPressed: _busy
                ? null
                : () => context.go(
                    AppRoutes.emailAuth,
                    extra: _emailController.text.trim(),
                  ),
            icon: Icon(Icons.arrow_back, color: context.onSurfaceColor),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _step == _RecoveryStep.complete
                        ? Icons.check_circle_outline
                        : _step == _RecoveryStep.code
                        ? Icons.mark_email_read_outlined
                        : Icons.lock_reset,
                    size: 80,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.displayLarge.copyWith(
                      color: context.onSurfaceColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLarge.copyWith(color: secondary),
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: Column(
                      key: ValueKey(_step),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_step == _RecoveryStep.email)
                          TextFormField(
                            key: const ValueKey('recovery-email'),
                            controller: _emailController,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            onChanged: (_) => _clearErrorIfAny(),
                            decoration: _decoration(
                              'Email',
                              Icons.email_outlined,
                            ),
                            validator: (value) =>
                                RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(value?.trim() ?? '')
                                ? null
                                : 'Enter a valid email address',
                            onFieldSubmitted: (_) {
                              if (_resendCooldown == 0) _submit();
                            },
                          ),
                        if (_step == _RecoveryStep.code)
                          TextFormField(
                            key: const ValueKey('recovery-code'),
                            controller: _codeController,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            maxLength: 8,
                            textAlign: TextAlign.center,
                            onChanged: (_) => _clearErrorIfAny(),
                            decoration: _decoration(
                              'Reset code',
                              Icons.password_outlined,
                            ),
                            validator: (value) =>
                                RegExp(
                                  r'^\d{6,8}$',
                                ).hasMatch(value?.trim() ?? '')
                                ? null
                                : 'Enter the 6 to 8 digit code from your email',
                            onFieldSubmitted: (_) => _submit(),
                          ),
                        if (_step == _RecoveryStep.password) ...[
                          TextFormField(
                            key: const ValueKey('recovery-password'),
                            controller: _passwordController,
                            enabled: !_busy,
                            obscureText: !_showPassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            onChanged: (_) => _clearErrorIfAny(),
                            decoration:
                                _decoration(
                                  'New password',
                                  Icons.lock_outline,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    tooltip: _showPassword
                                        ? 'Hide password'
                                        : 'Show password',
                                    onPressed: () => setState(
                                      () => _showPassword = !_showPassword,
                                    ),
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                            validator: (value) => (value?.length ?? 0) >= 8
                                ? null
                                : 'Use at least 8 characters',
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).nextFocus(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const ValueKey('recovery-confirm-password'),
                            controller: _confirmController,
                            enabled: !_busy,
                            obscureText: !_showPassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            onChanged: (_) => _clearErrorIfAny(),
                            decoration:
                                _decoration(
                                  'Confirm password',
                                  Icons.lock_outline,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    tooltip: _showPassword
                                        ? 'Hide password'
                                        : 'Show password',
                                    onPressed: () => setState(
                                      () => _showPassword = !_showPassword,
                                    ),
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                            validator: (value) =>
                                value == _passwordController.text
                                ? null
                                : 'Passwords do not match',
                            onFieldSubmitted: (_) => _submit(),
                          ),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              error,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed:
                                _busy ||
                                    (_step == _RecoveryStep.email &&
                                        _resendCooldown > 0)
                                ? null
                                : _step == _RecoveryStep.complete
                                ? () => context.go(
                                    AppRoutes.emailAuth,
                                    extra: _emailController.text.trim(),
                                  )
                                : () => _submit(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    buttonLabel,
                                    style: AppTextStyles.titleMedium.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        if (_step == _RecoveryStep.code) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _busy || _resendCooldown > 0
                                ? null
                                : () => _submit(resend: true),
                            child: Text(
                              _resendCooldown > 0
                                  ? 'Resend code in ${_resendCooldown}s'
                                  : 'Resend code',
                            ),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _step = _RecoveryStep.email;
                                    _resendTimer?.cancel();
                                    _resendCooldown = 0;
                                    _codeController.clear();
                                    ref
                                        .read(
                                          passwordRecoveryControllerProvider
                                              .notifier,
                                        )
                                        .clearError();
                                  }),
                            child: const Text('Use a different email'),
                          ),
                        ],
                        if (_step == _RecoveryStep.password)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _step = _RecoveryStep.email;
                                    _resendTimer?.cancel();
                                    _resendCooldown = 0;
                                    _codeController.clear();
                                    _passwordController.clear();
                                    _confirmController.clear();
                                    ref
                                        .read(
                                          passwordRecoveryControllerProvider
                                              .notifier,
                                        )
                                        .clearError();
                                  }),
                            child: const Text('Request a new code'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
