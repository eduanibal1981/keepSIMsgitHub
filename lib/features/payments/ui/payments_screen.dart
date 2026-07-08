/// SIM Shield — Payment Methods & Auto-Funding Screen
///
/// Breathtaking glassmorphic billing dashboard allowing expats to manage credit cards
/// and configure automated wallet top-up triggers.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/payments/controller/payments_controller.dart';
import 'package:keep_sims/features/payments/model/payment_method_model.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  // State for Auto-Fund Configuration local sliders before clicking save
  bool _autoFundEnabled = false;
  double _autoFundThreshold = 20.0;
  double _autoFundAmount = 50.0;
  bool _isInit = false;

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(paymentsControllerProvider);
    final authProfile = ref.watch(authControllerProvider).value;
    final userName = authProfile?.fullName ?? 'Valued Expat';

    // Set initial auto-fund values from database once loaded
    if (!_isInit) {
      stateAsync.whenData((state) {
        if (state.wallet != null) {
          setState(() {
            _autoFundEnabled = state.wallet!.autoFundEnabled;
            _autoFundThreshold = state.wallet!.autoFundThreshold ?? 20.0;
            _autoFundAmount = state.wallet!.autoFundAmount ?? 50.0;
            _isInit = true;
          });
        }
      });
    }

    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: context.onSurfaceColor,
            ),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppLocalizations.of(context)!.paymentsAutoFundTitle,
          style: AppTextStyles.headlineMedium.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: stateAsync.when(
        data: (state) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── CARDS SECTION HEADER ─────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.linkedCards,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: context.onSurfaceColor,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: state.isSubmitting
                            ? null
                            : () => _showAddCardSheet(context, ref),
                        icon: Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: isDark
                              ? AppColors.secondary
                              : context.primaryColor,
                        ),
                        label: Text(
                          AppLocalizations.of(context)!.addCard,
                          style: AppTextStyles.labelLarge.copyWith(
                            color: isDark
                                ? AppColors.secondary
                                : context.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ─── CARDS CAROUSEL / LIST ────────────────────────
                  if (state.paymentMethods.isEmpty)
                    _buildEmptyCardsState(context)
                  else
                    SizedBox(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: state.paymentMethods.length,
                        itemBuilder: (context, index) {
                          final card = state.paymentMethods[index];
                          return _buildGlassmorphicCard(card, userName);
                        },
                      ),
                    ),

                  const SizedBox(height: 30),

                  // ─── AUTO-FUNDING SECTION ─────────────────────────
                  _buildAutoFundingPanel(context, state.isSubmitting),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: context.primaryColor),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.failedToLoadPaymentInfo,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: context.onSurfaceColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                textAlign: CenterAlign().textAlign,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── GLASSMORPHIC CARD BUILDER ────────────────────────────────────
  Widget _buildGlassmorphicCard(PaymentMethod card, String userName) {
    final isDark = context.isDarkMode;
    final isDefault = card.isDefault;
    final bgGradient = isDefault
        ? AppColors.heroGradient
        : (isDark
              ? AppColors.darkCardGradient
              : const LinearGradient(
                  colors: [Colors.white, Color(0xFFF0F4F8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ));

    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 16, bottom: 8, top: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: bgGradient,
        boxShadow: [
          BoxShadow(
            color: (isDefault ? context.primaryColor : Colors.black)
                .withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDefault
              ? Colors.white.withValues(alpha: 0.3)
              : (isDark
                    ? AppColors.darkBorder.withValues(alpha: 0.5)
                    : AppColors.lightBorder),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative background bubbles
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Card contents
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Type Logo + Default Indicator + Delete Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Glow Card Brand
                      Row(
                        children: [
                          Icon(
                            card.provider?.toLowerCase() == 'visa'
                                ? Icons.credit_card_rounded
                                : Icons.payment_rounded,
                            color: isDefault || isDark
                                ? Colors.white
                                : context.onSurfaceColor,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            card.provider?.toUpperCase() ?? 'CARD',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: isDefault || isDark
                                  ? Colors.white
                                  : context.onSurfaceColor,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),

                      // Actions row
                      Row(
                        children: [
                          if (isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isDark
                                            ? AppColors.secondary
                                            : AppColors.lightSecondary)
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      (isDark
                                              ? AppColors.secondary
                                              : AppColors.lightSecondary)
                                          .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: 10,
                                    color: isDark
                                        ? AppColors.secondary
                                        : AppColors.lightSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.defaultCardIndicator,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: isDark
                                          ? AppColors.secondary
                                          : AppColors.lightSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.star_border_rounded,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textSecondaryLight,
                                size: 20,
                              ),
                              onPressed: () => _handleSetDefault(card.id!),
                            ),
                          const SizedBox(width: 12),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.healthRed,
                              size: 20,
                            ),
                            onPressed: () => _confirmDeleteCard(card.id!),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Card Number
                  Text(
                    '••••  ••••  ••••  ${card.lastFour ?? '0000'}',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: isDefault || isDark
                          ? Colors.white
                          : context.onSurfaceColor,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),

                  // Expiry & Cardholder
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.cardholder,
                            style: AppTextStyles.caption.copyWith(
                              color: isDefault || isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : AppColors.textTertiaryLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 180,
                            child: Text(
                              userName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isDefault || isDark
                                    ? Colors.white
                                    : context.onSurfaceColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.expires,
                            style: AppTextStyles.caption.copyWith(
                              color: isDefault || isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : AppColors.textTertiaryLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${card.expiryMonth.toString().padLeft(2, '0')}/${(card.expiryYear ?? 0) % 100}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isDefault || isDark
                                  ? Colors.white
                                  : context.onSurfaceColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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

  // ─── CARDS EMPTY STATE ────────────────────────────────────────────
  Widget _buildEmptyCardsState(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          style: BorderStyle.values[0] /* Wait, outline dashed */,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _showAddCardSheet(context, ref),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.primary : AppColors.lightPrimary)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_card_rounded,
                color: context.primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.linkFirstCard,
              style: AppTextStyles.titleMedium.copyWith(
                color: context.onSurfaceColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.supportVisaMastercard,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── AUTO-FUND PREFERENCES PANEL ──────────────────────────────────
  Widget _buildAutoFundingPanel(BuildContext context, bool isSubmitting) {
    final isDark = context.isDarkMode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row switch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      (isDark ? AppColors.secondary : AppColors.lightSecondary)
                          .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: isDark
                      ? AppColors.secondary
                      : AppColors.lightSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.autoFundingRules,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: context.onSurfaceColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.refillWalletLow,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _autoFundEnabled,
                activeColor: isDark
                    ? AppColors.secondary
                    : AppColors.lightSecondary,
                activeTrackColor:
                    (isDark ? AppColors.secondary : AppColors.lightSecondary)
                        .withValues(alpha: 0.3),
                inactiveThumbColor: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                inactiveTrackColor: isDark
                    ? AppColors.darkBg
                    : const Color(0xFFEAEEF1),
                onChanged: (val) {
                  setState(() {
                    _autoFundEnabled = val;
                  });
                },
              ),
            ],
          ),

          if (_autoFundEnabled) ...[
            const SizedBox(height: 24),
            Divider(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              height: 1,
            ),
            const SizedBox(height: 24),

            // ─── LOW BALANCE SLIDER ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.lowBalanceTrigger,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${_autoFundThreshold.toInt()}',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isDark
                        ? AppColors.secondary
                        : AppColors.lightSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Slider.adaptive(
              value: _autoFundThreshold,
              min: 5.0,
              max: 100.0,
              divisions: 19,
              activeColor: context.primaryColor,
              inactiveColor: isDark
                  ? AppColors.darkBg
                  : const Color(0xFFEAEEF1),
              onChanged: (val) {
                setState(() {
                  _autoFundThreshold = val;
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$5',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.triggerLowTopUp,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                  Text(
                    '\$100',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── RELOAD AMOUNT SLIDER ───────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.reloadDepositAmount,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${_autoFundAmount.toInt()}',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isDark
                        ? AppColors.primaryLight
                        : AppColors.lightPrimaryMid,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Slider.adaptive(
              value: _autoFundAmount,
              min: 10.0,
              max: 200.0,
              divisions: 19,
              activeColor: context.primaryColor,
              inactiveColor: isDark
                  ? AppColors.darkBg
                  : const Color(0xFFEAEEF1),
              onChanged: (val) {
                setState(() {
                  _autoFundAmount = val;
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$10',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.amountToLoad,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                  Text(
                    '\$200',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ─── SAVE PREFERENCES BUTTON ────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: isDark
                      ? AppColors.primaryGradient
                      : const LinearGradient(
                          colors: [
                            AppColors.lightPrimary,
                            AppColors.lightPrimaryMid,
                          ],
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: context.primaryColor.withValues(
                        alpha: isDark ? 0.3 : 0.15,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _saveAutoFundPreferences,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          AppLocalizations.of(context)!.saveSettings,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.autoFundingRulesDesc,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── SHEET FOR ADDING Mock Billing Cards ──────────────────────────
  void _showAddCardSheet(BuildContext context, WidgetRef ref) {
    final numberController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    String detectedProvider = 'Visa';
    final isDark = context.isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (builderCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.linkCreditDebitCard,
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: context.onSurfaceColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark
                              ? Colors.white70
                              : AppColors.textSecondaryLight,
                        ),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Card Number Field
                  Text(
                    AppLocalizations.of(context)!.cardNumberLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? Colors.white70
                          : AppColors.textSecondaryLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: numberController,
                    keyboardType: TextInputType.number,
                    maxLength: 19,
                    style: TextStyle(color: context.onSurfaceColor),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _CardNumberFormatter(),
                    ],
                    onChanged: (val) {
                      final clean = val.replaceAll(' ', '');
                      String provider = 'Visa';
                      if (clean.startsWith('5')) {
                        provider = 'MasterCard';
                      } else if (clean.startsWith('3')) {
                        provider = 'Amex';
                      }
                      setSheetState(() {
                        detectedProvider = provider;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: '4242 4242 4242 4242',
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.3)
                            : AppColors.textTertiaryLight,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkBg
                          : const Color(0xFFEAEEF1),
                      prefixIcon: Icon(
                        detectedProvider == 'Visa'
                            ? Icons.credit_card_rounded
                            : Icons.payment_rounded,
                        color: isDark
                            ? AppColors.secondary
                            : AppColors.lightSecondary,
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          detectedProvider.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isDark
                                ? Colors.white70
                                : AppColors.textSecondaryLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Row Expiry + CVV
                  Row(
                    children: [
                      // Expiry
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.expiryDateLabel,
                              style: AppTextStyles.caption.copyWith(
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: expiryController,
                              keyboardType: TextInputType.number,
                              maxLength: 5,
                              style: TextStyle(color: context.onSurfaceColor),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _ExpiryDateFormatter(),
                              ],
                              decoration: InputDecoration(
                                hintText: 'MM/YY',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : AppColors.textTertiaryLight,
                                ),
                                counterText: '',
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.darkBg
                                    : const Color(0xFFEAEEF1),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: context.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // CVV
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.cvvCodeLabel,
                              style: AppTextStyles.caption.copyWith(
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: cvvController,
                              keyboardType: TextInputType.number,
                              maxLength: 3,
                              obscureText: true,
                              style: TextStyle(color: context.onSurfaceColor),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                hintText: '•••',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : AppColors.textTertiaryLight,
                                ),
                                counterText: '',
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.darkBg
                                    : const Color(0xFFEAEEF1),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: context.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Action link card
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: isDark
                            ? AppColors.accentGradient
                            : const LinearGradient(
                                colors: [
                                  AppColors.lightPrimary,
                                  AppColors.lightPrimaryMid,
                                ],
                              ),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _linkCard(
                          sheetCtx,
                          numberController.text,
                          expiryController.text,
                          cvvController.text,
                          detectedProvider,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.securelyLinkCard,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── LINK CARD LOGIC ──────────────────────────────────────────────
  Future<void> _linkCard(
    BuildContext sheetContext,
    String rawNumber,
    String expiry,
    String cvv,
    String provider,
  ) async {
    final cleanNum = rawNumber.replaceAll(' ', '');
    if (cleanNum.length < 16) {
      _showBanner(
        AppLocalizations.of(sheetContext)!.pleaseEnterValidCardNumber,
        isError: true,
      );
      return;
    }

    if (expiry.length < 5 || !expiry.contains('/')) {
      _showBanner(
        AppLocalizations.of(sheetContext)!.pleaseEnterValidExpiryDate,
        isError: true,
      );
      return;
    }

    final month = int.tryParse(expiry.split('/')[0]) ?? 0;
    final yearStr = expiry.split('/')[1];
    final year = 2000 + (int.tryParse(yearStr) ?? 0);

    if (month < 1 || month > 12) {
      _showBanner(
        AppLocalizations.of(sheetContext)!.invalidExpiryMonth,
        isError: true,
      );
      return;
    }

    if (cvv.length < 3) {
      _showBanner(
        AppLocalizations.of(sheetContext)!.cvvMustBe3Digits,
        isError: true,
      );
      return;
    }

    // Dismiss bottom sheet first
    Navigator.pop(sheetContext);

    final lastFour = cleanNum.substring(cleanNum.length - 4);

    final errorMsg = await ref
        .read(paymentsControllerProvider.notifier)
        .addPaymentMethod(
          provider: provider,
          lastFour: lastFour,
          expiryMonth: month,
          expiryYear: year,
        );

    if (errorMsg != null) {
      _showBanner(errorMsg, isError: true);
    } else {
      _showBanner(AppLocalizations.of(sheetContext)!.cardLinkedSuccessfully);
    }
  }

  // ─── CARD SET DEFAULT ACTION ──────────────────────────────────────
  Future<void> _handleSetDefault(String cardId) async {
    final err = await ref
        .read(paymentsControllerProvider.notifier)
        .setDefaultPaymentMethod(cardId);
    if (err != null) {
      _showBanner(err, isError: true);
    } else {
      _showBanner(AppLocalizations.of(context)!.defaultPaymentCardUpdated);
    }
  }

  // ─── CARD DELETE ACTION ───────────────────────────────────────────
  void _confirmDeleteCard(String cardId) {
    final isDark = context.isDarkMode;
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            AppLocalizations.of(context)!.removePaymentCard,
            style: AppTextStyles.headlineSmall.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            AppLocalizations.of(context)!.confirmRemoveCardDesc,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : AppColors.textTertiaryLight,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.healthRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final err = await ref
                    .read(paymentsControllerProvider.notifier)
                    .deletePaymentMethod(cardId);
                if (err != null) {
                  _showBanner(err, isError: true);
                } else {
                  _showBanner(
                    AppLocalizations.of(
                      context,
                    )!.billingCardSuccessfullyRemoved,
                  );
                }
              },
              child: Text(AppLocalizations.of(context)!.remove),
            ),
          ],
        );
      },
    );
  }

  // ─── SAVE AUTO-FUND RULES ─────────────────────────────────────────
  Future<void> _saveAutoFundPreferences() async {
    // Basic verification: user must have at least one card linked to enable auto fund
    final controller = ref.read(paymentsControllerProvider).value;
    if (_autoFundEnabled && (controller?.paymentMethods.isEmpty ?? true)) {
      _showBanner(
        AppLocalizations.of(context)!.pleaseAddDefaultCardFirst,
        isError: true,
      );
      return;
    }

    final err = await ref
        .read(paymentsControllerProvider.notifier)
        .updateAutoFundSettings(
          autoFundEnabled: _autoFundEnabled,
          autoFundThreshold: _autoFundThreshold,
          autoFundAmount: _autoFundAmount,
        );

    if (err != null) {
      _showBanner(err, isError: true);
    } else {
      _showBanner(AppLocalizations.of(context)!.autoFundPrefsSavedSuccess);
    }
  }

  // Helper banners
  void _showBanner(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }
}

// ─── CARD NUMBER FORMATTER (Adds spaces every 4 characters) ─────────
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      final nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

// ─── EXPIRY DATE FORMATTER (Adds slash after MM) ───────────────────
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      final nonZeroIndex = i + 1;
      if (nonZeroIndex == 2 && nonZeroIndex != text.length) {
        buffer.write('/');
      }
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

// Custom Align classes to avoid linter errors with static analyze parameters
class CenterAlign {
  TextAlign get textAlign => TextAlign.center;
}
