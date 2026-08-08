import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
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
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/sim_lines/domain/plan_payment.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/carrier_activity_notice.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/carrier_rules_sheet.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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

  bool _isEdit = false;
  bool _hasPrepopulated = false;
  bool _isSaving = false;

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
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nicknameController.dispose();
    super.dispose();
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

    _hasPrepopulated = true;
  }

  void _onPhoneChanged(String val, List<Country> countries) {
    // Basic auto-detection no longer needed since country is chosen first.
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(simLinesControllerProvider).value ?? [];
    final countries = ref.watch(supportedCountriesProvider).value ?? [];
    final user = ref.watch(authControllerProvider).value;
    final globalTier = user?.subscriptionTier ?? 'standard';
    final notificationChannels =
        ref.watch(notificationChannelsControllerProvider).value ?? [];

    final existingLinesCount = _isEdit
        ? lines.where((l) => l.id != widget.id).length
        : lines.length;
    final lineOrdinalPosition = existingLinesCount + 1;

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
    final bool isFree = selectedTier == 'free';

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
        // Same computed quote as onboarding — the whole year charged once, not
        // the stored inapp_pricing snapshot the old copy showed.
        final cur = premiumRule.inappPricingCurrency.toUpperCase();
        billingDesc =
            'Fully automated top-ups. ${PlanPayment.premiumYearlyTotalSync(ref, premiumRule).toStringAsFixed(2)} $cur charged once for the year — '
            '\$${_baseServiceFeeUsd.toStringAsFixed(2)} service plus '
            '${premiumRule.refillsPerYear} refills of '
            '${PlanPayment.premiumRefillPriceSync(ref, premiumRule).toStringAsFixed(2)} $cur, one every ${premiumRule.refillIntervalDays} days.';
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
          // i8: the price above is only half the story. This opens the carrier's
          // actual deactivation window, its grace period, what a top-up has to
          // be worth — and an opinion on whether to buy anything at all.
          if (premiumRule != null && _selectedCarrier != null)
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
    final currentLines = ref.read(simLinesControllerProvider).value ?? [];

    // Check if free plan should be disabled
    final hasFreeLine = currentLines.any(
      (l) => l.planType == 'free' && l.id != widget.id,
    );
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

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: isDisabled
                ? null
                : () {
                    setState(() {
                      _selectedTier = tier['key']!;
                    });
                  },
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
                    Radio<String>(
                      value: tier['key']!,
                      groupValue: _selectedTier,
                      activeColor: isDark
                          ? AppColors.primaryLight
                          : AppColors.lightPrimary,
                      onChanged: isDisabled
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedTier = val;
                                });
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
                                (isDisabled ? ' (Limit Reached)' : ''),
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
                                          _selectedCarrier =
                                              null; // Reset carrier
                                        });
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
      CarrierRule? premiumRule;
      DateTime? planExpiresAt;

      // Ensure premium lines have pricing
      if (selectedPlanType == 'premium' &&
          _selectedCountry != null &&
          _selectedCarrier != null) {
        final rule = await ref
            .read(simLinesRepositoryProvider)
            .getCarrierRule(_selectedCarrier!.id);
        if (rule != null) {
          // i7: last gate before payment. queue_premium_refill_executions
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
          premiumRule = rule;
        } else {
          throw Exception(
            'Premium pricing not configured for this carrier. Please select Standard plan.',
          );
        }
      }

      // Premium is priced from the carrier rule and cannot be charged without
      // one — on both rails, and on the server too (`plan_price_net` raises
      // rather than invent a carrier). Saying so here keeps it a sentence the
      // subscriber can act on instead of a null-check crash further down.
      if (selectedPlanType == 'premium' && premiumRule == null) {
        throw Exception(
          'Please choose the country and carrier for this line before selecting '
          'the Premium plan — its price comes from the carrier\'s own rules.',
        );
      }

      if (selectedPlanType != 'free') {
        planExpiresAt = DateTime.now().add(const Duration(days: 365));
      }

      Future<void> commitSave() async {
        try {
          if (_isEdit) {
            // Fetch current line copy to update
            final line = currentLines.firstWhereOrNull(
              (l) => l.id == widget.id,
            );
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
              planType: selectedPlanType,
              protectionTier: selectedPlanType == 'free'
                  ? 'basic'
                  : selectedPlanType,
              planExpiresAt: planExpiresAt,
              carrierRuleId: carrierRuleId,
            );

            await ref
                .read(simLinesControllerProvider.notifier)
                .updateSimLine(updatedLine);
          } else {
            await ref
                .read(simLinesControllerProvider.notifier)
                .addSimLine(
                  phoneNumber: fullPhoneNumber,
                  nickname: _nicknameController.text.isNotEmpty
                      ? _nicknameController.text
                      : null,
                  avatarIcon: _selectedIcon,
                  countryId: _selectedCountry?.id,
                  carrierId: _selectedCarrier?.id,
                  planType: selectedPlanType,
                  protectionTier: selectedPlanType == 'free'
                      ? 'basic'
                      : selectedPlanType,
                  planExpiresAt: planExpiresAt,
                  carrierRuleId: carrierRuleId,
                );
          }

          // Both controller methods wrap their work in `AsyncValue.guard`, so a
          // rejected insert lands in the provider's state instead of throwing.
          // Without this the form would announce "saved successfully" and pop
          // over a line that was never created — and by this point the plan fee
          // has already been debited.
          final saved = ref.read(simLinesControllerProvider);
          if (saved.hasError) {
            throw Exception(saved.error.toString());
          }

          // The line exists, so the fee it paid for is spent. Until this runs
          // the reference stays on disk and the next attempt replays it instead
          // of billing again.
          await PlanPayment.consumePendingFee(ref);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SIM line saved successfully.'),
                backgroundColor: AppColors.success,
              ),
            );
            Navigator.pop(context); // Close the form
          }
        } on PremiumRefillQueueException catch (e, stack) {
          // The line was created and the plan was paid for; only the pre-paid
          // refill queue is missing. Reporting this as "failed to save" is what
          // left an unpaid-looking premium line in production with no way for
          // its owner to retry — the phone number is taken, so a second attempt
          // can only collide with the row that already exists.
          //
          // The fee is spent either way: the reference must be consumed here
          // too, or the next line the user adds replays it and is created for
          // free.
          await PlanPayment.consumePendingFee(ref);
          await Sentry.captureException(
            e.cause,
            stackTrace: stack,
            withScope: (scope) {
              scope.setTag('flow', 'premium_refill_queue');
              scope.setContexts('premium_queue', {
                'sim_line_id': e.simLineId,
                'carrier_rule_id': carrierRuleId,
              });
            },
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Your line was saved and your payment was recorded, but the '
                  'automatic refills could not be scheduled: $e\n'
                  'Please contact support — do not add the line again.',
                ),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 12),
              ),
            );
            Navigator.pop(context);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to save SIM line: $e'),
                backgroundColor: AppColors.error,
              ),
            );
            setState(() {
              _isSaving = false;
            });
          }
        }
      }

      // Charge only when the plan is newly set or changed to a paid tier.
      // Before C3c this charged on EVERY save of a paid line — renaming a
      // Standard line's nickname billed the service fee again.
      final originalPlan = _isEdit
          ? currentLines
                .firstWhereOrNull((l) => l.id == widget.id)
                ?.planType
                .trim()
                .toLowerCase()
          : null;
      final needsCharge =
          selectedPlanType != 'free' && originalPlan != selectedPlanType;

      if (needsCharge) {
        // What this plan costs on the wallet rail. Priced here only to size the
        // top-up and fill in the breakdown sheet — `pay_plan_fee_from_wallet`
        // prices the debit itself, server-side, from the same formula
        // (`plan_price_net`, J8).
        final double basePlanFee = double.parse(
          (selectedPlanType == 'premium'
                  ? await PlanPayment.premiumWalletTotal(ref, premiumRule!)
                  : await ref.read(baseServiceFeeUsdProvider.future))
              .toStringAsFixed(2),
        );

        // BOTH paid tiers bill wallet-first (C3c for Standard; J8 extends it to
        // Premium). Premium used to skip this entirely and push a PayPal
        // *deposit* — which credited the wallet, created the line and never
        // charged for the plan, so `queue_premium_refill_executions` refused
        // the line with KS403 and the save reported failure over a row that
        // had already been inserted. A wallet debit also lands the entitlement
        // synchronously, before the line exists.
        try {
          if (await PlanPayment.tryPlanFromWallet(
            ref,
            plan: selectedPlanType,
            rule: premiumRule,
            simLineId: _isEdit ? widget.id : null,
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
            await commitSave();
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
            setState(() => _isSaving = false);
          }
          return;
        }

        // The wallet cannot cover it, so the plan is bought through PayPal as a
        // PLAN charge — not as a wallet deposit.
        //
        // That distinction is the whole of C3c's contract and this screen was
        // the one place breaking it. A deposit is credited to the payer's
        // wallet at its FULL captured value (`paypal-webhook` passes `gross` to
        // `credit_wallet_for_deposit`), so routing a plan purchase through a
        // deposit hands the subscriber every cent they paid and leaves KeepSIMs
        // paying PayPal's cut — $0.81 on a $9.52 Premium year, and $0.57 of a
        // $2.50 Standard fee, which is 23%. Worse, the sheet computed a
        // grossed-up total, printed it on the button, and then pushed checkout
        // with the *un*-grossed figure, so PayPal charged $9.52 against a
        // button that said $10.36.
        //
        // A plan charge is priced server-side by `quote_plan_price` from the
        // same `plan_price_net` the wallet rail uses, grossed up once for the
        // gateway. The figure below is the client's copy of that quote, shown
        // for confirmation; the server still decides what is billed.
        final planPayPalTotal = double.parse(
          (selectedPlanType == 'premium'
                  ? await PlanPayment.premiumYearlyTotal(ref, premiumRule!)
                  : await PlanPayment.standardPayPalTotal(ref))
              .toStringAsFixed(2),
        );
        final paypalFee = double.parse(
          (planPayPalTotal - basePlanFee).toStringAsFixed(2),
        );

        // Read from the repository, not `walletControllerProvider.value` — the
        // provider hands back the pre-refresh balance after an invalidate.
        double walletBalance = 0.0;
        final walletRead = await ref.read(walletRepositoryProvider).getWallet();
        if (walletRead case Success(data: final w)) {
          walletBalance = w.balance;
        }

        // Show dialog with detailed breakdown!
        setState(() => _isSaving = false);
        final shouldPay = await _showPayPalPlanChargeDialog(
          context: context,
          currentBalance: walletBalance,
          basePlanFee: basePlanFee,
          paypalFee: paypalFee,
          grossTotalToCharge: planPayPalTotal,
          planName: selectedPlanType == 'premium' ? 'Premium' : 'Standard',
        );

        if (shouldPay != true) return;

        // Biometric / Mock Security Verification (Interactive so emulator works)
        final authGuard = ref.read(paymentAuthGuardProvider);
        final authOk = await authGuard.confirmPaymentInteractive(
          context,
          reason: 'Authenticate to pay for the $selectedPlanType plan',
        );
        if (!authOk) return;

        // Anything recorded from here on belongs to this purchase.
        final chargeStartedAt = DateTime.now().toUtc();

        if (mounted) {
          // Captured from *this* screen's context, before the route is pushed.
          // The builder's parameter used to be called `context` too, which
          // shadowed `State.context`, so every lookup inside `onSuccess` ran
          // against the PayPal route — an element that is deactivated the
          // instant the first line pops it. `mounted` refers to this State and
          // stayed true, so the guards passed straight into
          // `ScaffoldMessenger.of(<deactivated>)`, which throws "Looking up a
          // deactivated widget's ancestor is unsafe" *after* the plan fee had
          // been debited and before the line was ever created.
          final navigator = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);

          navigator.push(
            MaterialPageRoute(
              builder: (_) => PayPalCheckoutScreen(
                initialAmount: planPayPalTotal,
                paymentReason:
                    '${selectedPlanType == 'premium' ? 'Premium' : 'Standard'} '
                    'protection plan — 1 year',
                paymentKind: 'plan',
                plan: selectedPlanType,
                // Null on a new line: the row does not exist yet, which is
                // exactly why the carrier rule id has to travel instead.
                simLineId: _isEdit ? widget.id : null,
                carrierRuleId: carrierRuleId,
                onSuccess: () async {
                  navigator.pop(); // pop PayPal screen
                  setState(() => _isSaving = true);

                  // Every await below is a network call with no timeout of its
                  // own. `_isSaving` blanks the whole form behind a spinner, so
                  // one stalled socket used to leave the screen unusable with no
                  // way back — hence the outer bound and the finally.
                  try {
                    // A plan charge becomes an entitlement only when the
                    // `plan_payments` row lands, and checkout can report
                    // success first — always on the client-driven capture
                    // fallback, which writes no payment row at all. Creating a
                    // Premium line before then asks the refill queue to trust a
                    // payment it cannot see, and it answers KS403.
                    //
                    // Committed either way once the wait is over: the charge is
                    // already made and a plan charge carries no idempotency
                    // reference, so the worst outcome must be "plan active,
                    // refills pending", never a second payment.
                    await PlanPayment.waitForPlanPayment(
                      ref,
                      since: chargeStartedAt,
                    );

                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Payment received. Activating your plan…'),
                        backgroundColor: AppColors.success,
                      ),
                    );

                    // Paid by this point, so a save that stalls must surface as
                    // a retryable error rather than an endless spinner.
                    await commitSave().timeout(const Duration(seconds: 45));
                  } catch (e, stack) {
                    // The fee is already debited here, so a failure at this
                    // point is a money event, not a UI hiccup. Report it with
                    // enough context to identify the call that failed —
                    // several of these have been invisible in the device log.
                    await Sentry.captureException(
                      e,
                      stackTrace: stack,
                      withScope: (scope) {
                        scope.setTag('flow', 'plan_fee_line_create');
                        scope.setContexts('plan_fee', {
                          'plan': selectedPlanType,
                          'is_edit': _isEdit,
                          'sim_line_id': widget.id,
                        });
                      },
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Could not finish saving the line: $e'),
                        backgroundColor: AppColors.error,
                        duration: const Duration(seconds: 10),
                      ),
                    );
                  } finally {
                    // commitSave pops the form on success; guard for that.
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
              ),
            ),
          );
        }
      } else {
        await commitSave();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process line: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted && _selectedTier == 'free') {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ── Pay for the plan with PayPal (the wallet could not cover it) ─────────
  //
  // This used to be an "Insufficient Wallet Balance" top-up sheet, and every
  // number in it described a deposit that is no longer made. It also stated a
  // grossed-up total that was never charged: the button said $10.36 while
  // checkout was opened for $9.52, because the caller passed the *net*. The
  // breakdown now describes exactly one thing — the PayPal charge for the plan.
  Future<bool?> _showPayPalPlanChargeDialog({
    required BuildContext context,
    required double currentBalance,
    required double basePlanFee,
    required double grossTotalToCharge,
    required double paypalFee,
    required String planName,
  }) {
    final isDark = context.isDarkMode;

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
                          'Pay with PayPal',
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
                          'PayPal Processing Fee:',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          '+\$${paypalFee.toStringAsFixed(2)}',
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
                          'Total PayPal Charge:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${grossTotalToCharge.toStringAsFixed(2)}',
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
                        'Breakdown: \$${basePlanFee.toStringAsFixed(2)} plan '
                        '+ \$${paypalFee.toStringAsFixed(2)} PayPal fee. This '
                        'is charged by PayPal for the plan itself, so nothing '
                        'passes through your wallet.'
                        '${currentBalance > 0 ? ' Your \$${currentBalance.toStringAsFixed(2)} balance stays untouched — top it up to \$${basePlanFee.toStringAsFixed(2)} and save the PayPal fee.' : ''}',
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
                        'Pay \$${grossTotalToCharge.toStringAsFixed(2)} via PayPal & Activate',
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
      priceStr = '\$${_baseServiceFeeUsd.toStringAsFixed(2)}';
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
      priceStr = '\$${_baseServiceFeeUsd.toStringAsFixed(2)}';
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
