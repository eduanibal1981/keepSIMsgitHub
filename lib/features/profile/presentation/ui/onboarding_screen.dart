/// SIM Shield — Onboarding Screen
///
/// A premium, dark-themed 4-step animated onboarding wizard.
/// Collects user details, country, currency, protection tier, and smart preferences.
library;

import 'dart:async';
import 'package:keep_sims/core/fx/fx_provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';

import 'package:keep_sims/features/profile/presentation/controller/profile_controller.dart';
import 'package:keep_sims/features/profile/presentation/widgets/account_setup_welcome.dart';
import 'package:keep_sims/features/profile/presentation/widgets/setup_device_permissions.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_permission_controller.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/notifications/data/models/channel_destination.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/payments/presentation/screens/paypal_checkout_screen.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';

import '../../../sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/features/sim_lines/domain/plan_payment.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/carrier_activity_notice.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/carrier_rules_sheet.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_liveness_result.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/carrier_liveness_badge.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/sim_otp_verification_sheet.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _agreedToTerms = false;

  // Step 2 Data
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _whatsappNumberController =
      TextEditingController();
  final TextEditingController _notificationEmailController =
      TextEditingController();
  final FocusNode _whatsappNumberFocus = FocusNode();
  bool _hasEditedWhatsAppNumber = false;
  String? _whatsappNumberError;
  String _selectedCountryCode = 'EG';
  String _selectedCurrency = 'USD';
  bool _isSavingProfileStep = false;

  // Step 3 Data
  String _selectedTier = 'free';
  bool _skippedFirstSim = false;

  String get _setupTier => _skippedFirstSim ? 'free' : _selectedTier;

  // Step 4 (First SIM) Data
  final TextEditingController _simPhoneController = TextEditingController();
  final TextEditingController _simNicknameController = TextEditingController();
  Country? _selectedSimCountry;
  Carrier? _selectedSimCarrier;
  final String _selectedSimIcon = 'sim_card';
  SimLivenessResult? _simLivenessResult;
  bool _isCheckingLiveness = false;
  Timer? _livenessDebounce;

  // Step 5 Data
  bool _isFreePlanDisabled = false;

  final List<Map<String, String>> _countries = [
    {'code': 'EG', 'name': 'Egypt', 'flag': '🇪🇬'},
    {'code': 'SA', 'name': 'Saudi Arabia', 'flag': '🇸🇦'},
    {'code': 'AE', 'name': 'United Arab Emirates', 'flag': '🇦🇪'},
    {'code': 'IN', 'name': 'India', 'flag': '🇮🇳'},
    {'code': 'GB', 'name': 'United Kingdom', 'flag': '🇬🇧'},
    {'code': 'US', 'name': 'United States', 'flag': '🇺🇸'},
    {'code': 'PH', 'name': 'Philippines', 'flag': '🇵🇭'},
    {'code': 'JO', 'name': 'Jordan', 'flag': '🇯🇴'},
    {'code': 'PK', 'name': 'Pakistan', 'flag': '🇵🇰'},
  ];

  // Must stay in step with the `fx_rates` catalogue (G11): a code with no rate
  // row silently falls back to USD, which reads as the picker ignoring you.
  // The four rupee/taka corridors below were missing while the country picker
  // above has listed India, Philippines, Pakistan and Nepal all along — and
  // this feature exists for exactly those users.
  static const _seedCurrencies = <Map<String, String>>[
    {'code': 'OMR', 'name': 'Omani Rial (OMR)'},
    {'code': 'USD', 'name': 'US Dollar (\$)'},
    {'code': 'EUR', 'name': 'Euro (€)'},
    {'code': 'GBP', 'name': 'British Pound (£)'},
    {'code': 'SAR', 'name': 'Saudi Riyal (SR)'},
    {'code': 'EGP', 'name': 'Egyptian Pound (E£)'},
    {'code': 'AED', 'name': 'UAE Dirham (AED)'},
    {'code': 'JOD', 'name': 'Jordanian Dinar (JD)'},
    {'code': 'INR', 'name': 'Indian Rupee (₹)'},
    {'code': 'PKR', 'name': 'Pakistani Rupee (Rs)'},
    {'code': 'PHP', 'name': 'Philippine Peso (₱)'},
    {'code': 'BDT', 'name': 'Bangladeshi Taka (৳)'},
    {'code': 'LKR', 'name': 'Sri Lankan Rupee (Rs)'},
    {'code': 'NPR', 'name': 'Nepalese Rupee (Rs)'},
    {'code': 'TRY', 'name': 'Turkish Lira (₺)'},
  ];
  List<Map<String, String>> get _currencies {
    final state = ref.watch(fxControllerProvider);
    final available = !state.isLoading && !state.hasError
        ? state.asData?.value.available ?? const []
        : const [];
    final options = available.isEmpty
        ? _seedCurrencies.toList()
        : available
              .map(
                (option) => <String, String>{
                  'code': option.code,
                  'name': '${option.name} (${option.code})',
                },
              )
              .toList();
    if (!options.any((option) => option['code'] == _selectedCurrency)) {
      options.add({'code': _selectedCurrency, 'name': _selectedCurrency});
    }
    return options;
  }

  @override
  void initState() {
    super.initState();
    _simPhoneController.addListener(_onSimPhoneChanged);
    ref.listenManual(authControllerProvider, (previous, next) {
      final profile = next.asData?.value;
      if (profile == null) return;
      if (_nameController.text.isEmpty) {
        _nameController.text = profile.fullName ?? '';
      }
      _notificationEmailController.text = profile.email;
    }, fireImmediately: true);
    ref.listenManual(notificationChannelsControllerProvider, (previous, next) {
      if (_hasEditedWhatsAppNumber) return;
      final channel = next.asData?.value.firstWhereOrNull(
        (channel) => channel['channel_type'] == 'whatsapp',
      );
      if (channel == null) return;
      _whatsappNumberController.text = channelDestination(
        'whatsapp',
        Map<String, dynamic>.from(channel['config'] ?? {}),
      );
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _livenessDebounce?.cancel();
    _simPhoneController.removeListener(_onSimPhoneChanged);
    _pageController.dispose();
    _nameController.dispose();
    _whatsappNumberController.dispose();
    _notificationEmailController.dispose();
    _whatsappNumberFocus.dispose();
    _simPhoneController.dispose();
    _simNicknameController.dispose();
    super.dispose();
  }

  void _onSimPhoneChanged() {
    _livenessDebounce?.cancel();
    // Clear previous verification result so user can explicitly verify the updated digits
    if (_simLivenessResult != null) {
      setState(() {
        _simLivenessResult = null;
      });
    }
  }

  Future<SimLivenessResult?> _triggerSimLivenessCheck({
    bool showMissingError = true,
  }) async {
    if (!mounted) return null;
    if (_selectedSimCountry == null) {
      if (showMissingError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a country first.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return null;
    }

    String localNumber = _simPhoneController.text.trim();
    if (localNumber.startsWith('0')) {
      localNumber = localNumber.substring(1);
    }
    if (localNumber.length < 6) {
      if (showMissingError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your complete phone number first.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return null;
    }

    final fullNumber = '${_selectedSimCountry!.dialingCode}$localNumber';

    setState(() {
      _isCheckingLiveness = true;
    });

    try {
      final repo = ref.read(simLinesRepositoryProvider);
      final result = await repo.validateSimLiveness(
        fullNumber,
        countryCode: _selectedSimCountry?.isoCode,
      );

      if (mounted) {
        setState(() {
          _simLivenessResult = result;
          _isCheckingLiveness = false;
        });

        // Auto-match carrier if not yet chosen
        if (_selectedSimCarrier == null &&
            result.detectedOperatorName != null &&
            _selectedSimCountry != null) {
          final carriers =
              ref
                  .read(carriersForCountryProvider(_selectedSimCountry!.id))
                  .value ??
              [];
          final opLower = result.detectedOperatorName!.toLowerCase();
          final matched = carriers.firstWhereOrNull((c) {
            final cNameLower = c.name.toLowerCase();
            return opLower.contains(cNameLower) ||
                cNameLower.contains(opLower) ||
                (opLower.contains('friendi') &&
                    cNameLower.contains('friendi')) ||
                (opLower.contains('omantel') &&
                    cNameLower.contains('omantel')) ||
                (opLower.contains('ooredoo') &&
                    cNameLower.contains('ooredoo')) ||
                (opLower.contains('vodafone') &&
                    cNameLower.contains('vodafone')) ||
                (opLower.contains('red bull') &&
                    cNameLower.contains('red bull')) ||
                (opLower.contains('renna') && cNameLower.contains('renna'));
          });
          if (matched != null) {
            setState(() {
              _selectedSimCarrier = matched;
            });
          }
        }
      }
      return result;
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCheckingLiveness = false;
        });
      }
      return null;
    }
  }

  Future<void> _onTierSelected(String tierKey) async {
    if (tierKey == 'free') {
      setState(() {
        _selectedTier = 'free';
      });
      return;
    }

    final planLabel = tierKey == 'premium' ? 'Premium Plan' : 'Standard Plan';

    // 1. If we already checked this number:
    if (_simLivenessResult != null) {
      if (_simLivenessResult!.carrierStatus == 'inactive') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _simLivenessResult!.message.isNotEmpty
                  ? _simLivenessResult!.message
                  : 'This SIM number is inactive or expired at the carrier. Cannot select $planLabel.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final isConfirmedActive =
          _simLivenessResult!.isActive ||
          _simLivenessResult!.carrierStatus == 'active';
      if (!isConfirmedActive && _selectedSimCarrier == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Carrier validation is pending for this line. Please validate the line before selecting $planLabel.',
            ),
            backgroundColor: AppColors.warning,
            action: SnackBarAction(
              label: 'Validate Now',
              textColor: Colors.white,
              onPressed: () => _triggerSimLivenessCheck(showMissingError: true),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      setState(() {
        _selectedTier = tierKey;
      });
      return;
    }

    // 2. Otherwise, perform the live lookup automatically (same as Validate Line button)
    final result = await _triggerSimLivenessCheck(showMissingError: true);
    if (!mounted) return;

    if (result == null) {
      // User hasn't typed complete phone number or country yet
      return;
    }

    if (result.carrierStatus == 'inactive') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isNotEmpty
                ? result.message
                : 'This SIM number is inactive or expired at the carrier. Cannot select $planLabel.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final isConfirmedActive =
        result.isActive || result.carrierStatus == 'active';
    if (!isConfirmedActive && _selectedSimCarrier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Carrier validation is pending for this line. Please validate the line before selecting $planLabel.',
          ),
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: 'Validate Now',
            textColor: Colors.white,
            onPressed: () => _triggerSimLivenessCheck(showMissingError: true),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() {
      _selectedTier = tierKey;
    });
  }

  Future<void> _openSimOtpVerification() async {
    if (!mounted || _selectedSimCountry == null) return;
    String localNumber = _simPhoneController.text.trim();
    if (localNumber.startsWith('0')) {
      localNumber = localNumber.substring(1);
    }
    if (localNumber.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your complete phone number first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final fullNumber = '${_selectedSimCountry!.dialingCode}$localNumber';
    final result = await SimOtpVerificationSheet.show(
      context,
      fullPhoneNumber: fullNumber,
      carrierName: _selectedSimCarrier?.name,
      countryCode: _selectedSimCountry?.isoCode,
    );

    if (result != null && mounted) {
      setState(() {
        _simLivenessResult = result;
      });
    }
  }

  Future<void> _saveWhatsAppContact() async {
    if (!_hasEditedWhatsAppNumber) return;
    final channels = await ref.read(
      notificationChannelsControllerProvider.future,
    );
    if (!mounted) return;
    final channel = channels.firstWhereOrNull(
      (channel) => channel['channel_type'] == 'whatsapp',
    );
    if (channel == null) {
      throw StateError('WhatsApp settings are unavailable. Please try again.');
    }
    final config = Map<String, dynamic>.from(channel['config'] ?? {});
    final number = _whatsappNumberController.text.trim();
    config['phone'] = number;
    config['phone_number'] = number;
    await ref
        .read(notificationChannelsControllerProvider.notifier)
        .updateChannelConfig('whatsapp', config);
    _hasEditedWhatsAppNumber = false;
  }

  Future<void> _nextPage() async {
    if (_isSavingProfileStep) return;
    if (_currentPage == 0 && !_agreedToTerms) return;
    if (_currentPage == 1) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your full name.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      var whatsapp = _whatsappNumberController.text.trim().replaceAll(
        RegExp(r'[\s\-()]'),
        '',
      );
      if (whatsapp.startsWith('00')) whatsapp = '+${whatsapp.substring(2)}';
      if (whatsapp.isNotEmpty &&
          !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(whatsapp)) {
        setState(() {
          _whatsappNumberError =
              'Add + and the country code before your number, e.g. +96891234567.';
        });
        _whatsappNumberFocus.requestFocus();
        return;
      }
      _whatsappNumberController.text = whatsapp;
    }

    if (_currentPage == 1) {
      setState(() => _isSavingProfileStep = true);
      var saved = false;
      var contactsSaved = false;
      try {
        saved = await ref
            .read(fxControllerProvider.notifier)
            .setDisplayCurrency(_selectedCurrency);
        if (saved && mounted) {
          await _saveWhatsAppContact();
          contactsSaved = true;
        }
      } catch (_) {
        // Keep this step open so either failed save can be retried.
      } finally {
        if (mounted) setState(() => _isSavingProfileStep = false);
      }
      if (!mounted) return;
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.fxCurrencySaveFailed),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (!contactsSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save your WhatsApp number. Please try again.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    if (_currentPage == 2) {
      final phone = _simPhoneController.text.trim();
      if (phone.isNotEmpty) {
        if (_selectedSimCountry == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a country for your first SIM card.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        if (_selectedSimCarrier == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a carrier for your first SIM card.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        if (_selectedTier != 'free') {
          if (_simLivenessResult == null) {
            final res = await _triggerSimLivenessCheck(showMissingError: true);
            if (!mounted) return;
            final isConfirmed =
                res != null && (res.isActive || res.carrierStatus == 'active');
            if (!isConfirmed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    res?.carrierStatus == 'inactive'
                        ? (res?.message.isNotEmpty == true
                              ? res!.message
                              : 'Number inactive or expired at carrier.')
                        : 'Carrier verification is unconfirmed for this line. Please verify via Voice Call or SMS code first, or select the Free Plan.',
                  ),
                  backgroundColor: AppColors.error,
                  action: (res != null && res.carrierStatus != 'inactive')
                      ? SnackBarAction(
                          label: 'Verify Now',
                          textColor: Colors.white,
                          onPressed: _openSimOtpVerification,
                        )
                      : null,
                ),
              );
              return;
            }
          } else {
            final isConfirmed =
                _simLivenessResult!.isActive ||
                _simLivenessResult!.carrierStatus == 'active';
            if (!isConfirmed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _simLivenessResult!.carrierStatus == 'inactive'
                        ? (_simLivenessResult!.message.isNotEmpty
                              ? _simLivenessResult!.message
                              : 'Number inactive or expired at carrier.')
                        : 'Carrier verification is unconfirmed for this line. Please verify via Voice Call or SMS code first, or select the Free Plan.',
                  ),
                  backgroundColor: AppColors.error,
                  action: _simLivenessResult!.carrierStatus != 'inactive'
                      ? SnackBarAction(
                          label: 'Verify Now',
                          textColor: Colors.white,
                          onPressed: _openSimOtpVerification,
                        )
                      : null,
                ),
              );
              return;
            }
          }
        }
      }
    }

    if (_currentPage < 4) {
      if (_currentPage == 2) _skippedFirstSim = false;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipFirstSim() {
    if (_currentPage != 2 || _isCheckingLiveness) return;
    FocusScope.of(context).unfocus();
    setState(() => _skippedFirstSim = true);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  /// The yearly base service fee both paid tiers carry, from
  /// `system_configs.BASE_SERVICE_FEE_USD` (C3c) — one row, no app update.
  /// Safe to call during build(); _submit() awaits the real row before
  /// charging anything.
  double? get _baseServiceFeeUsd => ref.watch(baseServiceFeeUsdProvider).value;

  /// `$2.50/yr`-style label used across the plan copy.
  String get _feePerYearLabel =>
      '\$${_baseServiceFeeUsd?.toStringAsFixed(2) ?? '…'}/yr';

  /// Premium quoting/charging is shared with the add-line form and upgrade
  /// sheet via [PlanPayment] — three screens, one price.
  double? _premiumRefillPriceSync(CarrierRule rule) =>
      PlanPayment.premiumRefillPriceSync(ref, rule);

  double? _premiumYearlyTotalSync(CarrierRule rule) =>
      PlanPayment.premiumYearlyTotalSync(ref, rule);

  Future<void> _submit() async {
    final selectedTier = _setupTier;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must agree to the Terms of Service to proceed.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name.'),
          backgroundColor: AppColors.error,
        ),
      );
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      return;
    }

    final phone = _simPhoneController.text.trim();
    final hasSimDetails =
        !_skippedFirstSim &&
        phone.isNotEmpty &&
        _selectedSimCountry != null &&
        _selectedSimCarrier != null;

    Future<Null> commitSubmit() async {
      if (hasSimDetails) {
        try {
          String localNumber = phone;
          if (localNumber.startsWith('0')) {
            localNumber = localNumber.substring(1);
          }
          final fullPhoneNumber =
              '${_selectedSimCountry!.dialingCode}$localNumber';

          String? carrierRuleId;
          DateTime? planExpiresAt;

          if (selectedTier == 'premium') {
            final rule = await ref
                .read(simLinesRepositoryProvider)
                .getCarrierRule(_selectedSimCarrier!.id);
            if (rule != null) {
              // i7: last gate before payment. the server schedule mutation
              // raises KS422 for these carriers, and by the time it does, the
              // yearly charge has already been taken — the charged-but-no-line
              // shape this codebase has paid for before. Refuse here instead.
              if (CarrierActivityNotice.blocksPremium(rule)) {
                throw Exception(
                  'This carrier only resets its inactivity clock on a call, SMS or '
                  'data session, so automatic refills cannot keep the line active. '
                  'Please select the Standard plan.',
                );
              }
              carrierRuleId = rule.id;
            } else {
              throw Exception(
                'Premium pricing not configured for this carrier. Please select Standard plan.',
              );
            }
          }

          if (selectedTier != 'free') {
            planExpiresAt = DateTime.now().add(const Duration(days: 365));
          }

          await ref
              .read(simLinesControllerProvider.notifier)
              .addSimLine(
                phoneNumber: fullPhoneNumber,
                nickname: _simNicknameController.text.trim().isNotEmpty
                    ? _simNicknameController.text.trim()
                    : null,
                avatarIcon: _selectedSimIcon,
                countryId: _selectedSimCountry!.id,
                carrierId: _selectedSimCarrier!.id,
                planType: selectedTier,
                protectionTier: selectedTier == 'free' ? 'basic' : selectedTier,
                planExpiresAt: planExpiresAt,
                carrierRuleId: carrierRuleId,
                isCarrierVerified: _simLivenessResult?.isActive ?? false,
                carrierStatus: _simLivenessResult?.carrierStatus ?? 'pending',
                detectedOperatorName: _simLivenessResult?.detectedOperatorName,
                carrierVerifiedAt: _simLivenessResult != null
                    ? DateTime.now()
                    : null,
              );
        } on ScheduleInitializationException catch (e) {
          // The saved plan must not be charged again during schedule review.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Your plan was saved, but the '
                  'refill settings need review: $e\n'
                  'Do not pay for the plan again.',
                ),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 12),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to protect SIM: $e'),
                backgroundColor: AppColors.warning,
              ),
            );
          }
          return;
        }
      }

      final result = await ref
          .read(profileControllerProvider.notifier)
          .completeOnboarding(
            fullName: name,
            homeCountryCode: _selectedCountryCode,
            preferredCurrency: _selectedCurrency,
            isPowerUser: selectedTier == 'premium',
            subscriptionTier: selectedTier == 'free' ? 'basic' : selectedTier,
          );

      ref.invalidate(fxControllerProvider);

      if (mounted && result is Failure<UserProfile>) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    final isPaid = selectedTier != 'free';
    if (isPaid) {
      CarrierRule? premiumRule;
      if (selectedTier == 'premium' && hasSimDetails) {
        final rule = await ref
            .read(simLinesRepositoryProvider)
            .getCarrierRule(_selectedSimCarrier!.id);
        if (rule != null) {
          if (CarrierActivityNotice.blocksPremium(rule)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'This carrier only resets its inactivity clock on a call, SMS '
                    'or data session, so automatic refills cannot keep the line '
                    'active. Please select the Standard plan.',
                  ),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            return;
          }
          premiumRule = rule;
        }
      }

      final double planFee = double.parse(
        (selectedTier == 'premium' && premiumRule != null
                ? await PlanPayment.premiumWalletTotal(ref, premiumRule)
                : await ref.read(baseServiceFeeUsdProvider.future))
            .toStringAsFixed(2),
      );

      // Standard and Premium both bill wallet-first
      try {
        if (await PlanPayment.tryPlanFromWallet(
          ref,
          plan: selectedTier,
          rule: premiumRule,
        )) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.planFeePaidFromWallet,
                ),
                backgroundColor: AppColors.success,
              ),
            );
          }
          await commitSubmit();
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Wallet cannot cover it: compute shortfall deposit (minimum $5.00)
      double walletBalance = 0.0;
      final walletRead = await ref.read(walletRepositoryProvider).getWallet();
      if (walletRead case Success(data: final w)) {
        walletBalance = w.balance;
      }

      final shortfall = PlanPayment.calculateShortfall(
        fee: planFee,
        availableBalance: walletBalance,
      );

      final authGuard = ref.read(paymentAuthGuardProvider);
      final authResult = await authGuard.confirmPayment(
        reason: 'Authenticate to confirm plan deposit',
      );
      if (authResult != BiometricResult.success) {
        return;
      }

      if (mounted) {
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);

        navigator.push(
          MaterialPageRoute(
            builder: (_) => PayPalCheckoutScreen(
              initialAmount: shortfall,
              paymentReason: 'Wallet deposit for $selectedTier plan',
              paymentKind: 'deposit',
              plan: selectedTier,
              carrierRuleId: premiumRule?.id,
              onSuccess: () async {
                navigator.pop();
                try {
                  await PlanPayment.waitForWalletCredit(ref, atLeast: planFee);

                  final paid = await PlanPayment.tryPlanFromWallet(
                    ref,
                    plan: selectedTier,
                    rule: premiumRule,
                  );

                  if (paid) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)!.planFeePaidFromWallet,
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    await commitSubmit();
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Deposit received! Please try activating again from your wallet balance.',
                        ),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Plan activation failed: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    } else {
      await commitSubmit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final countries = ref.watch(supportedCountriesProvider).value ?? [];
    final carriers = _selectedSimCountry == null
        ? <Carrier>[]
        : ref
                  .watch(carriersForCountryProvider(_selectedSimCountry!.id))
                  .value ??
              [];

    // Pre-select SIM country based on selected home country code if not already selected
    if (_selectedSimCountry == null && countries.isNotEmpty) {
      try {
        _selectedSimCountry = countries.firstWhere(
          (c) => c.isoCode == _selectedCountryCode,
        );
      } catch (_) {
        _selectedSimCountry = null;
      }
    }

    CarrierRule? premiumRule;
    bool isPremiumLoading = false;
    if (_selectedSimCountry != null && _selectedSimCarrier != null) {
      final ruleAsync = ref.watch(carrierRuleProvider(_selectedSimCarrier!.id));
      premiumRule = ruleAsync.value;
      isPremiumLoading = ruleAsync.isLoading;
    }

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header / Step Progress Indicator ───────────────────────
            _buildHeader(),

            // ── Main Page Carousel ────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildStepWelcome(),
                  _buildStepProfile(),
                  _buildStepFirstSim(
                    countries,
                    carriers,
                    premiumRule,
                    isPremiumLoading,
                  ),
                  _buildStepNotifications(),
                  _buildStepSmartPreferences(),
                ],
              ),
            ),

            // ── Footer Navigation Buttons ──────────────────────────────
            _buildFooter(profileState.isLoading),
          ],
        ),
      ),
    );
  }

  // ── Header Widget ───────────────────────────────────────────────
  Widget _buildHeader() {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Setup Protection',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Step ${_currentPage + 1} of 5',
                  textAlign: TextAlign.end,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Clean custom linear progress indicator
          Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                width:
                    MediaQuery.of(context).size.width *
                        ((_currentPage + 1) / 5) -
                    40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 1: Welcome Screen ──────────────────────────────────────
  Widget _buildStepWelcome() {
    return AccountSetupWelcome(
      agreedToTerms: _agreedToTerms,
      onAgreementChanged: (value) => setState(() => _agreedToTerms = value),
      onOpenTerms: () => _openPolicy('https://keepsims.com/terms'),
      onOpenPrivacy: () => _openPolicy('https://keepsims.com/privacy'),
    );
  }

  Future<void> _openPolicy(String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // Keep the welcome step available if the device cannot open the browser.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open this page. Please try again.'),
      ),
    );
  }

  // ── Step 2: Personalize Profile Screen ───────────────────────────
  Widget _buildStepProfile() {
    final isDark = context.isDarkMode;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'Personalize Profile',
            style: AppTextStyles.headlineSmall.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.w700,
              fontSize: 21,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tell us who you are and set your preferences so we can deliver timely SIM alerts.',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // Name Input
          Text(
            'Full Name',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            style: TextStyle(color: context.onSurfaceColor),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              hintText: 'John Doe',
              hintStyle: TextStyle(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.primaryColor, width: 1.5),
              ),
              prefixIcon: Icon(
                Icons.person_rounded,
                size: 20,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Home Country Dropdown
          Text(
            'Home Country',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCountryCode,
                isDense: true,
                dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                isExpanded: true,
                items: _countries.map((country) {
                  return DropdownMenuItem<String>(
                    value: country['code'],
                    child: Row(
                      children: [
                        Text(
                          country['flag']!,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          country['name']!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.onSurfaceColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCountryCode = val;
                    });
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'WhatsApp Number',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            'Keepsims will send you alerts about your SIM',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontStyle: FontStyle.italic,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('onboarding-whatsapp-number'),
            controller: _whatsappNumberController,
            focusNode: _whatsappNumberFocus,
            enabled: !_isSavingProfileStep,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            style: TextStyle(color: context.onSurfaceColor),
            onChanged: (_) {
              _hasEditedWhatsAppNumber = true;
              if (_whatsappNumberError != null) {
                setState(() => _whatsappNumberError = null);
              }
            },
            decoration: _notificationContactDecoration(
              hintText: 'e.g. +96891234567',
              icon: Icons.chat_bubble_outline_rounded,
              errorText: _whatsappNumberError,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: context.primaryColor.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Format: + followed by country code and mobile number',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Example (Oman): +96891234567',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'For Standard and Premium SIM subscriptions',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Notification email',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('onboarding-notification-email'),
            controller: _notificationEmailController,
            readOnly: true,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: context.onSurfaceColor),
            decoration: _notificationContactDecoration(
              hintText: 'Your account email',
              icon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Uses your account email. You can choose a different verified email later in notification settings.',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),

          // Currency Dropdown
          Text(
            'Preferred Currency',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCurrency,
                isDense: true,
                dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                isExpanded: true,
                items: _currencies.map((curr) {
                  return DropdownMenuItem<String>(
                    value: curr['code'],
                    child: Text(
                      curr['name']!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.onSurfaceColor,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: _isSavingProfileStep
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCurrency = val;
                          });
                        }
                      },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Prices are in USD. Your preferred currency is used to show an approximate converted value.',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _notificationContactDecoration({
    required String hintText,
    required IconData icon,
    String? errorText,
  }) {
    final isDark = context.isDarkMode;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
    );
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintText: hintText,
      errorText: errorText,
      errorMaxLines: 3,
      hintStyle: TextStyle(
        color: isDark
            ? AppColors.textTertiaryDark
            : AppColors.textTertiaryLight,
      ),
      filled: true,
      fillColor: isDark ? AppColors.darkCard : Colors.white,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: context.primaryColor, width: 1.5),
      ),
      prefixIcon: Icon(
        icon,
        size: 20,
        color: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
      ),
    );
  }

  // ── Step 3: Choose Protection Tier Screen ────────────────────────

  // ── Step 3: Protect First SIM Screen ─────────────────────────────
  Widget _buildStepFirstSim(
    List<Country> countries,
    List<Carrier> carriers,
    CarrierRule? premiumRule,
    bool isPremiumLoading,
  ) {
    final isDark = context.isDarkMode;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Protect First SIM',
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: context.onSurfaceColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                key: const ValueKey('onboarding-first-sim-skip'),
                onPressed: _isCheckingLiveness ? null : _skipFirstSim,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Skip'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the details of your first SIM card to begin active shield protection. You can skip this step and add more SIM lines later from the dashboard.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // SIM Country Dropdown
          Text(
            'SIM Card Country',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Country>(
                value: _selectedSimCountry,
                hint: Text(
                  'Select Country',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
                dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                isExpanded: true,
                items: countries.map((c) {
                  return DropdownMenuItem<Country>(
                    value: c,
                    child: Row(
                      children: [
                        Text(c.flagEmoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Text(
                          c.name,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: context.onSurfaceColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedSimCountry = val;
                      _selectedSimCarrier = null; // Reset carrier
                      _simLivenessResult = null; // Reset verification
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Phone Number Input
          Text(
            'SIM Card Phone Number',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedSimCountry != null
                          ? _selectedSimCountry!.flagEmoji
                          : '🌐',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedSimCountry?.dialingCode ?? '+00',
                      style: TextStyle(
                        color: context.onSurfaceColor,
                        fontSize: 16,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _simPhoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: context.onSurfaceColor),
                  decoration: InputDecoration(
                    hintText: 'e.g. 91234567',
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: context.primaryColor,
                        width: 1.5,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.phone_android_rounded,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ),
            ],
          ),
          CarrierLivenessBadge(
            result: _simLivenessResult,
            isLoading: _isCheckingLiveness,
            onCheck: _triggerSimLivenessCheck,
            onRetry: _triggerSimLivenessCheck,
            onOtpVerify: _openSimOtpVerification,
          ),
          const SizedBox(height: 24),

          // Carrier Dropdown
          if (_selectedSimCountry != null) ...[
            Text(
              'SIM Carrier Brand',
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.onSurfaceColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Carrier>(
                  value: _selectedSimCarrier,
                  hint: Text(
                    'Select Carrier brand',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                  dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  isExpanded: true,
                  items: carriers.map((c) {
                    return DropdownMenuItem<Carrier>(
                      value: c,
                      child: Text(
                        c.name,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: context.onSurfaceColor,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedSimCarrier = val;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // SIM Nickname Input
          Text(
            'SIM Nickname (Optional)',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _simNicknameController,
            style: TextStyle(color: context.onSurfaceColor),
            decoration: InputDecoration(
              hintText: 'e.g. My Travel SIM',
              hintStyle: TextStyle(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.primaryColor, width: 1.5),
              ),
              prefixIcon: Icon(
                Icons.label_outline_rounded,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Plan Selection
          Text(
            'Select Protection Plan',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // i7: above the tiers, not below them — if this carrier cannot be
          // protected by refilling, the user should know before they read a
          // price. Mirrors sim_line_form_screen.dart.
          if (premiumRule != null) CarrierActivityNotice(rule: premiumRule),
          _buildTierGrid(premiumRule, isPremiumLoading),
          const SizedBox(height: 24),
          _buildDynamicBillingSection(
            _selectedTier,
            premiumRule,
            isPremiumLoading,
          ),
          const SizedBox(height: 16),

          // Info Note
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Note: You can add and protect more SIM cards later from the dashboard.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 5: Smart Preferences Screen ──────────────────────────────
  Widget _buildStepSmartPreferences() {
    final isDark = context.isDarkMode;
    final selectedTier = _setupTier;
    final selectedCountry = _countries.firstWhere(
      (c) => c['code'] == _selectedCountryCode,
      orElse: () => {'code': '', 'name': '', 'flag': ''},
    );

    final selectedCurrency = _currencies.firstWhere(
      (curr) => curr['code'] == _selectedCurrency,
      orElse: () => {'code': '', 'name': ''},
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Smart Preferences',
            style: AppTextStyles.headlineLarge.copyWith(
              color: context.onSurfaceColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review your configuration before activating protection for your lines.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 36),

          // Selection Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.assignment_turned_in_rounded,
                        color: context.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Review Configuration',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSummaryRow(
                  label: 'Full Name',
                  value: _nameController.text.trim().isEmpty
                      ? 'Not specified'
                      : _nameController.text.trim(),
                  icon: Icons.person_rounded,
                ),
                Divider(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  height: 24,
                ),
                _buildSummaryRow(
                  label: 'Home Country',
                  value:
                      '${selectedCountry['flag']} ${selectedCountry['name']}',
                  icon: Icons.public_rounded,
                ),
                Divider(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  height: 24,
                ),
                _buildSummaryRow(
                  label: 'Preferred Currency',
                  value: selectedCurrency['name'] ?? _selectedCurrency,
                  icon: Icons.payments_rounded,
                ),
                Divider(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  height: 24,
                ),
                _buildSummaryRow(
                  label: 'Selected Plan',
                  value: selectedTier == 'free'
                      ? 'Free Plan (\$0)'
                      : (selectedTier == 'standard'
                            ? 'Standard Plan ($_feePerYearLabel)'
                            : 'Premium Plan (annual membership + first refill)'),
                  icon: Icons.shield_rounded,
                  valueColor: selectedTier == 'free'
                      ? Colors.blueAccent
                      : (selectedTier == 'standard'
                            ? context.primaryColor
                            : Colors.purpleAccent),
                ),
                if (!_skippedFirstSim &&
                    _simPhoneController.text.trim().isNotEmpty) ...[
                  Divider(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    height: 24,
                  ),
                  _buildSummaryRow(
                    label: 'First Protected SIM',
                    value:
                        '${_selectedSimCountry?.flagEmoji ?? ""} ${_selectedSimCountry?.dialingCode ?? ""}${_simPhoneController.text.trim()}${_simNicknameController.text.trim().isNotEmpty ? " (${_simNicknameController.text.trim()})" : ""}',
                    icon: Icons.sim_card_rounded,
                  ),
                ],
                ref
                    .watch(notificationChannelsControllerProvider)
                    .maybeWhen(
                      data: (channels) {
                        final activeList = channels
                            .where((c) => c['is_enabled'] == true)
                            .map((c) {
                              final type = c['channel_type'] as String;
                              if (type == 'push') return 'Push';
                              if (type == 'email') return 'Email';
                              if (type == 'whatsapp') return 'WhatsApp';
                              if (type == 'telegram') return 'Telegram';
                              return type;
                            })
                            .toList();
                        final valueText = activeList.isEmpty
                            ? 'None active'
                            : activeList.join(', ');
                        return Column(
                          children: [
                            Divider(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                              height: 24,
                            ),
                            _buildSummaryRow(
                              label: 'Configured Alerts',
                              value: valueText,
                              icon: Icons.notifications_active_rounded,
                            ),
                          ],
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: isDark ? AppColors.secondary : AppColors.lightSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Terms of Service and Privacy Policy accepted. Activating '
                  'protection authorizes smart checks on the lines you add.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.onSurfaceColor,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNotifications() {
    final isDark = context.isDarkMode;
    final isBasic = _setupTier == 'free';
    final channelsAsync = ref.watch(notificationChannelsControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                'Setup Alerts',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: context.onSurfaceColor,
                ),
              ),
              TextButton.icon(
                key: const ValueKey('onboarding-alerts-skip'),
                onPressed: _nextPage,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Set up later'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isBasic
                ? 'Free Plan includes mobile push notifications and Telegram alerts. Upgrade to unlock WhatsApp and Email alerts.'
                : 'Choose how you would like to receive critical deactivation warnings, wallet alerts, and renewal status updates.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          const SetupDevicePermissions(),
          const Divider(height: 40),
          Text(
            'Alert channels',
            style: AppTextStyles.titleLarge.copyWith(
              color: context.onSurfaceColor,
            ),
          ),
          const SizedBox(height: 12),
          channelsAsync.when(
            data: (channels) {
              final order = {
                'push': 1,
                'email': 2,
                'whatsapp': 3,
                'telegram': 4,
              };
              final filtered =
                  channels
                      .where((c) => order.containsKey(c['channel_type']))
                      .toList()
                    ..sort(
                      (a, b) => (order[a['channel_type']] ?? 99).compareTo(
                        order[b['channel_type']] ?? 99,
                      ),
                    );

              return Material(
                color: isDark ? AppColors.darkCard : Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => Divider(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final ch = filtered[index];
                    final type = ch['channel_type'] as String;
                    final isEnabled = ch['is_enabled'] ?? false;

                    String label = '';
                    IconData icon = Icons.notifications;
                    Color color = AppColors.primary;
                    String subtitle = '';
                    switch (type) {
                      case 'push':
                        label = 'Push Notifications';
                        subtitle =
                            'SIM reminders and account updates on this device.';
                        icon = Icons.notifications_active_rounded;
                        color = AppColors.primaryLight;
                        break;
                      case 'whatsapp':
                        label = 'Whats Alerts';
                        subtitle =
                            'Renewal reminders pushed directly to WhatsApp.';
                        icon = Icons.chat_bubble_outline_rounded;
                        color = const Color(0xFF4ADE80);
                        break;
                      case 'telegram':
                        label = 'Telegram Bot';
                        subtitle =
                            'Bound interactive Telegram chat notifications.';
                        icon = Icons.telegram_rounded;
                        color = const Color(0xFF22D3EE);
                        break;
                      case 'email':
                        label = 'Email Alerts';
                        subtitle =
                            'Critical deactivation alerts sent via Email.';
                        icon = Icons.email_rounded;
                        color = const Color(0xFF38BDF8);
                        break;
                    }

                    // On basic tier, WhatsApp and Email are locked (Push and Telegram are free)
                    final bool isLocked =
                        type != 'push' && type != 'telegram' && isBasic;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          key: ValueKey('onboarding-channel-$type'),
                          value: isLocked ? false : isEnabled,
                          activeThumbColor: color,
                          activeTrackColor: color.withValues(alpha: 0.2),
                          inactiveThumbColor: AppColors.textTertiaryDark,
                          inactiveTrackColor: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          title: Row(
                            children: [
                              Icon(
                                icon,
                                color: isLocked
                                    ? AppColors.textTertiaryDark
                                    : color,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  label,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isLocked
                                        ? AppColors.textSecondaryDark
                                        : context.onSurfaceColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isLocked) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.amberAccent.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'UPGRADE',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: Colors.amberAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              subtitle,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                          ),
                          onChanged: isLocked
                              ? null
                              : (val) => _toggleAlertChannel(type, val),
                        ),
                        if (isEnabled && type != 'push' && !isLocked) ...[
                          _InlineOnboardingChannelConfig(
                            channel: ch,
                            ref: ref,
                            isDark: isDark,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (err, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAlertChannel(String type, bool enabled) async {
    try {
      if (type == 'push' && enabled) {
        final allowed = await ref
            .read(notificationPermissionControllerProvider.notifier)
            .enable();
        if (!mounted || !allowed) return;
      }
      await ref
          .read(notificationChannelsControllerProvider.notifier)
          .toggleChannel(type, enabled);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update alerts. Please try again.'),
        ),
      );
    }
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    final isDark = context.isDarkMode;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: valueColor ?? context.onSurfaceColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Footer Navigation Buttons ────────────────────────────────────
  Widget _buildFooter(bool isLoading) {
    isLoading = isLoading || _isSavingProfileStep;
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          if (_currentPage > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: isLoading ? null : _prevPage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.onSurfaceColor,
                      side: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              ),
            ),

          // Next / Submit Button
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                key: const ValueKey('onboarding-continue'),
                onPressed: (isLoading || (_currentPage == 0 && !_agreedToTerms))
                    ? null
                    : (_currentPage == 4)
                    ? _submit
                    : _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  foregroundColor: isDark && _currentPage == 0
                      ? AppColors.darkBg
                      : Colors.white,
                  disabledBackgroundColor: context.primaryColor.withValues(
                    alpha: _currentPage == 0 ? 0.15 : 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _currentPage == 4 ? 'Start Protecting' : 'Continue',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicBillingSection(
    String selectedTier,
    CarrierRule? premiumRule,
    bool isPremiumLoading,
  ) {
    final isDark = context.isDarkMode;
    final bool isStandard = selectedTier == 'standard';
    final bool isPremium = selectedTier == 'premium';

    String planName = 'Free Plan';
    Color planColor = isDark ? Colors.blueAccent : Colors.blue;
    String billingDesc =
        'This line is protected for free. Basic alerts only. No auto-refills.';
    String billingRate = 'FREE';

    if (isPremium) {
      planName = 'Premium Plan';
      planColor = isDark ? Colors.purpleAccent : Colors.purple;
      if (isPremiumLoading) {
        billingDesc = 'Loading premium pricing rules for this carrier...';
        billingRate = '$_feePerYearLabel + ...';
      } else if (CarrierActivityNotice.blocksPremium(premiumRule)) {
        // The server refuses to queue refills for these carriers, so selling
        // the plan here would take the money and fail afterwards.
        billingDesc =
            'This carrier only counts calls, texts and data as activity, so '
            'automatic top-ups cannot keep the line active. Please choose the '
            'Standard Plan.';
        planColor = isDark ? AppColors.error : Colors.redAccent;
        billingRate = 'Not Supported';
      } else if (premiumRule != null) {
        // The whole year is charged once, up front — the old copy read as though
        // each refill were billed separately.
        const cur = 'USD';
        billingDesc =
            'Initial Premium charge: ${_premiumYearlyTotalSync(premiumRule)?.toStringAsFixed(2) ?? '…'} $cur, '
            'including the annual membership and first refill. Future refills are '
            'charged to your wallet when due, every ${premiumRule.refillIntervalDays} days.';
        billingRate = '$_feePerYearLabel + Refill';
      } else {
        billingDesc =
            'Premium auto-refill is not yet supported for this carrier. Please choose the Standard Plan.';
        planColor = isDark ? AppColors.error : Colors.redAccent;
        billingRate = 'Not Supported';
      }
    } else if (isStandard) {
      planName = 'Standard Plan';
      planColor = isDark ? AppColors.primary : AppColors.lightPrimary;
      billingDesc =
          'Automated tracking & notifications. You will be billed $_feePerYearLabel for this line.';
      billingRate = _feePerYearLabel;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: planColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: planColor.withValues(alpha: isDark ? 0.05 : 0.08),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: planColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: planColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  planName,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: planColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      billingRate,
                      style: AppTextStyles.caption.copyWith(
                        color: planColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (isStandard)
                      if (_baseServiceFeeUsd case final price?)
                        ApproxLocalText(price)
                      else if (isPremium &&
                          premiumRule != null &&
                          !isPremiumLoading &&
                          !CarrierActivityNotice.blocksPremium(premiumRule))
                        if (_premiumYearlyTotalSync(premiumRule)
                            case final price?)
                          ApproxLocalText(price),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            billingDesc,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const FxChargeNotice(),
          // i8: same link as the add-line form. Onboarding is where most people
          // meet this decision for the first time, so it is the last place that
          // should hide what the carrier's rules actually are.
          if (premiumRule != null && _selectedSimCarrier != null)
            _buildCarrierRulesLink(premiumRule, planColor),
        ],
      ),
    );
  }

  Widget _buildCarrierRulesLink(CarrierRule rule, Color planColor) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: InkWell(
        onTap: () => CarrierRulesSheet.show(
          context: context,
          rule: rule,
          carrierId: _selectedSimCarrier!.id,
          carrierName: _selectedSimCarrier!.name,
          countryName: _selectedSimCountry?.name,
          premiumYearlyTotal: CarrierActivityNotice.blocksPremium(rule)
              ? null
              : _premiumYearlyTotalSync(rule),
        ),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_rounded, size: 16, color: planColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.carrierRulesLinkLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: planColor,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: planColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 16, color: planColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierGrid(CarrierRule? premiumRule, bool isPremiumLoading) {
    final isDark = context.isDarkMode;
    final currentLines = ref.read(simLinesControllerProvider).value ?? [];

    // Check if free plan should be disabled
    final hasFreeLine = currentLines.any((l) => l.planType == 'free');
    _isFreePlanDisabled = hasFreeLine;

    // if free is disabled and currently selected, auto-select standard
    if (_isFreePlanDisabled && _selectedTier == 'free') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedTier = 'standard';
          });
        }
      });
    }

    final tiers = [
      {
        'key': 'free',
        'name': 'Free Plan',
        'desc': 'Limited to 1 line. Basic alerts.',
      },
      {
        'key': 'standard',
        'name': 'Standard Plan',
        'desc': 'Automated tracking & notifications.',
      },
      {
        'key': 'premium',
        'name': 'Premium Plan',
        'desc': 'Fully automated top-ups & extensions.',
      },
    ];

    return Column(
      children: tiers.map((tier) {
        final isSelected = _selectedTier == tier['key'];
        final isDisabled = tier['key'] == 'free' && _isFreePlanDisabled;
        final double? displayPriceUsd = tier['key'] == 'standard'
            ? _baseServiceFeeUsd
            : tier['key'] == 'premium' &&
                  premiumRule != null &&
                  !isPremiumLoading &&
                  !CarrierActivityNotice.blocksPremium(premiumRule)
            ? _premiumYearlyTotalSync(premiumRule)
            : null;

        final isChecking =
            _isCheckingLiveness &&
            (tier['key'] == 'standard' || tier['key'] == 'premium');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: isDisabled || _isCheckingLiveness
                ? null
                : () => _onTierSelected(tier['key']!),
            borderRadius: BorderRadius.circular(16),
            child: Opacity(
              opacity: isDisabled ? 0.5 : 1.0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.primary : AppColors.lightPrimary)
                            .withValues(alpha: 0.1)
                      : (isDark ? AppColors.darkCard : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? AppColors.primary : AppColors.lightPrimary)
                        : (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder),
                    width: 2,
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.lightPrimary.withValues(
                              alpha: 0.04,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    if (isChecking)
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark
                                ? AppColors.primaryLight
                                : AppColors.lightPrimary,
                          ),
                        ),
                      )
                    else
                      RadioGroup<String>(
                        groupValue: _selectedTier,
                        onChanged: (value) {
                          if (value != null &&
                              !isDisabled &&
                              !_isCheckingLiveness) {
                            _onTierSelected(value);
                          }
                        },
                        child: Radio<String>(
                          value: tier['key']!,
                          enabled: !isDisabled && !_isCheckingLiveness,
                          activeColor: isDark
                              ? AppColors.primaryLight
                              : AppColors.lightPrimary,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tier['name']!,
                            style: TextStyle(
                              color: context.onSurfaceColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tier['desc']! +
                                (isDisabled ? ' (Limit Reached)' : ''),
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontSize: 12,
                            ),
                          ),
                          if (displayPriceUsd != null) ...[
                            Text(
                              '${Money.usd(displayPriceUsd)}${tier['key'] == 'premium' ? ' USD' : '/yr'}',
                              style: TextStyle(
                                color: context.onSurfaceColor,
                                fontSize: 12,
                              ),
                            ),
                            ApproxLocalText(displayPriceUsd),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showPlanFeaturesDialog(
                        context,
                        tier['key']!,
                        premiumRule,
                        isPremiumLoading,
                      ),
                      icon: Icon(
                        Icons.help_outline_rounded,
                        color: context.primaryColor,
                        size: 22,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Info Dialog ────────────────────────────────────────────────────────────
  void _showPlanFeaturesDialog(
    BuildContext context,
    String planKey,
    CarrierRule? premiumRule,
    bool isPremiumLoading,
  ) {
    final isDark = context.isDarkMode;

    final String title;
    final IconData icon;
    final Color accentColor;
    final String priceStr;
    final String billingPeriod;
    final List<String> features;
    final bool isPremium = planKey == 'premium';
    final bool isStandard = planKey == 'standard';

    if (isPremium) {
      title = 'Premium Plan';
      icon = Icons.workspace_premium_rounded;
      accentColor = const Color(0xFF2E7D32); // Green
      final annualFee = premiumRule == null
          ? null
          : PlanPayment.premiumBreakdownSync(ref, premiumRule)?.annualFeeUsd;
      priceStr = '\$${annualFee?.toStringAsFixed(2) ?? '…'}';
      billingPeriod = '/yr per line';
      features = [
        'Everything in Standard',
        'Automated Keep-Alive auto-refill',
        'Custom auto-refill scheduling',
        'Real-time balance monitoring',
        'Unlimited SIM lines',
        'Priority support',
      ];
    } else if (isStandard) {
      title = 'Standard Plan';
      icon = Icons.verified_user_rounded;
      accentColor = const Color(0xFF1565C0); // Blue
      priceStr = '\$${_baseServiceFeeUsd?.toStringAsFixed(2) ?? '…'}';
      billingPeriod = '/yr per line';
      features = [
        'Push notification alerts',
        'Telegram recharge requests',
        'Manual status & expiry checks',
        'Up to 5 SIM lines',
      ];
    } else {
      title = 'Free Plan';
      icon = Icons.info_outline_rounded;
      accentColor = const Color(0xFF757575); // Grey
      priceStr = 'FREE';
      billingPeriod = 'no charge';
      features = [
        'Basic expiry alerts',
        'Limited to 1 line per account',
        'Manual verification checks',
        'Standard email support',
      ];
    }

    final cardBgColor = isDark
        ? accentColor.withValues(alpha: 0.12)
        : accentColor.withValues(alpha: 0.05);
    final cardBorderColor = accentColor.withValues(alpha: 0.3);

    showModalBottomSheet(
      context: context,
      backgroundColor: context.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Plan Details',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.onSurfaceColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: context.onSurfaceColor.withValues(alpha: 0.6),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Main Plan Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorderColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(
                        alpha: isDark ? 0.05 : 0.08,
                      ),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row
                    Row(
                      children: [
                        // Shield/Plan Icon badge
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: accentColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        // Plan Name
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: context.onSurfaceColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Pricing
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  priceStr,
                                  style: AppTextStyles.titleLarge.copyWith(
                                    color: accentColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                  ),
                                ),
                                if (isStandard && _baseServiceFeeUsd != null)
                                  ApproxLocalText(
                                    _baseServiceFeeUsd!,
                                    textAlign: TextAlign.end,
                                  ),
                              ],
                            ),
                            Text(
                              billingPeriod,
                              style: AppTextStyles.caption.copyWith(
                                color: context.onSurfaceColor.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.end,
                            ),
                            if (isPremium && premiumRule != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '+ ${_premiumRefillPriceSync(premiumRule)?.toStringAsFixed(2) ?? '…'} USD refill',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: accentColor.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  if (_premiumRefillPriceSync(premiumRule)
                                      case final price?)
                                    ApproxLocalText(
                                      price,
                                      textAlign: TextAlign.end,
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: accentColor.withValues(alpha: 0.2),
                      height: 1,
                      thickness: 1,
                    ),
                    const SizedBox(height: 16),
                    // Features list
                    ...features.map(
                      (feat) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: accentColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                feat,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: context.onSurfaceColor.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Auto refill rule (Premium only)
                    if (isPremium) ...[
                      const SizedBox(height: 16),
                      if (isPremiumLoading)
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Loading auto-refill pricing...',
                              style: AppTextStyles.caption.copyWith(
                                color: context.onSurfaceColor.withValues(
                                  alpha: 0.5,
                                ),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        )
                      else if (premiumRule != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.autorenew_rounded,
                                size: 16,
                                color: accentColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Auto-refill: ${_premiumRefillPriceSync(premiumRule)?.toStringAsFixed(2) ?? '…'} USD every ${premiumRule.refillIntervalDays} days (telecom, VAT included)',
                                  style: AppTextStyles.caption.copyWith(
                                    color: context.onSurfaceColor.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Auto-refill pricing not available for this carrier yet.',
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    // Badges
                    if (isPremium) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC8E6C9), // Light green badge
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('✨ ', style: TextStyle(fontSize: 12)),
                            Text(
                              'Most Popular',
                              style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isStandard) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBBDEFB), // Light blue badge
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '👍 Recommended',
                              style: TextStyle(
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InlineOnboardingChannelConfig extends StatefulWidget {
  final Map<String, dynamic> channel;
  final WidgetRef ref;
  final bool isDark;

  const _InlineOnboardingChannelConfig({
    required this.channel,
    required this.ref,
    required this.isDark,
  });

  @override
  State<_InlineOnboardingChannelConfig> createState() =>
      _InlineOnboardingChannelConfigState();
}

class _InlineOnboardingChannelConfigState
    extends State<_InlineOnboardingChannelConfig> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final config = widget.channel['config'] as Map<String, dynamic>? ?? {};
    final type = widget.channel['channel_type'] as String;
    String txt = '';
    if (type == 'email') {
      txt = config['email'] ?? '';
    } else if (type == 'whatsapp') {
      txt = config['phone'] ?? '';
    }
    _controller = TextEditingController(text: txt);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final type = widget.channel['channel_type'] as String;
    final currentConfig = Map<String, dynamic>.from(
      widget.channel['config'] ?? {},
    );

    if (type == 'email') {
      currentConfig['email'] = _controller.text.trim();
    } else if (type == 'whatsapp') {
      String val = _controller.text.trim();
      val = val.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (val.startsWith('00')) {
        val = '+${val.substring(2)}';
      }
      if (!val.startsWith('+') && val.isNotEmpty) {
        if (val.length <= 9) {
          final profile = widget.ref.read(authControllerProvider).value;
          final homeCode = profile?.homeCountryCode;
          final countries =
              widget.ref.read(supportedCountriesProvider).value ?? [];
          String homeDial = '+20';
          if (countries.isNotEmpty) {
            try {
              homeDial = countries
                  .firstWhere((c) => c.isoCode == homeCode)
                  .dialingCode;
            } catch (_) {}
          }
          if (val.startsWith('0')) {
            val = val.substring(1);
          }
          val = '$homeDial$val';
        } else {
          val = '+$val';
        }
      }
      _controller.text = val;
      currentConfig['phone'] = val;
    }

    await widget.ref
        .read(notificationChannelsControllerProvider.notifier)
        .updateChannelConfig(type, currentConfig);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${type == 'email' ? 'Email' : 'WhatsApp'} detail saved successfully.',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.channel['channel_type'] as String;
    final config = widget.channel['config'] as Map<String, dynamic>? ?? {};

    if (type == 'telegram') {
      final chatId = config['chat_id'];
      final isBound = chatId != null && chatId.toString().isNotEmpty;

      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.darkCard : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isBound
                      ? Icons.check_circle_rounded
                      : Icons.pending_actions_rounded,
                  color: isBound ? AppColors.success : AppColors.warning,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  isBound ? 'Status: Linked' : 'Status: Unlinked',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isBound ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Link our Telegram Bot to receive validity alerts directly.',
              style: AppTextStyles.bodySmall.copyWith(
                color: widget.isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await HapticHelper.lightTick();
                  final user = widget.ref.read(authControllerProvider).value;
                  final userId = user?.id;
                  if (userId == null) return;
                  String bindParam = userId;
                  try {
                    final token = await Supabase.instance.client.rpc(
                      'create_telegram_bind_token',
                    );
                    if (token != null && token.toString().isNotEmpty) {
                      bindParam = token.toString();
                    }
                  } catch (_) {
                    // Fallback to userId if token RPC fails
                  }
                  final botUrl =
                      'https://t.me/KeepSIMsBot?start=bind_$bindParam';
                  final uri = Uri.parse(botUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.telegram, color: Colors.white, size: 16),
                label: const Text(
                  'Link Telegram Bot',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22D3EE),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    String hint = type == 'email'
        ? 'e.g. user@domain.com'
        : 'e.g. +96891234567';
    IconData icon = type == 'email' ? Icons.alternate_email : Icons.phone;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _controller,
                    keyboardType: type == 'email'
                        ? TextInputType.emailAddress
                        : TextInputType.phone,
                    style: TextStyle(
                      color: context.onSurfaceColor,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: widget.isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        icon,
                        color: widget.isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        size: 16,
                      ),
                      filled: true,
                      fillColor: widget.isDark
                          ? AppColors.darkCard
                          : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: widget.isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                height: 40,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          if (type == 'whatsapp') ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                'Enter full international format starting with + (e.g. +96893990492)',
                style: AppTextStyles.bodySmall.copyWith(
                  color: widget.isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
