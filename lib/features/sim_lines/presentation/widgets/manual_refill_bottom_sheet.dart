import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/payment_method_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/payments/presentation/screens/paypal_checkout_screen.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/api_offers_providers.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/features/sim_lines/domain/refill_pricing.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/core/utils/error_formatter.dart';
import 'package:keep_sims/core/fx/money.dart';

class ManualRefillBottomSheet extends ConsumerStatefulWidget {
  final SimLine simLine;

  const ManualRefillBottomSheet({super.key, required this.simLine});

  @override
  ConsumerState<ManualRefillBottomSheet> createState() =>
      _ManualRefillBottomSheetState();
}

class _ManualRefillBottomSheetState
    extends ConsumerState<ManualRefillBottomSheet> {
  Map<String, dynamic>? _selectedOffer;
  bool _isLoading = false;
  PaymentMethod? _selectedPaymentMethod;

  final _amountController = TextEditingController();
  int? _rangeValue;
  double _rangeFinalPriceUsd = 0.0;
  double _rangeBaseCostUsd = 0.0;
  double _rangeGatewayFee = 0.0;
  double _rangeAppFee = 0.0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// The app fee rate currently configured server-side. Falls back to the same
  /// default `calculate_topup_fees` uses, so a failed read cannot make the
  /// quote disagree with the debit.
  double get _appFeePercent =>
      ref.watch(appFeePercentProvider).value ?? kDefaultAppFeePercent;

  RefillQuote _quote(double baseCostUsd, PaymentMethod? pm) =>
      RefillPricing.quote(
        baseCostUsd: baseCostUsd,
        appFeePercent: _appFeePercent,
        gatewayFeePercentage: pm?.feePercentage ?? 0,
        gatewayFeeFixed: pm?.feeFixed ?? 0,
      );

  Future<void> _handleRefill() async {
    if (_selectedOffer == null) return;

    setState(() => _isLoading = true);

    try {
      final isRange = _selectedOffer!['isRange'] == true;
      final baseCostUsd = isRange
          ? _rangeBaseCostUsd
          : (_selectedOffer!['baseCostUsd'] as num).toDouble();
      final offerId = _selectedOffer!['offerId'] as String;

      final pm = _selectedPaymentMethod;
      final paymentCode = pm?.code ?? 'wallet';

      final totalAmount = _quote(baseCostUsd, pm).total;

      final authGuard = ref.read(paymentAuthGuardProvider);
      final authResult = await authGuard.confirmPayment(
        reason: 'Authenticate to confirm refill',
      );
      if (authResult == BiometricResult.cancelled ||
          authResult == BiometricResult.failed ||
          authResult == BiometricResult.lockedOut) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Wallet refills are debited server-side by worker_instant_refill, which
      // fails the execution outright when the balance is short. Catching it here
      // means the user gets a top-up prompt instead of a queued request that
      // turns into a failure notification a few seconds later.
      if (paymentCode == 'wallet') {
        final balance = ref.read(walletControllerProvider).value?.wallet.balance;
        if (balance != null && balance < totalAmount) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          await _promptTopUp(balance, totalAmount);
          return;
        }
      }

      if (paymentCode == 'paypal') {
        if (!mounted) return;
        Navigator.of(context).pop();

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PayPalCheckoutScreen(
              initialAmount: totalAmount,
              paymentReason: 'Manual Refill for ${widget.simLine.phoneNumber}',
              paymentKind: 'deposit',
              onSuccess: () async {
                try {
                  await ref
                      .read(simLinesControllerProvider.notifier)
                      .performManualRefill(
                        widget.simLine,
                        paymentCode,
                        offerId: offerId,
                        displayBaseUsd: baseCostUsd,
                        amountUsd: isRange ? _rangeBaseCostUsd : null,
                      );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(RateLimitErrorFormatter.format(e, context)),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
        return;
      }

      await ref
          .read(simLinesControllerProvider.notifier)
          .performManualRefill(
            widget.simLine,
            paymentCode,
            offerId: offerId,
            displayBaseUsd: baseCostUsd,
            amountUsd: isRange ? _rangeBaseCostUsd : null,
          );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (paymentCode != 'wallet') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Redirecting to Payment Gateway...'),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully requested Refill for ${widget.simLine.phoneNumber}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(RateLimitErrorFormatter.format(e, context)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shown instead of queuing a refill the wallet cannot cover.
  Future<void> _promptTopUp(double balance, double required) async {
    final shortfall = required - balance;
    final goToWallet = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: Text(
          'Not enough balance',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This refill costs \$${required.toStringAsFixed(2)} but your wallet '
          'has \$${balance.toStringAsFixed(2)}. Add at least '
          '\$${shortfall.toStringAsFixed(2)} to continue.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Top up wallet',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (goToWallet == true && mounted) {
      Navigator.of(context).pop();
      context.push(AppRoutes.wallet);
    }
  }

  void _calculateRangeFees() {
    if (_rangeBaseCostUsd == 0) return;
    final q = _quote(_rangeBaseCostUsd, _selectedPaymentMethod);
    setState(() {
      _rangeGatewayFee = q.gatewayFee;
      _rangeAppFee = q.appFee;
      _rangeFinalPriceUsd = q.total;
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletControllerProvider);
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Manual Refill',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textSecondaryDark,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select an amount to instantly top-up ${widget.simLine.nickname ?? widget.simLine.phoneNumber}.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.darkBorder, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wallet Balance',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textTertiaryDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        walletState.when(
                          data: (state) => Text(
                            '\$${state.wallet.balance.toStringAsFixed(2)}',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.textPrimaryDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          loading: () => const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.primary,
                              ),
                            ),
                          ),
                          error: (error, stack) => Text(
                            '--',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(AppRoutes.wallet);
                    },
                    icon: const Icon(
                      Icons.open_in_new,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'Open',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            paymentMethodsAsync.when(
              data: (methods) {
                if (methods.isEmpty) return const SizedBox.shrink();

                if (_selectedPaymentMethod == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() => _selectedPaymentMethod = methods.first);
                    if (_rangeValue != null) _calculateRangeFees();
                  });
                }

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<PaymentMethod>(
                      value: _selectedPaymentMethod,
                      isExpanded: true,
                      dropdownColor: AppColors.darkCard,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.primary,
                      ),
                      items: methods.map((pm) {
                        return DropdownMenuItem(
                          value: pm,
                          child: Row(
                            children: [
                              Icon(
                                pm.code == 'wallet'
                                    ? Icons.account_balance_wallet
                                    : Icons.credit_card,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                pm.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedPaymentMethod = val);
                          if (_rangeValue != null) _calculateRangeFees();
                        }
                      },
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            Text(
              'Select Refill Package',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.simLine.countryId == null ||
                widget.simLine.carrierId == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Country or Carrier is missing for this SIM line.',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              )
            else
              // I1: line-scoped so every enabled supplier is listed and the
              // ranking matches what request_instant_refill will re-apply.
              ref
                  .watch(lineRefillOffersProvider(widget.simLine.id))
                  .when(
                    data: (offers) {
                      if (offers.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No offers available for this carrier.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      final rangeOfferIdx = offers.indexWhere(
                        (o) => o['priceType'] == 'RANGE',
                      );
                      if (rangeOfferIdx != -1) {
                        return _buildRangeUI(offers[rangeOfferIdx]);
                      }

                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: offers.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final offer = offers[index];
                            final isSelected =
                                _selectedOffer?['offerId'] == offer['offerId'];

                            final baseCost = (offer['baseCostUsd'] as num)
                                .toDouble();
                            final q = _quote(baseCost, _selectedPaymentMethod);
                            final gatewayFee = q.gatewayFee;
                            final appFee = q.appFee;
                            final finalPrice = q.total;

                            final name =
                                offer['description'] ?? offer['offerId'];

                            return InkWell(
                              onTap: () {
                                setState(() => _selectedOffer = offer);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.1)
                                      : AppColors.darkCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.darkBorder,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: AppTextStyles.labelLarge
                                                .copyWith(
                                                  color:
                                                      AppColors.textPrimaryDark,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        Text(
                                          '\$${finalPrice.toStringAsFixed(2)}',
                                          style: AppTextStyles.titleMedium
                                              .copyWith(
                                                color: AppColors.primaryLight,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // G11 — the all-in price in the user's own
                                    // currency. It converts `finalPrice`, the
                                    // charged total, and not the fee breakdown
                                    // below: converting each component invites
                                    // adding them up and finding they do not
                                    // reconcile, because each is rounded.
                                    ApproxLocalText(finalPrice),
                                    Text(
                                      'Base: \$${baseCost.toStringAsFixed(2)} | Fees: \$${gatewayFee.toStringAsFixed(2)} | App: \$${appFee.toStringAsFixed(2)}',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.textTertiaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Failed to load offers: $err',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed:
                  (_isLoading ||
                      _selectedOffer == null ||
                      (_selectedOffer!['isRange'] == true &&
                          _rangeValue == null))
                  ? null
                  : _handleRefill,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _confirmLabel(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _confirmLabel() {
    final offer = _selectedOffer;
    if (offer == null) return 'Select a Package';
    if (offer['isRange'] == true) {
      return _rangeValue == null
          ? 'Enter valid amount'
          : 'Confirm \$${_rangeFinalPriceUsd.toStringAsFixed(2)} Refill';
    }
    final total = _quote(
      (offer['baseCostUsd'] as num).toDouble(),
      _selectedPaymentMethod,
    ).total;
    return 'Confirm \$${total.toStringAsFixed(2)} Refill';
  }

  Widget _buildRangeUI(Map<String, dynamic> offer) {
    if (_selectedOffer?['offerId'] != offer['offerId']) {
      // Auto-select the range offer if we are showing it
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _selectedOffer = offer);
      });
    }

    final minLocal =
        (offer['min'] as num? ?? 800) /
        (offer['sendCurrencyDivisor'] as num? ?? 100);
    final maxLocal =
        (offer['max'] as num? ?? 20000) /
        (offer['sendCurrencyDivisor'] as num? ?? 100);
    final currency = offer['send']?['currency'] ?? 'EGP';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Custom Amount ($currency)',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter amount (Min: $minLocal, Max: $maxLocal)',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: AppColors.darkCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.darkBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
            onChanged: (value) {
              final doubleVal = double.tryParse(value);
              if (doubleVal != null &&
                  doubleVal >= minLocal &&
                  doubleVal <= maxLocal) {
                final divisor = (offer['sendCurrencyDivisor'] as num? ?? 100)
                    .toInt();
                final intValue = (doubleVal * divisor).round();

                // USD cost interpolated across the offer's price range — the
                // same mapping request_instant_refill applies server-side, so
                // the quote here matches what the RPC will charge.
                final sendMin = (offer['min'] as num? ?? 0).toDouble();
                final sendMax = (offer['max'] as num? ?? 0).toDouble();
                final priceMin = (offer['priceMinUsd'] as num? ?? 0).toDouble();
                final priceMax = (offer['priceMaxUsd'] as num? ?? 0).toDouble();
                final frac = sendMax > sendMin
                    ? (intValue - sendMin) / (sendMax - sendMin)
                    : 0.0;
                final baseCostUsd = double.parse(
                  (priceMin + frac * (priceMax - priceMin)).toStringAsFixed(2),
                );

                setState(() {
                  _rangeValue = intValue;
                  _rangeBaseCostUsd = baseCostUsd;
                });
                _calculateRangeFees();
              } else {
                setState(() {
                  _rangeValue = null;
                  _rangeFinalPriceUsd = 0.0;
                  _rangeBaseCostUsd = 0.0;
                  _rangeGatewayFee = 0.0;
                  _rangeAppFee = 0.0;
                });
              }
            },
          ),
          if (_rangeValue != null) ApproxLocalText(_rangeFinalPriceUsd),
          if (_rangeValue != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Base: \$${_rangeBaseCostUsd.toStringAsFixed(2)} | Gateway: \$${_rangeGatewayFee.toStringAsFixed(2)} | App Fee: \$${_rangeAppFee.toStringAsFixed(2)}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textTertiaryDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
