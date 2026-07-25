import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

enum PayPalCheckoutStatus {
  idle,
  creatingOrder,
  awaitingApproval,
  capturing,
  success,
  failed,
}

class PayPalCheckoutScreen extends ConsumerStatefulWidget {
  final double? initialAmount;
  final String? paymentReason;
  final VoidCallback? onSuccess;
  final String paymentKind;
  final String? plan;
  final String? simLineId;

  const PayPalCheckoutScreen({
    super.key,
    this.initialAmount,
    this.paymentReason,
    this.onSuccess,
    this.paymentKind = 'deposit',
    this.plan,
    this.simLineId,
  });

  @override
  ConsumerState<PayPalCheckoutScreen> createState() => _PayPalCheckoutScreenState();
}

class _PayPalCheckoutScreenState extends ConsumerState<PayPalCheckoutScreen> {
  final TextEditingController _amountController = TextEditingController(text: '10.00');
  double _selectedDepositAmount = 10.00;
  PayPalCheckoutStatus _status = PayPalCheckoutStatus.idle;
  String? _orderId;
  String? _approveUrl;
  String? _errorMessage;
  double _initialWalletBalance = 0.0;
  RealtimeChannel? _realtimeChannel;
  bool _isCapturingManually = false;

  static const List<double> _presetAmounts = [10.0, 20.0, 50.0, 100.0];

  @override
  void initState() {
    super.initState();
    final amt = widget.initialAmount ?? 10.0;
    _selectedDepositAmount = amt < 1.00 ? 1.00 : amt;
    _amountController.text = _selectedDepositAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountSelected(double amount) {
    HapticHelper.lightTick();
    setState(() {
      _selectedDepositAmount = amount;
      _amountController.text = amount.toStringAsFixed(2);
    });
  }

  Future<void> _initiateCheckout() async {
    // 1. Biometric / Passcode Auth Guard Gate (Defect #7 fix)
    final authResult = await ref.read(paymentAuthGuardProvider).confirmPayment(
      reason: 'Authorize PayPal payment',
    );

    if (authResult != BiometricResult.success) {
      if (mounted && authResult == BiometricResult.lockedOut) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.biometricLockout ??
                  'Biometric authentication locked due to too many failed attempts.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final rawAmt = double.tryParse(_amountController.text) ?? _selectedDepositAmount;
    final effectiveAmt = rawAmt < 1.00 ? 1.00 : rawAmt;

    setState(() {
      _status = PayPalCheckoutStatus.creatingOrder;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final walletState = ref.read(walletControllerProvider);
      _initialWalletBalance = walletState.value?.wallet.balance ?? 0.0;

      // Create Order on Server (Server-priced for plan, floor clamped for deposit)
      final response = await supabase.functions.invoke(
        'create-paypal-order',
        body: {
          'kind': widget.paymentKind,
          'plan': widget.plan,
          'sim_line_id': widget.simLineId,
          'amount_usd': effectiveAmt,
        },
      );

      if (response.status != 200) {
        final errText = (response.data is Map && response.data['error'] != null)
            ? response.data['error'].toString()
            : 'Server error (${response.status})';
        throw Exception(errText);
      }

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true || data['approval_url'] == null) {
        throw Exception(data['error'] ?? 'Failed to generate PayPal approval link');
      }

      _orderId = data['order_id'];
      _approveUrl = data['approval_url'];

      setState(() {
        _status = PayPalCheckoutStatus.awaitingApproval;
      });

      // 2. Subscribe Realtime stream on paypal_orders table for this order_id (BLOCKER 2 Realtime Stream)
      _subscribeToOrderRealtime(_orderId!);

      // 3. Launch approve URL in external browser
      final uri = Uri.parse(_approveUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch PayPal approval URL.');
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _status = PayPalCheckoutStatus.failed;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _subscribeToOrderRealtime(String orderId) {
    _realtimeChannel?.unsubscribe();
    final supabase = Supabase.instance.client;

    _realtimeChannel = supabase
        .channel('paypal_order_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'paypal_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: orderId,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['status'] as String?;
            if (newStatus == 'captured') {
              _onPaymentSuccess();
            } else if (newStatus == 'failed') {
              if (mounted) {
                setState(() {
                  _status = PayPalCheckoutStatus.failed;
                  _errorMessage = AppLocalizations.of(context)?.payPalPaymentFailed ??
                      'Payment failed or was cancelled.';
                });
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _triggerManualCapture() async {
    if (_orderId == null || _isCapturingManually) return;
    HapticHelper.lightTick();

    setState(() {
      _isCapturingManually = true;
      _status = PayPalCheckoutStatus.capturing;
    });

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'capture-paypal-order',
        body: {
          'order_id': _orderId,
        },
      );

      if (response.status == 200 && response.data['success'] == true) {
        _onPaymentSuccess();
      } else {
        final errText = (response.data is Map && response.data['error'] != null)
            ? response.data['error'].toString()
            : 'Capture failed (${response.status})';
        throw Exception(errText);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturingManually = false;
          _status = PayPalCheckoutStatus.awaitingApproval;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _onPaymentSuccess() {
    _realtimeChannel?.unsubscribe();
    HapticHelper.mediumImpact();
    ref.invalidate(walletControllerProvider);

    if (mounted) {
      setState(() {
        _status = PayPalCheckoutStatus.success;
      });
      widget.onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;
    final isDeposit = widget.paymentKind == 'deposit';

    final rawAmt = double.tryParse(_amountController.text) ?? _selectedDepositAmount;
    final hasRemainder = isDeposit && rawAmt > 0 && rawAmt < 1.00;
    final remainderAmount = hasRemainder ? (1.00 - rawAmt) : 0.0;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.payPalCheckoutTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.payment_rounded, size: 44, color: Color(0xFF003087)),
                    const SizedBox(height: 12),
                    Text(
                      widget.paymentReason ?? l10n.payPalWalletTopUp,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.onSurfaceColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isDeposit) ...[
                      // Preset Amount Chips (Defect #1 fix)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _presetAmounts.map((amt) {
                          final isSelected = (_selectedDepositAmount - amt).abs() < 0.01;
                          return ChoiceChip(
                            label: Text('\$${amt.toInt()}'),
                            selected: isSelected,
                            onSelected: (_) => _onAmountSelected(amt),
                            selectedColor: const Color(0xFF0070BA),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : context.onSurfaceColor,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null) {
                            setState(() => _selectedDepositAmount = parsed);
                          }
                        },
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: const Color(0xFF0070BA),
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: const InputDecoration(
                          prefixText: '\$ ',
                          border: InputBorder.none,
                        ),
                      ),
                      if (hasRemainder)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Minimum PayPal charge is \$1.00 — \$${remainderAmount.toStringAsFixed(2)} remainder will stay in your wallet balance.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ] else ...[
                      if (widget.initialAmount != null)
                        Text(
                          '\$${widget.initialAmount!.toStringAsFixed(2)}',
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: const Color(0xFF0070BA),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildStatusWidget(isDark, l10n),
              const Spacer(),
              if (_status == PayPalCheckoutStatus.idle || _status == PayPalCheckoutStatus.failed)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _initiateCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0070BA),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n.payPalPaySecurely,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_status == PayPalCheckoutStatus.awaitingApproval || _status == PayPalCheckoutStatus.capturing)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _isCapturingManually ? null : _triggerManualCapture,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0070BA),
                      side: const BorderSide(color: Color(0xFF0070BA), width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isCapturingManually
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            l10n.payPalForceCaptureButton,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              if (_status == PayPalCheckoutStatus.success)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      l10n.biometricCancel,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusWidget(bool isDark, AppLocalizations l10n) {
    switch (_status) {
      case PayPalCheckoutStatus.idle:
        return Text(
          l10n.payPalRedirectInfo,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        );
      case PayPalCheckoutStatus.creatingOrder:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.payPalCreatingOrder),
          ],
        );
      case PayPalCheckoutStatus.awaitingApproval:
      case PayPalCheckoutStatus.capturing:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              l10n.payPalAwaitingConfirmation,
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.payPalCompleteInBrowser,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        );
      case PayPalCheckoutStatus.success:
        return Column(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 64),
            const SizedBox(height: 12),
            Text(
              l10n.payPalPaymentConfirmed,
              style: const TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        );
      case PayPalCheckoutStatus.failed:
        return Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? l10n.payPalPaymentFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
          ],
        );
    }
  }
}
