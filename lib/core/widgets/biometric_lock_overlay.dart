import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/core/services/biometric_lock_controller.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/voip_calling_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class BiometricLockOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const BiometricLockOverlay({super.key, required this.child});

  @override
  ConsumerState<BiometricLockOverlay> createState() =>
      _BiometricLockOverlayState();
}

class _BiometricLockOverlayState extends ConsumerState<BiometricLockOverlay>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initial check on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialLockState();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final lockEnabled =
          ref.read(biometricLockControllerProvider).value ?? false;
      if (lockEnabled) {
        setState(() {
          _isLocked = true;
          _errorMessage = null;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isLocked && !_isAuthenticating) {
        _triggerAuthentication();
      }
    }
  }

  void _checkInitialLockState() {
    final lockEnabled =
        ref.read(biometricLockControllerProvider).value ?? false;
    if (lockEnabled) {
      setState(() {
        _isLocked = true;
      });
      _triggerAuthentication();
    }
  }

  Future<void> _triggerAuthentication() async {
    if (_isAuthenticating || !_isLocked) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final service = ref.read(biometricAuthServiceProvider);
    final l = AppLocalizations.of(context);
    final reason = l?.biometricReasonUnlock ?? 'Authenticate to unlock KeepSIMs';

    final result = await service.authenticate(reason: reason);

    if (!mounted) return;

    setState(() {
      _isAuthenticating = false;
    });

    switch (result) {
      case BiometricResult.success:
      case BiometricResult.unavailable:
        setState(() {
          _isLocked = false;
          _errorMessage = null;
        });
      case BiometricResult.cancelled:
      case BiometricResult.failed:
        setState(() {
          _isLocked = true;
        });
      case BiometricResult.lockedOut:
        setState(() {
          _isLocked = true;
          _errorMessage = l?.biometricLockout ??
              'Biometric authentication locked due to too many failed attempts. Please use your device passcode to unlock.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(biometricLockControllerProvider);
    final isLockEnabled = lockState.value ?? false;

    // Do NOT lock or obscure the screen if an incoming or active VoIP call is in progress
    final voipState = ref.watch(voipCallingControllerProvider);
    if (voipState.isActive) {
      return widget.child;
    }

    // React if lock state changes while app is active (e.g. initial load)
    if (isLockEnabled && !_isLocked && lockState.isLoading) {
      // Keep opaque while checking initial lock setting to avoid content flash
    }

    return Stack(
      children: [
        widget.child,
        if (_isLocked && isLockEnabled)
          Positioned.fill(
            child: Material(
              color: const Color(0xFF0B1622),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF101E30),
                          border: Border.all(color: const Color(0xFF26374F)),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          size: 40,
                          color: Color(0xFF34D399),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        AppLocalizations.of(context)?.biometricAppLockTitle ??
                            'KeepSIMs is Locked',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEEF2F6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)?.biometricReasonUnlock ??
                            'Authenticate to unlock KeepSIMs',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8FA1B8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x24F2545B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFF2545B).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFF2545B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isAuthenticating
                              ? null
                              : () => _triggerAuthentication(),
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: Text(
                            AppLocalizations.of(context)
                                    ?.biometricUnlockButton ??
                                'Unlock with Biometrics',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
