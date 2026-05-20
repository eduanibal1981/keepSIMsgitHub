import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/notifications/data/models/user_preferences_model.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> with SingleTickerProviderStateMixin {
  late AnimationController _biometricAnimController;
  bool _isSimulatingScan = false;
  String _scanStatusText = 'Initializing scan...';
  
  // Custom Keyboard variables for PIN setup
  bool _isSettingPin = false;
  String _pinInput = '';
  String _firstPinInput = '';
  bool _isConfirmStep = false;
  String _pinSetupError = '';

  @override
  void initState() {
    super.initState();
    _biometricAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _biometricAnimController.dispose();
    super.dispose();
  }

  void _runBiometricSimulation(bool enable) async {
    if (!enable) {
      await HapticHelper.lightTick();
      ref.read(userPreferencesControllerProvider.notifier).toggleBiometricAuth(false);
      return;
    }

    setState(() {
      _isSimulatingScan = true;
      _scanStatusText = 'Aligning camera...';
    });
    _biometricAnimController.repeat();

    Future.delayed(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      await HapticHelper.lightTick();
      setState(() {
        _scanStatusText = 'Scanning Face ID...';
      });
    });

    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;
      await HapticHelper.lightTick();
      setState(() {
        _scanStatusText = 'Securing signature...';
      });
    });

    Future.delayed(const Duration(milliseconds: 2800), () async {
      if (!mounted) return;
      _biometricAnimController.stop();
      setState(() {
        _isSimulatingScan = false;
      });
      ref.read(userPreferencesControllerProvider.notifier).toggleBiometricAuth(true);
      await HapticHelper.successFeedback();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.face_unlock_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Face ID successfully paired!'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    });
  }

  // Interactive Custom PIN Keyboard bottom sheet
  void _showPinSetupSheet(BuildContext context, bool isChange) {
    setState(() {
      _isSettingPin = true;
      _pinInput = '';
      _firstPinInput = '';
      _isConfirmStep = false;
      _pinSetupError = '';
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag handle
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Header
                  Icon(
                    Icons.lock_rounded,
                    size: 40,
                    color: const Color(0xFFD946EF),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isConfirmStep ? 'Confirm 4-Digit PIN' : (isChange ? 'Enter New Transaction PIN' : 'Setup Transaction PIN'),
                    style: AppTextStyles.titleLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      _isConfirmStep
                          ? 'Please re-enter your PIN to verify.'
                          : 'This PIN protects wallet balance withdrawals, funding, and lines freeze edits.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Circle Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isEntered = index < _pinInput.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isEntered
                              ? const Color(0xFFD946EF)
                              : Colors.transparent,
                          border: Border.all(
                            color: isEntered
                                ? const Color(0xFFD946EF)
                                : Colors.white.withOpacity(0.2),
                            width: 2,
                          ),
                          boxShadow: isEntered
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFD946EF).withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              : [],
                        ),
                      );
                    }),
                  ),
                  
                  if (_pinSetupError.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      _pinSetupError,
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                    ),
                  ],
                  
                  const Spacer(),

                  // Custom Pin Pad Grid (4x3)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                              return _buildKeypadButton(val, () {
                                if (_pinInput.length >= 4) return;
                                setSheetState(() {
                                  _pinInput += val;
                                  _pinSetupError = '';
                                });
                                _checkAndProgressPin(setSheetState);
                              });
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Backspace
                            _buildKeypadButton('⌫', () {
                              if (_pinInput.isEmpty) return;
                              setSheetState(() {
                                _pinInput = _pinInput.substring(0, _pinInput.length - 1);
                                _pinSetupError = '';
                              });
                            }, isAction: true),
                            _buildKeypadButton('0', () {
                              if (_pinInput.length >= 4) return;
                              setSheetState(() {
                                _pinInput += '0';
                                _pinSetupError = '';
                              });
                              _checkAndProgressPin(setSheetState);
                            }),
                            // Close
                            _buildKeypadButton('✕', () {
                              Navigator.pop(context);
                            }, isAction: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKeypadButton(String value, VoidCallback onTap, {bool isAction = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await HapticHelper.lightTick();
          onTap();
        },
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isAction ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.08),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: isAction ? const Color(0xFFD946EF) : Colors.white,
                fontSize: isAction ? 20 : 26,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _checkAndProgressPin(StateSetter setSheetState) {
    if (_pinInput.length == 4) {
      Future.delayed(const Duration(milliseconds: 250), () async {
        if (!mounted) return;
        if (!_isConfirmStep) {
          // Progress to confirmation
          await HapticHelper.mediumImpact();
          setSheetState(() {
            _firstPinInput = _pinInput;
            _pinInput = '';
            _isConfirmStep = true;
          });
        } else {
          // Confirm code
          if (_pinInput == _firstPinInput) {
            await HapticHelper.successFeedback();
            ref.read(userPreferencesControllerProvider.notifier).updateTransactionPin(_pinInput);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: const [
                    Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Transaction PIN successfully updated!'),
                  ],
                ),
                backgroundColor: const Color(0xFFD946EF),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          } else {
            await HapticHelper.errorFeedback();
            setSheetState(() {
              _pinInput = '';
              _pinSetupError = 'PINs do not match. Try again!';
            });
          }
        }
      });
    }
  }

  // Interactive Language Selection Bottom Sheet
  void _showLanguageSelector(BuildContext context, String currentLang) {
    final languages = [
      {'code': 'en', 'name': 'English (US)', 'flag': '🇺🇸'},
      {'code': 'es', 'name': 'Español (ES)', 'flag': '🇪🇸'},
      {'code': 'fr', 'name': 'Français (FR)', 'flag': '🇫🇷'},
      {'code': 'ar', 'name': 'العربية (AR)', 'flag': '🇦🇪'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select App Language',
                style: AppTextStyles.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ...languages.map((lang) {
                final isSelected = lang['code'] == currentLang;
                return InkWell(
                  onTap: () async {
                    await HapticHelper.mediumImpact();
                    ref.read(userPreferencesControllerProvider.notifier).updateLanguage(lang['code']!);
                    Navigator.pop(context);
                    await HapticHelper.successFeedback();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.05) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF6366F1).withOpacity(0.3) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 16),
                        Text(
                          lang['name']!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1)),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // Interactive time range picker for quiet hours
  Future<void> _selectQuietTime(BuildContext context, bool isStart, String? currentValue) async {
    int currentHour = 22;
    int currentMinute = 0;
    if (currentValue != null) {
      final parts = currentValue.split(':');
      if (parts.length >= 2) {
        currentHour = int.tryParse(parts[0]) ?? 22;
        currentMinute = int.tryParse(parts[1]) ?? 0;
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8B5CF6),
              onPrimary: Colors.white,
              surface: Color(0xFF0F172A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
      final currentPrefs = ref.read(userPreferencesControllerProvider).valueOrNull;
      if (currentPrefs != null) {
        if (isStart) {
          ref.read(userPreferencesControllerProvider.notifier).updateQuietHours(
                formattedTime,
                currentPrefs.quietHoursEnd,
              );
        } else {
          ref.read(userPreferencesControllerProvider.notifier).updateQuietHours(
                currentPrefs.quietHoursStart,
                formattedTime,
              );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsState = ref.watch(userPreferencesControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () async {
            await HapticHelper.lightTick();
            context.pop();
          },
        ),
        title: Text(
          'Preferences & Security',
          style: AppTextStyles.titleMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: prefsState.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
        error: (err, stack) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
        data: (prefs) {
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Appearance',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondaryDark,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Segmented Theme Slider Card
                    _buildThemeSelector(prefs.theme),
                    const SizedBox(height: 28),

                    Text(
                      'Localization & Regional',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondaryDark,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Interactive Dropdown Card for Languages
                    _buildLanguageCard(prefs.language),
                    const SizedBox(height: 28),

                    Text(
                      'Security & Access Lock',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondaryDark,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Security card
                    _buildSecurityCard(prefs),
                    const SizedBox(height: 28),

                    Text(
                      'Automated Summary & Alerts',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondaryDark,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Digest and Quiet Hours card
                    _buildAlertsConfigCard(prefs),
                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // Animated Scanning Biometrics Overlay
              if (_isSimulatingScan)
                _buildScanningOverlay(),
            ],
          );
        },
      ),
    );
  }

  // ── Theme Customizer ────────────────────────────────────────────────
  Widget _buildThemeSelector(String selectedTheme) {
    final modes = [
      {'code': 'system', 'label': 'System', 'icon': Icons.settings_brightness_rounded},
      {'code': 'dark', 'label': 'Dark Mode', 'icon': Icons.dark_mode_rounded},
      {'code': 'light', 'label': 'Light Mode', 'icon': Icons.light_mode_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: modes.map((mode) {
          final isSelected = mode['code'] == selectedTheme;
          return Expanded(
            child: InkWell(
              onTap: () async {
                await HapticHelper.lightTick();
                ref.read(userPreferencesControllerProvider.notifier).updateTheme(mode['code'] as String);
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mode['icon'] as IconData,
                      color: isSelected ? Colors.white : AppColors.textSecondaryDark,
                      size: 20,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mode['label'] as String,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isSelected ? Colors.white : AppColors.textSecondaryDark,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Language Selector Card ─────────────────────────────────────────
  Widget _buildLanguageCard(String currentLang) {
    String langName = 'English (US)';
    String flag = '🇺🇸';
    if (currentLang == 'es') {
      langName = 'Español (ES)';
      flag = '🇪🇸';
    } else if (currentLang == 'fr') {
      langName = 'Français (FR)';
      flag = '🇫🇷';
    } else if (currentLang == 'ar') {
      langName = 'العربية (AR)';
      flag = '🇦🇪';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ListTile(
        onTap: () async {
          await HapticHelper.lightTick();
          _showLanguageSelector(context, currentLang);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10B981).withOpacity(0.1),
          ),
          child: const Center(
            child: Icon(Icons.translate_rounded, color: Color(0xFF10B981)),
          ),
        ),
        title: Text(
          'App Language',
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Currently using regional $langName',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                currentLang.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondaryDark, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Security Panel ──────────────────────────────────────────────────
  Widget _buildSecurityCard(UserPreferences prefs) {
    final hasPin = prefs.transactionPinHash != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          // Biometric Toggle Switch
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withOpacity(0.1),
              ),
              child: const Center(
                child: Icon(Icons.fingerprint_rounded, color: Color(0xFF6366F1)),
              ),
            ),
            title: Text(
              'Biometric Security',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Sign in using Face ID or Touch ID',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
            ),
            trailing: Switch(
              value: prefs.biometricEnabled,
              onChanged: (val) async {
                await HapticHelper.mediumImpact();
                _runBiometricSimulation(val);
              },
              activeColor: const Color(0xFF6366F1),
              activeTrackColor: const Color(0xFF6366F1).withOpacity(0.3),
            ),
          ),
          
          Divider(color: Colors.white.withOpacity(0.05), height: 1),

          // Transaction PIN Card Trigger
          ListTile(
            onTap: () async {
              await HapticHelper.lightTick();
              _showPinSetupSheet(context, hasPin);
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD946EF).withOpacity(0.1),
              ),
              child: const Center(
                child: Icon(Icons.dialpad_rounded, color: Color(0xFFD946EF)),
              ),
            ),
            title: Text(
              'Transaction PIN',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              hasPin ? 'PIN setup is active and secure' : 'Secure renewals and withdrawals',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: hasPin ? const Color(0xFFD946EF).withOpacity(0.1) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasPin ? const Color(0xFFD946EF).withOpacity(0.2) : Colors.transparent,
                ),
              ),
              child: Text(
                hasPin ? 'ACTIVE' : 'SETUP',
                style: TextStyle(
                  color: hasPin ? const Color(0xFFD946EF) : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Alert Config card ──────────────────────────────────────────────
  Widget _buildAlertsConfigCard(UserPreferences prefs) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          // Weekly Digest Switch
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEC4899).withOpacity(0.1),
              ),
              child: const Center(
                child: Icon(Icons.mail_outline_rounded, color: Color(0xFFEC4899)),
              ),
            ),
            title: Text(
              'Weekly Digest',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Receive active wallet & lines report',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
            ),
            trailing: Switch(
              value: prefs.weeklyDigestEnabled,
              onChanged: (val) async {
                await HapticHelper.mediumImpact();
                ref.read(userPreferencesControllerProvider.notifier).toggleWeeklyDigest(val);
              },
              activeColor: const Color(0xFFEC4899),
              activeTrackColor: const Color(0xFFEC4899).withOpacity(0.3),
            ),
          ),

          Divider(color: Colors.white.withOpacity(0.05), height: 1),

          // Quiet Hours Config Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.dark_mode_outlined, color: Color(0xFF8B5CF6), size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Quiet Hours range',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          await HapticHelper.lightTick();
                          _selectQuietTime(context, true, prefs.quietHoursStart);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'START TIME',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondaryDark,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                prefs.quietHoursStart?.substring(0, 5) ?? '22:00',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Icon(Icons.arrow_forward_rounded, color: Colors.white24),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          await HapticHelper.lightTick();
                          _selectQuietTime(context, false, prefs.quietHoursEnd);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'END TIME',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondaryDark,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                prefs.quietHoursEnd?.substring(0, 5) ?? '07:00',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Biometrics Scanner Overlay ──────────────────────────────────────
  Widget _buildScanningOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Radar sweeping circle
            AnimatedBuilder(
              animation: _biometricAnimController,
              builder: (context, child) {
                return Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Rotating sweep line
                      Transform.rotate(
                        angle: _biometricAnimController.value * 2 * 3.14159,
                        child: Container(
                          width: 128,
                          height: 128,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                Color(0xFF6366F1),
                              ],
                              stops: [0.0, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ),
                      
                      // Face icon glowing
                      Icon(
                        Icons.face_unlock_rounded,
                        size: 64,
                        color: const Color(0xFF6366F1).withOpacity(0.8),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 36),
            Text(
              'Biometric Security Lock',
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _scanStatusText,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
