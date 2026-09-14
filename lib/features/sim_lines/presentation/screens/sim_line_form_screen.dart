import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
//import 'package:keep_sims/features/sim_lines/domain/entities/sim_line.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:keep_sims/features/payments/presentation/screens/paypal_checkout_screen.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/features/sim_lines/domain/plan_payment.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/carrier_activity_notice.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/carrier_rules_sheet.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_liveness_result.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/carrier_liveness_badge.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/sim_otp_verification_sheet.dart';

import '../../data/models/carrier_rule_model.dart';

class SimLineFormScreen extends ConsumerStatefulWidget {
  final String? id;

  const SimLineFormScreen({super.key, this.id});

  @override
  ConsumerState<SimLineFormScreen> createState() => _SimLineFormScreenState();
}

class _SimLineFormScreenState extends ConsumerState<SimLineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nicknameController = TextEditingController();

  Country? _selectedCountry;
  Carrier? _selectedCarrier;
  String _selectedIcon = 'sim_card';
  String _selectedTier = 'free'; // default to free
  bool _isFreePlanDisabled = false;
  SimSetupQuote? _serverQuote;
  bool _isLoadingQuote = false;

  bool _isEdit = false;
  bool _hasPrepopulated = false;
  bool _isSaving = false;

  SimLivenessResult? _livenessResult;
  bool _isCheckingLiveness = false;
  Timer? _livenessDebounce;
  Timer? _quoteDebounce;

  /// The yearly base service fee both paid tiers carry, from
  /// `system_configs.BASE_SERVICE_FEE_USD` (C3c). Display only — the charge
  /// paths await the real rows via [PlanPayment].
  double get _baseServiceFeeUsd =>
      ref.watch(baseServiceFeeUsdProvider).value ?? kDefaultBaseServiceFeeUsd;

  /// `$2.50/yr`-style label used across the plan copy.
  String get _feePerYearLabel =>
      '\$${_baseServiceFeeUsd.toStringAsFixed(2)}/yr';

  @override
  void initState() {
    super.initState();
    _isEdit = widget.id != null;
    _phoneController.addListener(_onPhoneInputChanged);
  }

  @override
  void dispose() {
    _livenessDebounce?.cancel();
    _quoteDebounce?.cancel();
    _phoneController.removeListener(_onPhoneInputChanged);
    _phoneController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _onPhoneInputChanged() {
    _livenessDebounce?.cancel();
    _quoteDebounce?.cancel();
    // Clear previous verification result so user can explicitly verify the updated digits
    if (_livenessResult != null) {
      setState(() {
        _livenessResult = null;
      });
    }
    _quoteDebounce = Timer(const Duration(milliseconds: 600), () {
      _updateServerQuote();
    });
  }

  Future<void> _updateServerQuote() async {
    if (!mounted || _selectedCountry == null) return;
    String localNumber = _phoneController.text.trim();
    if (localNumber.startsWith('0')) {
      localNumber = localNumber.substring(1);
    }
    if (localNumber.length < 6) return;

    final fullNumber = '${_selectedCountry!.dialingCode}$localNumber';
    String? ruleId;
    if (_selectedCarrier != null) {
      final rule = ref.read(carrierRuleProvider(_selectedCarrier!.id)).value;
      ruleId = rule?.id;
    }

    setState(() {
      _isLoadingQuote = true;
    });

    final quote = await PlanPayment.fetchSimSetupQuote(
      phoneNumber: fullNumber,
      plan: _selectedTier,
      carrierRuleId: ruleId,
      simLineId: _isEdit ? widget.id : null,
    );

    if (mounted) {
      setState(() {
        _serverQuote = quote;
        _isLoadingQuote = false;
        if (quote != null && !quote.freeEligible && _selectedTier == 'free') {
          _selectedTier = 'standard';
        }
      });
    }
  }

  Future<SimLivenessResult?> _triggerLivenessCheck({bool showMissingError = true}) async {
    if (!mounted) return null;
    if (_selectedCountry == null) {
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

    String localNumber = _phoneController.text.trim();
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

    final fullNumber = '${_selectedCountry!.dialingCode}$localNumber';

    setState(() {
      _isCheckingLiveness = true;
    });

    try {
      final repo = ref.read(simLinesRepositoryProvider);
      final result = await repo.validateSimLiveness(
        fullNumber,
        countryCode: _selectedCountry?.isoCode,
      );

      if (mounted) {
        setState(() {
          _livenessResult = result;
          _isCheckingLiveness = false;
        });

        // Auto-match carrier if not yet selected and active
        if (_selectedCarrier == null &&
            result.detectedOperatorName != null &&
            _selectedCountry != null) {
          final carriers = ref.read(carriersForCountryProvider(_selectedCountry!.id)).value ?? [];
          final opLower = result.detectedOperatorName!.toLowerCase();
          final matched = carriers.firstWhereOrNull(
            (c) => opLower.contains(c.name.toLowerCase()) || c.name.toLowerCase().contains(opLower),
          );
          if (matched != null) {
            setState(() {
              _selectedCarrier = matched;
            });
            _updateServerQuote();
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
      if (_serverQuote != null && !_serverQuote!.freeEligible) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This phone number has already used its 6-month Free Plan grant. Please select Standard or Premium.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      setState(() {
        _selectedTier = 'free';
      });
      _updateServerQuote();
      return;
    }

    final planLabel = tierKey == 'premium' ? 'Premium Plan' : 'Standard Plan';

    // 1. If we already checked this number:
    if (_livenessResult != null) {
      if (_livenessResult!.carrierStatus == 'inactive') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _livenessResult!.message.isNotEmpty
                  ? _livenessResult!.message
                  : 'This SIM number is inactive or expired at the carrier. Cannot select $planLabel.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final isConfirmedActive = _livenessResult!.isActive || _livenessResult!.carrierStatus == 'active';
      if (!isConfirmedActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Carrier verification is unconfirmed for this line. Please verify via Voice Call or SMS Code first before selecting $planLabel.',
            ),
            backgroundColor: AppColors.warning,
            action: SnackBarAction(
              label: 'Verify Now',
              textColor: Colors.white,
              onPressed: _openOtpVerification,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      setState(() {
        _selectedTier = tierKey;
      });
      _updateServerQuote();
      return;
    }

    // 2. Otherwise, perform the live lookup automatically (same as Check Line button)
    final result = await _triggerLivenessCheck(showMissingError: true);
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

    final isConfirmedActive = result.isActive || result.carrierStatus == 'active';
    if (!isConfirmedActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Carrier verification is unconfirmed for this line. Please verify via Voice Call or SMS Code first before selecting $planLabel.',
          ),
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: 'Verify Now',
            textColor: Colors.white,
            onPressed: _openOtpVerification,
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() {
      _selectedTier = tierKey;
    });
    _updateServerQuote();
  }

  Future<void> _openOtpVerification() async {
    if (!mounted || _selectedCountry == null) return;
    String localNumber = _phoneController.text.trim();
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

    final fullNumber = '${_selectedCountry!.dialingCode}$localNumber';
    final result = await SimOtpVerificationSheet.show(
      context,
      fullPhoneNumber: fullNumber,
      carrierName: _selectedCarrier?.name,
      countryCode: _selectedCountry?.isoCode,
    );

    if (result != null && mounted) {
      setState(() {
        _livenessResult = result;
      });
    }
  }

  void _prepopulate(List<SimLine> lines, List<Country> countries) {
    if (_hasPrepopulated || !_isEdit || countries.isEmpty) return;

    final line = lines.firstWhereOrNull((l) => l.id == widget.id);
    if (line == null) return;

    _nicknameController.text = line.nickname ?? '';
    _selectedIcon = line.avatarIcon;
    _selectedTier = line.protectionTier;

    if (line.countryId != null) {
      _selectedCountry = countries.firstWhereOrNull(
        (c) => c.id == line.countryId,
      );
    }

    if (_selectedCountry != null &&
        line.phoneNumber.startsWith(_selectedCountry!.dialingCode)) {
      _phoneController.text = line.phoneNumber
          .substring(_selectedCountry!.dialingCode.length)
          .trim();
    } else {
      _phoneController.text = line.phoneNumber;
    }

    if (line.isCarrierVerified) {
      _livenessResult = SimLivenessResult(
        isActive: line.carrierStatus == 'active',
        carrierStatus: line.carrierStatus,
        detectedOperatorName: line.detectedOperatorName,
        verifiedAt: line.carrierVerifiedAt,
      );
    }

    _hasPrepopulated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateServerQuote());
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(simLinesControllerProvider).value ?? [];
    final countries = ref.watch(supportedCountriesProvider).value ?? [];
    final notificationChannels =
        ref.watch(notificationChannelsControllerProvider).value ?? [];

    if (_isEdit && !_hasPrepopulated) {
      _prepopulate(lines, countries);
    }

    // Carriers are dynamically retrieved based on selected country ID
    final carriers = _selectedCountry == null
        ? <Carrier>[]
        : ref.watch(carriersForCountryProvider(_selectedCountry!.id)).value ??
              [];

    // Pre-populate carrier in edit mode if needed
    if (_isEdit &&
        _hasPrepopulated &&
        _selectedCarrier == null &&
        _selectedCountry != null &&
        carriers.isNotEmpty) {
      final line = lines.firstWhereOrNull((l) => l.id == widget.id);
      if (line != null && line.carrierId != null) {
        final matched = carriers.firstWhereOrNull(
          (c) => c.id == line.carrierId,
        );
        if (matched != null) {
          _selectedCarrier = matched;
          WidgetsBinding.instance.addPostFrameCallback((_) => _updateServerQuote());
        }
      }
    }

    final isDark = context.isDarkMode;

    // Fetch premium pricing if carrier is selected
    CarrierRule? premiumRule;
    bool isPremiumLoading = false;
    if (_selectedCountry != null && _selectedCarrier != null) {
      final ruleAsync = ref.watch(carrierRuleProvider(_selectedCarrier!.id));
      premiumRule = ruleAsync.value;
      isPremiumLoading = ruleAsync.isLoading;
    }

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isEdit
              ? AppLocalizations.of(context)!.editProtectedLine
              : AppLocalizations.of(context)!.protectNewLine,
          style: AppTextStyles.headlineLarge.copyWith(
            color: context.onSurfaceColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.onSurfaceColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isSaving
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Country Selection Lookups
                    _buildSectionHeader(context, 'COUNTRY OF HOME'),
                    const SizedBox(height: 12),
                    _buildCountryPicker(context, countries),
                    const SizedBox(height: 24),

                    // Phone Number Field
                    _buildSectionHeader(context, 'SIM PHONE NUMBER'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedCountry != null
                                    ? _selectedCountry!.flagEmoji
                                    : '🌐',
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedCountry?.dialingCode ?? '+00',
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
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(
                              color: context.onSurfaceColor,
                              fontSize: 16,
                              fontFamily: 'monospace',
                            ),
                            decoration: _buildInputDecoration(
                              context,
                              hintText: 'Your SIM card phone number',
                              icon: Icons.phone_android,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter phone number';
                              }
                              if (_selectedCountry == null) {
                                return 'Please select a country first';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    CarrierLivenessBadge(
                      result: _livenessResult,
                      isLoading: _isCheckingLiveness,
                      onCheck: _triggerLivenessCheck,
                      onRetry: _triggerLivenessCheck,
                      onOtpVerify: _openOtpVerification,
                    ),
                    const SizedBox(height: 24),

                    // Dynamic Carrier brand dropdown
                    _buildSectionHeader(context, 'CARRIER BRAND'),
                    const SizedBox(height: 12),
                    _buildCarrierPicker(carriers),
                    const SizedBox(height: 24),

                    // Custom Nickname
                    _buildSectionHeader(context, 'NICKNAME (OPTIONAL)'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nicknameController,
                      style: TextStyle(
                        color: context.onSurfaceColor,
                        fontSize: 16,
                      ),
                      decoration: _buildInputDecoration(
                        context,
                        hintText: 'e.g. My Egypt Orange SIM',
                        icon: Icons.label_outline,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Protection Tier Dynamic Billing Info Card
                    _buildSectionHeader(context, 'PROTECTION BILLING DETAILS'),
                    const SizedBox(height: 12),
                    // i7: above the tiers, not below them — if this carrier
                    // cannot be protected by refilling, the user should know
                    // before they read a price.
                    if (premiumRule != null)
                      CarrierActivityNotice(
                        rule: premiumRule,
                        carrierName: _selectedCarrier?.name,
                      ),
                    _buildTierGrid(premiumRule, isPremiumLoading),
                    const SizedBox(height: 32),
                    _buildDynamicBillingSection(
                      _selectedTier,
                      premiumRule,
                      isPremiumLoading,
                    ),
                    const SizedBox(height: 48),

                    // Notification Info
                    _buildSectionHeader(context, 'NOTIFICATION PREFERENCES'),
                    const SizedBox(height: 12),
                    _buildNotificationInfo(notificationChannels, _selectedTier),
                    const SizedBox(height: 32),

                    // Glowing Action Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveLine,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shadowColor: AppColors.primary.withValues(alpha: 0.5),
                          elevation: 10,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _isEdit
                              ? AppLocalizations.of(context)!.saveChanges
                              : AppLocalizations.of(
                                  context,
                                )!.activateShieldProtection,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    VoidCallback? onHelpTap,
  }) {
    final isDark = context.isDarkMode;
    final textWidget = Text(
      title,
      style: AppTextStyles.labelMedium.copyWith(
        color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );

    if (onHelpTap == null) return textWidget;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        textWidget,
        IconButton(
          onPressed: onHelpTap,
          icon: Icon(
            Icons.help_outline_rounded,
            color: context.primaryColor,
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(
    BuildContext context, {
    required String hintText,
    required IconData icon,
    String? prefixText,
  }) {
    final isDark = context.isDarkMode;
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDark
            ? AppColors.textTertiaryDark
            : AppColors.textTertiaryLight,
      ),
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontSize: 16),
      prefixIcon: Icon(
        icon,
        color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
        size: 20,
      ),
      filled: true,
      fillColor: isDark ? AppColors.darkCard : const Color(0xFFEAEEF1),
      errorStyle: const TextStyle(color: AppColors.error),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? AppColors.primary : AppColors.lightPrimary,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }

  Widget _buildCountryPicker(BuildContext context, List<Country> countries) {
    final isDark = context.isDarkMode;
    return InkWell(
      onTap: () => _showCountrySearchSheet(countries),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: AppColors.lightPrimary.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Text(
              _selectedCountry != null
                  ? '${_selectedCountry!.flagEmoji} '
                  : '🌐 ',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedCountry != null
                    ? '${_selectedCountry!.name} (${_selectedCountry!.dialingCode})'
                    : 'Select Country',
                style: TextStyle(
                  color: _selectedCountry != null
                      ? context.onSurfaceColor
                      : (isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight),
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarrierPicker(List<Carrier> carriers) {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.lightPrimary.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<Carrier>(
          initialValue: _selectedCarrier,
          hint: Text(
            AppLocalizations.of(context)!.carrier,
            style: const TextStyle(color: Colors.white54),
          ),
          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
          style: TextStyle(color: context.onSurfaceColor, fontSize: 16),
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          items: carriers.map((c) {
            return DropdownMenuItem<Carrier>(value: c, child: Text(c.name));
          }).toList(),
          onChanged: (carrier) {
            setState(() {
              _selectedCarrier = carrier;
            });
            _updateServerQuote();
          },
          decoration: const InputDecoration(border: InputBorder.none),
          validator: (value) {
            if (value == null) {
              return 'Please select a carrier brand';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildNotificationInfo(
    List<Map<String, dynamic>> channels,
    String selectedTier,
  ) {
    final isDark = context.isDarkMode;

    final bool isFree =
        selectedTier.toLowerCase() == 'basic' ||
        selectedTier.toLowerCase() == 'free';

    // Extract channel statuses
    final whatsappConfig = channels.firstWhereOrNull(
      (c) => c['channel_type'] == 'whatsapp',
    );
    final telegramConfig = channels.firstWhereOrNull(
      (c) => c['channel_type'] == 'telegram',
    );
    final emailConfig = channels.firstWhereOrNull(
      (c) => c['channel_type'] == 'email',
    );

    final whatsappPhone =
        (whatsappConfig?['config'] as Map<String, dynamic>?)?['phone']
            as String? ??
        '';
    final hasWhatsApp = whatsappPhone.isNotEmpty;
    final hasTelegram =
        (telegramConfig?['config'] as Map<String, dynamic>?)?['chat_id'] !=
        null;
    final hasEmail =
        ((emailConfig?['config'] as Map<String, dynamic>?)?['email'] as String?)
            ?.isNotEmpty ==
        true;

    String message;
    if (isFree) {
      message =
          'Alerts via Push notifications only. '
          'Upgrade to a paid plan to unlock WhatsApp, Telegram & Email channels.';
    } else {
      // Build a list of active channels
      final List<String> activeChannels = ['Push'];
      if (hasWhatsApp) activeChannels.add('WhatsApp ($whatsappPhone)');
      if (hasTelegram) activeChannels.add('Telegram');
      if (hasEmail) activeChannels.add('Email');

      if (activeChannels.length == 1) {
        // Only Push is active, nudge to configure more
        message =
            'Alerts via Push only. '
            'You can also enable WhatsApp, Telegram & Email from Alert Preferences.';
      } else {
        message = 'Alerts via ${activeChannels.join(', ')}.';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: context.onSurfaceColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage channels in More → Alert Preferences.',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 12,
                  ),
                ),
              ],
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
        'This line is protected for free for 6 months. Basic alerts only. No auto-refills.';
    String billingRate = 'FREE';

    final annualFee = _serverQuote?.annualFeeUsd ?? _baseServiceFeeUsd;
    final firstRefill = _serverQuote?.firstRefillCostUsd ?? (premiumRule?.minimumTopupAmount ?? 0.59);
    final totalDue = _serverQuote?.totalChargeUsd ?? (annualFee + firstRefill);
    final bool showPremiumBreakdown = isPremium &&
        (_serverQuote != null || premiumRule != null) &&
        !CarrierActivityNotice.blocksPremium(premiumRule);

    if (isPremium) {
      planName = 'Premium Plan';
      planColor = isDark ? Colors.purpleAccent : Colors.purple;
      if (isPremiumLoading || _isLoadingQuote) {
        billingDesc = 'Loading premium pricing rules for this carrier...';
        billingRate = '$_feePerYearLabel + ...';
      } else if (premiumRule != null && premiumRule.requiresHumanUsage) {
        billingRate = '\$5.00 / yr';
        billingDesc =
            'Includes Premium account benefits (discounted calling & eSIM) and \$1.00 alert allowance pool. Automated refills are locked because this carrier requires manual call/SMS activity.';
      } else if (_serverQuote != null || premiumRule != null) {
        billingRate = '\$${totalDue.toStringAsFixed(2)} Today';
        billingDesc =
            'Includes your 1st SIM recharge to verify the line immediately. Future refills are billed individually from your wallet balance when due.';
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
          'Automated tracking & expiry alerts. You will be billed \$${annualFee.toStringAsFixed(2)}/yr for this line.';
      billingRate = '\$${annualFee.toStringAsFixed(2)}/yr';
    } else {
      if (_serverQuote != null && !_serverQuote!.freeEligible) {
        planName = 'Free Plan (Ineligible)';
        planColor = isDark ? AppColors.error : Colors.redAccent;
        billingDesc =
            'This phone number has already utilized its 6-month Free Plan grant. Please choose the Standard or Premium Plan.';
        billingRate = 'LIMIT REACHED';
      }
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
                child: Text(
                  billingRate,
                  style: AppTextStyles.caption.copyWith(
                    color: planColor,
                    fontWeight: FontWeight.w900,
                  ),
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
          if (showPremiumBreakdown) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: planColor.withValues(alpha: isDark ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: planColor.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Annual Protection Fee',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.onSurfaceColor,
                        ),
                      ),
                      Text(
                        '\$${annualFee.toStringAsFixed(2)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.onSurfaceColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '1st SIM Recharge (Live Verification)',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.onSurfaceColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 14,
                            color: AppColors.success,
                          ),
                        ],
                      ),
                      Text(
                        '\$${firstRefill.toStringAsFixed(2)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.onSurfaceColor,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Due Today',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.onSurfaceColor,
                        ),
                      ),
                      Text(
                        '\$${totalDue.toStringAsFixed(2)} USD',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w900,
                          color: planColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Only successful recharges are charged. If verification fails, 100% of your funds are returned to your wallet balance immediately.',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (isStandard) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.phone_in_talk_outlined,
                  size: 16,
                  color: planColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Includes automated network reachability check by phone ring (zero talk-time deduction).',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
          // i8: the price above is only half the story. This opens the carrier's
          // actual deactivation window, its grace period, what a top-up has to
          // be worth — and an opinion on whether to buy anything at all.
          if (premiumRule != null && _selectedCarrier != null)
            _buildCarrierRulesLink(premiumRule, planColor),
          if (isPremium && _selectedCarrier?.name.toLowerCase().contains('mobily') == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.amber : Colors.orange).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark ? Colors.amber : Colors.orange).withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: isDark ? Colors.amberAccent : Colors.orange.shade800,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PIN Voucher Fulfillment: Direct network recharge is not available for this carrier. On each scheduled refill, you will receive an instant digital PIN voucher in the app with 1-tap dialer activation (*1400*PIN#).',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? Colors.amber.shade100
                            : Colors.orange.shade900,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          carrierId: _selectedCarrier!.id,
          carrierName: _selectedCarrier!.name,
          countryName: _selectedCountry?.name,
          // Withheld for a carrier we refuse to sell Premium on: a price beside
          // a refusal reads as an offer.
          premiumYearlyTotal: CarrierActivityNotice.blocksPremium(rule)
              ? null
              : PlanPayment.premiumYearlyTotalSync(ref, rule),
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

    // Free plan is permanently available ($0 forever) with no 6-month restrictions
    _isFreePlanDisabled = false;

    final tiers = [
      {
        'key': 'free',
        'name': 'Free Plan',
        'desc': 'Permanent Free Protection. Manual refills (7% fee), basic reminders.',
      },
      {
        'key': 'standard',
        'name': 'Standard Plan (\$2.50/yr)',
        'desc': 'Annual Membership. 5% refill fee, annual SMS/WhatsApp alert allowance (\$0.50 pool).',
      },
      {
        'key': 'premium',
        'name': 'Premium Plan (\$5.00/yr)',
        'desc': 'Automated Protection. 100% automated refills (lowest 3% fee), \$1.00 alert allowance pool, priority support.',
      },
    ];

    return Column(
      children: tiers.map((tier) {
        final isSelected = _selectedTier == tier['key'];
        final isDisabled = tier['key'] == 'free' && _isFreePlanDisabled;

        final isChecking = _isCheckingLiveness && (tier['key'] == 'standard' || tier['key'] == 'premium');

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
                            color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                          ),
                        ),
                      )
                    else
                      Radio<String>(
                        value: tier['key']!,
                        groupValue: _selectedTier,
                        activeColor: isDark
                            ? AppColors.primaryLight
                            : AppColors.lightPrimary,
                        onChanged: isDisabled || _isCheckingLiveness
                            ? null
                            : (val) {
                                if (val != null) {
                                  _onTierSelected(val);
                                }
                              },
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
                                (isDisabled ? ' (Already used for this number)' : ''),
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontSize: 12,
                            ),
                          ),
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

  void _showCountrySearchSheet(List<Country> countries) {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.isDarkMode
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCountries = countries.where((c) {
              final query = searchQuery.toLowerCase();
              return c.name.toLowerCase().contains(query) ||
                  c.dialingCode.contains(query);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: context.isDarkMode
                                ? Colors.white24
                                : Colors.black12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Text(
                        'Supported Countries',
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: context.isDarkMode
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        style: TextStyle(
                          color: context.isDarkMode
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search country or code...',
                          hintStyle: TextStyle(
                            color: context.isDarkMode
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: context.isDarkMode
                                ? AppColors.primaryLight
                                : AppColors.lightPrimary,
                          ),
                          filled: true,
                          fillColor: context.isDarkMode
                              ? AppColors.darkCard
                              : const Color(0xFFEAEEF1),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.isDarkMode
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.isDarkMode
                                  ? AppColors.primary
                                  : AppColors.lightPrimary,
                            ),
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: context.isDarkMode
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                  onPressed: () {
                                    setModalState(() {
                                      searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filteredCountries.isEmpty
                            ? Center(
                                child: Text(
                                  'No countries found',
                                  style: TextStyle(
                                    color: context.isDarkMode
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filteredCountries.length,
                                itemBuilder: (context, index) {
                                  final c = filteredCountries[index];
                                  final isSelected =
                                      _selectedCountry?.id == c.id;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (context.isDarkMode
                                                ? AppColors.primary.withValues(
                                                    alpha: 0.15,
                                                  )
                                                : AppColors.lightPrimary
                                                      .withValues(alpha: 0.15))
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: Text(
                                        c.flagEmoji,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                      title: Text(
                                        c.name,
                                        style: TextStyle(
                                          color: isSelected
                                              ? (context.isDarkMode
                                                    ? AppColors.primaryLight
                                                    : AppColors.lightPrimary)
                                              : (context.isDarkMode
                                                    ? Colors.white
                                                    : AppColors
                                                          .textPrimaryLight),
                                          fontSize: 16,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      subtitle: Text(
                                        c.dialingCode,
                                        style: TextStyle(
                                          color: context.isDarkMode
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                      trailing: isSelected
                                          ? Icon(
                                              Icons.check_circle_rounded,
                                              color: context.isDarkMode
                                                  ? AppColors.primaryLight
                                                  : AppColors.lightPrimary,
                                            )
                                          : null,
                                      onTap: () {
                                        setState(() {
                                          _selectedCountry = c;
                                          _selectedCarrier = null; // Reset carrier
                                          _livenessResult = null; // Reset verification
                                        });
                                        _updateServerQuote();
                                        Navigator.pop(context);
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _saveLine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCountry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a country'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String localNumber = _phoneController.text.trim();
    if (localNumber.startsWith('0')) {
      localNumber = localNumber.substring(1);
    }
    final fullPhoneNumber = '${_selectedCountry!.dialingCode}$localNumber';

    final currentLines = ref.read(simLinesControllerProvider).value ?? [];
    final isDuplicate = currentLines.any(
      (l) => l.phoneNumber == fullPhoneNumber && l.id != widget.id,
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This phone number is already protected in your account.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final selectedPlanType = _selectedTier;
      String? carrierRuleId;

      if (selectedPlanType == 'premium') {
        if (_selectedCarrier == null) {
          throw Exception('Please select a carrier before choosing the Premium plan.');
        }
        final rule = await ref
            .read(simLinesRepositoryProvider)
            .getCarrierRule(_selectedCarrier!.id);
        if (rule != null) {
          carrierRuleId = rule.id;
        } else {
          throw Exception(
            'Premium pricing not configured for this carrier. Please select Standard plan.',
          );
        }
      }

      // Check if newly chosen plan needs payment
      final originalPlan = _isEdit
          ? currentLines
                .firstWhereOrNull((l) => l.id == widget.id)
                ?.planType
                .trim()
                .toLowerCase()
          : null;
      final needsCharge =
          selectedPlanType != 'free' && originalPlan != selectedPlanType;

      Future<SimLine> commitSave({
        required String planType,
        required String protectionTier,
        DateTime? planExpiresAt,
        bool isCarrierVerified = false,
        String carrierStatus = 'pending',
        String? verificationStatus,
        DateTime? lastTopupDate,
        bool isDraft = false,
      }) async {
        if (_isEdit) {
          final line = currentLines.firstWhereOrNull((l) => l.id == widget.id);
          if (line == null) {
            throw StateError('SIM line not found for ID: ${widget.id}');
          }
          final updatedLine = line.copyWith(
            phoneNumber: fullPhoneNumber,
            nickname: _nicknameController.text.isNotEmpty
                ? _nicknameController.text
                : null,
            avatarIcon: _selectedIcon,
            countryId: _selectedCountry?.id,
            carrierId: _selectedCarrier?.id,
            planType: planType,
            protectionTier: protectionTier,
            planExpiresAt: planExpiresAt,
            carrierRuleId: carrierRuleId,
            isCarrierVerified: isCarrierVerified,
            carrierStatus: carrierStatus,
            verificationStatus: verificationStatus ?? line.verificationStatus,
            lastTopupAt: lastTopupDate ?? line.lastTopupAt,
            carrierVerifiedAt: isCarrierVerified ? DateTime.now() : line.carrierVerifiedAt,
          );
          await ref
              .read(simLinesControllerProvider.notifier)
              .updateSimLine(updatedLine);
          return updatedLine;
        } else {
          final created = await ref
              .read(simLinesControllerProvider.notifier)
              .addSimLine(
                phoneNumber: fullPhoneNumber,
                nickname: _nicknameController.text.isNotEmpty
                    ? _nicknameController.text
                    : null,
                avatarIcon: _selectedIcon,
                countryId: _selectedCountry?.id,
                carrierId: _selectedCarrier?.id,
                planType: planType,
                protectionTier: protectionTier,
                planExpiresAt: planExpiresAt,
                carrierRuleId: carrierRuleId,
                isCarrierVerified: isCarrierVerified,
                carrierStatus: carrierStatus,
                carrierVerifiedAt: isCarrierVerified ? DateTime.now() : null,
                isDraft: isDraft,
              );
          return created;
        }
      }

      if (!needsCharge) {
        // Free plan or existing unchanged paid plan
        if (selectedPlanType == 'free' && _serverQuote != null && !_serverQuote!.freeEligible) {
          throw Exception(
            'This phone number has already utilized its 6-month Free Plan grant. Please choose Standard or Premium.',
          );
        }

        await commitSave(
          planType: selectedPlanType,
          protectionTier: selectedPlanType == 'free' ? 'basic' : selectedPlanType,
          planExpiresAt: selectedPlanType == 'free'
              ? DateTime.now().add(const Duration(days: 180))
              : DateTime.now().add(const Duration(days: 365)),
        );
        ref.invalidate(simLinesControllerProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                selectedPlanType == 'free'
                    ? 'SIM line saved with 6 Months Free Plan.'
                    : 'SIM line saved successfully.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      // ── Handle Setup Order & Reservation ──
      final orderRes = await PlanPayment.createSimSetupOrder(
        phoneNumber: fullPhoneNumber,
        plan: selectedPlanType,
        carrierRuleId: carrierRuleId,
        countryCode: _selectedCountry?.isoCode,
        carrierCode: _selectedCarrier?.name,
        simLineId: _isEdit ? widget.id : null,
      );

      if (orderRes == null || orderRes['order_id'] == null) {
        throw Exception('Failed to initialize SIM setup order.');
      }

      final orderId = orderRes['order_id'] as String;
      final totalChargeUsd = (orderRes['total_charge_usd'] as num?)?.toDouble() ?? 2.50;
      final annualFeeUsd = (orderRes['annual_fee_usd'] as num?)?.toDouble() ?? 2.50;

      // Security check (Biometrics / 4-digit token)
      final phoneDigits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final confirmationToken = phoneDigits.length <= 4
          ? phoneDigits
          : phoneDigits.substring(phoneDigits.length - 4);
      if (!mounted) return;
      final authGuard = ref.read(paymentAuthGuardProvider);
      final authOk = await authGuard.confirmPaymentInteractive(
        context,
        reason: 'Authorize payment of \$${totalChargeUsd.toStringAsFixed(2)} for ${selectedPlanType.toUpperCase()} plan setup',
        confirmationToken: confirmationToken,
      );
      if (!authOk) {
        setState(() => _isSaving = false);
        return;
      }

      // Reserve holds
      var reserveRes = await PlanPayment.reserveSimSetupHolds(orderId);
      if (reserveRes['success'] == false && reserveRes['error'] == 'insufficient_balance') {
        final shortfall = (reserveRes['shortfall'] as num).toDouble();
        final depositAmount = shortfall < 5.00 ? 5.00 : shortfall;
        final currentBal = (reserveRes['current_balance'] as num?)?.toDouble() ?? 0.0;

        setState(() => _isSaving = false);
        if (!mounted) return;
        final shouldDeposit = await _showShortfallDepositDialog(
          context: context,
          currentBalance: currentBal,
          basePlanFee: totalChargeUsd,
          depositAmount: depositAmount,
          planName: selectedPlanType == 'premium' ? 'Premium' : 'Standard',
        );

        if (shouldDeposit != true) return;

        setState(() => _isSaving = true);
        final paypalOk = await _launchPayPalDeposit(
          depositAmount: depositAmount,
          plan: selectedPlanType,
          orderId: orderId,
        );

        if (!paypalOk) {
          setState(() => _isSaving = false);
          return;
        }

        reserveRes = await PlanPayment.reserveSimSetupHolds(orderId);
        if (reserveRes['success'] != true) {
          throw Exception('Could not reserve funds after deposit: ${reserveRes['error']}');
        }
      } else if (reserveRes['success'] != true) {
        throw Exception(reserveRes['error'] ?? 'Reservation failed');
      }

      // ── If Standard Plan: finalize order and activate immediately ──
      if (selectedPlanType == 'standard') {
        final saved = await commitSave(
          planType: 'standard',
          protectionTier: 'standard',
          planExpiresAt: DateTime.now().add(const Duration(days: 365)),
          isCarrierVerified: false,
          carrierStatus: 'pending',
          verificationStatus: 'unverified',
          isDraft: false,
        );

        final finalizeRes = await PlanPayment.finalizeSimSetupOrder(
          orderId,
          simLineId: saved.id,
        );
        if (finalizeRes['success'] != true) {
          throw Exception(finalizeRes['error'] ?? 'Failed to finalize standard plan activation');
        }

        ref.invalidate(simLinesControllerProvider);
        ref.invalidate(scheduledTopupControllerProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Standard Plan activated! Annual protection secured.'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      // ── If Premium Plan: Live verification recharge via Queue ──
      // 1. Commit draft row
      final saved = await commitSave(
        planType: 'premium',
        protectionTier: 'premium',
        planExpiresAt: DateTime.now().add(const Duration(days: 365)),
        isCarrierVerified: false,
        carrierStatus: 'pending',
        isDraft: true,
      );

      // 2. Dispatch the live verification recharge via topup_executions queue
      final dispatchRes = await PlanPayment.dispatchSimSetupVerification(
        orderId: orderId,
        simLineId: saved.id,
      );

      if (dispatchRes['success'] != true) {
        throw Exception(dispatchRes['error'] ?? 'Could not dispatch verification recharge.');
      }

      // 3. Poll finalizeSimSetupOrder for execution result (up to 15 attempts * 2s = 30s)
      Map<String, dynamic>? finalOutcome;
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 2000));
        if (!mounted) return;
        final res = await PlanPayment.finalizeSimSetupOrder(orderId);
        if (res['status'] == 'active' || res['success'] == true) {
          finalOutcome = res;
          break;
        } else if (res['status'] == 'failed') {
          finalOutcome = res;
          break;
        }
      }

      if (finalOutcome != null && (finalOutcome['status'] == 'active' || finalOutcome['success'] == true)) {
        // Success!
        ref.invalidate(simLinesControllerProvider);
        ref.invalidate(scheduledTopupControllerProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Premium Plan activated! Line verified with live recharge.'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } else if (finalOutcome != null && finalOutcome['status'] == 'failed') {
        // Recharge Failed: Holds were released on server. Show fallback sheet
        final errorMsg = finalOutcome['reason']?.toString() ??
            finalOutcome['failure_reason']?.toString() ??
            'Carrier could not deliver initial recharge.';

        setState(() => _isSaving = false);

        if (mounted) {
          await _showSetupFailureSheet(
            totalAmount: totalChargeUsd,
            annualFee: annualFeeUsd,
            failureReason: errorMsg,
            isFreeEligible: _serverQuote?.freeEligible ?? true,
            onUseAnotherNumber: () async {
              await PlanPayment.cancelSimSetupOrder(orderId, reason: 'User chose another number');
              if (!_isEdit) {
                try {
                  await ref.read(simLinesRepositoryProvider).deleteSimLine(saved.id);
                  ref.invalidate(simLinesControllerProvider);
                  ref.invalidate(scheduledTopupControllerProvider);
                } catch (_) {}
              }
            },
            onFallbackToReminders: () async {
              setState(() => _isSaving = true);
              final targetPlan = (_serverQuote?.freeEligible ?? true) ? 'free' : 'standard';
              final fallbackRes = await PlanPayment.fallbackSimSetupToReminders(
                orderId: orderId,
                simLineId: saved.id,
                fallbackPlan: targetPlan,
              );
              if (fallbackRes['success'] == true) {
                ref.invalidate(simLinesControllerProvider);
                ref.invalidate(scheduledTopupControllerProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        targetPlan == 'free'
                            ? 'Saved with 6 Months Free Plan. Manual reminders active.'
                            : 'Saved with Standard Plan (\$2.50/yr). Manual reminders active.',
                      ),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                  Navigator.pop(context);
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to switch plan: ${fallbackRes['message'] ?? fallbackRes['error']}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
          );
        }
      } else {
        // Polling timeout: Still processing in background
        ref.invalidate(simLinesControllerProvider);
        ref.invalidate(scheduledTopupControllerProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Verification recharge is processing in the background. Your line will activate automatically once confirmed.',
              ),
              backgroundColor: AppColors.primary,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process SIM line: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _launchPayPalDeposit({
    required double depositAmount,
    required String plan,
    required String orderId,
  }) async {
    final completer = Completer<bool>();
    if (!mounted) return false;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => PayPalCheckoutScreen(
          initialAmount: depositAmount,
          paymentReason: 'Wallet deposit for ${plan == 'premium' ? 'Premium' : 'Standard'} plan setup',
          paymentKind: 'deposit',
          plan: plan,
          simLineId: _isEdit ? widget.id : null,
          onSuccess: () async {
            Navigator.of(ctx).pop();
            try {
              await PlanPayment.waitForWalletCredit(
                ref,
                atLeast: depositAmount,
              );
              completer.complete(true);
            } catch (_) {
              completer.complete(true);
            }
          },
        ),
      ),
    );

    return completer.future;
  }

  Future<void> _showSetupFailureSheet({
    required double totalAmount,
    required double annualFee,
    required String failureReason,
    required bool isFreeEligible,
    required VoidCallback onUseAnotherNumber,
    required Future<void> Function() onFallbackToReminders,
  }) {
    final isDark = context.isDarkMode;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Verification Recharge Failed',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.onSurfaceColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your number may be inactive or unable to receive this recharge. Premium has not started.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.onSurfaceColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'The full amount of \$${totalAmount.toStringAsFixed(2)}, including the \$${annualFee.toStringAsFixed(2)} subscription fee, has been returned to your KeepSIMs wallet.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark ? Colors.green.shade200 : Colors.green.shade900,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Only successful recharges are charged.',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onUseAnotherNumber();
                  },
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text(
                    'Use another number',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await onFallbackToReminders();
                  },
                  child: Text(
                    isFreeEligible
                        ? 'Use Free Reminders for 6 months (\$0.00)'
                        : 'Use Standard Reminders (\$${annualFee.toStringAsFixed(2)}/year)',
                    style: TextStyle(
                      color: context.onSurfaceColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/wallet');
                  },
                  child: Text(
                    'View KeepSIMs Wallet',
                    style: TextStyle(
                      color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Pay for the plan with PayPal (the wallet could not cover it) ─────────
  //
  // This used to be an "Insufficient Wallet Balance" top-up sheet, and every
  // number in it described a deposit that is no longer made. It also stated a
  // grossed-up total that was never charged: the button said $10.36 while
  // checkout was opened for $9.52, because the caller passed the *net*. The
  // breakdown now describes exactly one thing — the PayPal charge for the plan.
  Future<bool?> _showShortfallDepositDialog({
    required BuildContext context,
    required double currentBalance,
    required double basePlanFee,
    required double depositAmount,
    required String planName,
  }) {
    final isDark = context.isDarkMode;
    final remainder = (currentBalance + depositAmount) - basePlanFee;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.amber.shade800,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Funds & Activate',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.onSurfaceColor,
                          ),
                        ),
                        Text(
                          'Your wallet cannot cover the $planName Plan',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$planName Plan (1 year):',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          '\$${basePlanFee.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: context.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Wallet Balance:',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          '\$${currentBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Required Deposit:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${depositAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: Color(0xFF0070BA),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0070BA).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF0070BA),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Minimum PayPal deposit is \$5.00. Funds will be deposited to your wallet, then \$${basePlanFee.toStringAsFixed(2)} will be debited for your plan.'
                        '${remainder > 0.001 ? ' Remaining \$${remainder.toStringAsFixed(2)} stays in your wallet for future refills or services.' : ''}',
                        style: AppTextStyles.caption.copyWith(
                          color: context.onSurfaceColor.withValues(alpha: 0.85),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0070BA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.payment_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Deposit \$${depositAmount.toStringAsFixed(2)} & Activate Plan',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
      priceStr = '\$5.00';
      billingPeriod = '/yr per line';
      features = [
        '100% automated keep-alive refills',
        'Lowest refill fee: 3% (\$0.10 min)',
        '\$1.00 annual alert allowance pool (SMS/WhatsApp)',
        'Account Halo: discounted calling & eSIM rates',
        'Custom auto-refill scheduling',
        'Unlimited SIM lines',
        'Priority support',
      ];
    } else if (isStandard) {
      title = 'Standard Plan';
      icon = Icons.verified_user_rounded;
      accentColor = const Color(0xFF1565C0); // Blue
      priceStr = '\$2.50';
      billingPeriod = '/yr per line';
      features = [
        'Annual membership (\$2.50/yr)',
        'Reduced refill fee: 5% (\$0.30 min)',
        '\$0.50 annual alert allowance pool (SMS/WhatsApp)',
        'Push & offline SMS/WhatsApp alerts',
        'Manual refill requests',
        'Standard support',
      ];
    } else {
      title = 'Free Plan';
      icon = Icons.info_outline_rounded;
      accentColor = const Color(0xFF757575); // Grey
      priceStr = 'FREE';
      billingPeriod = 'permanent (\$0/yr)';
      features = [
        'Permanent line protection (\$0 forever)',
        'Manual refills with 7% app fee (\$0.50 min)',
        'Push notification expiry alerts',
        'Manual verification checks',
        'Unlimited SIM lines',
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
                            Text(
                              priceStr,
                              style: AppTextStyles.titleLarge.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
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
                              Text(
                                '+ ${premiumRule.inappPricing} ${premiumRule.inappPricingCurrency.toUpperCase()} refill',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor.withValues(alpha: 0.7),
                                ),
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
                                  'Auto-refill: ${premiumRule.inappPricing} ${premiumRule.inappPricingCurrency.toUpperCase()} every ${premiumRule.refillIntervalDays} days (telecom, VAT included)',
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
