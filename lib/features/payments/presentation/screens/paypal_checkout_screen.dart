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
  awaitingWebhook,
  success,
  failed,
}

class PayPalCheckoutScreen extends ConsumerStatefulWidget {
  final double? initialAmount;
  final String? paymentReason;
  final VoidCallback? onSuccess;
  final bool depositToWallet;
  final String paymentKind;
  final String? simLineId;

  const PayPalCheckoutScreen({
    super.key,
    this.initialAmount,
    this.paymentReason,
    this.onSuccess,
    this.depositToWallet = true,
    this.paymentKind = 'deposit',
    this.simLineId,
  });

  @override
  ConsumerState<PayPalCheckoutScreen> createState() => _PayPalCheckoutScreenState();
}

// Alias for backwards compatibility across call sites
typedef PaypalRefillSimulatorScreen = PayPalCheckoutScreen;

class _PayPalCheckoutScreenState extends ConsumerState<PayPalCheckoutScreen> {
  final TextEditingController _amountController = TextEditingController(text: '10.00');
  PayPalCheckoutStatus _status = PayPalCheckoutStatus.idle;
  String? _orderId;
  String? _approveUrl;
  String? _errorMessage;
  Timer? _pollingTimer;
  double _initialWalletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    final amt = widget.initialAmount ?? 10.0;
    _amountController.text = amt.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _initiateCheckout() async {
    // 1. Biometric / Passcode Auth Guard Gate
    final authResult = await ref.read(paymentAuthGuardProvider).confirmPayment(
      reason: 'Authorize PayPal payment',
    );
    if (authResult == BiometricResult.cancelled || authResult == BiometricResult.failed) {
      return;
    }

    final amt = double.tryParse(_amountController.text) ?? (widget.initialAmount ?? 10.00);

    setState(() {
      _status = PayPalCheckoutStatus.creatingOrder;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final walletState = ref.read(walletControllerProvider);
      _initialWalletBalance = walletState.value?.wallet.balance ?? 0.0;

      final response = await supabase.functions.invoke(
        'create-paypal-order',
        body: {
          'kind': widget.paymentKind,
          'sim_line_id': widget.simLineId,
          'amount_usd': amt,
        },
      );

      if (response.status != 200) {
        final errText = (response.data is Map && response.data['error'] != null)
            ? response.data['error'].toString()
            : 'Server error (${response.status})';
        throw Exception(errText);
      }

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true || data['approve_url'] == null) {
        throw Exception(data['error'] ?? 'Failed to generate PayPal approval link');
      }

      _orderId = data['order_id'];
      _approveUrl = data['approve_url'];

      setState(() {
        _status = PayPalCheckoutStatus.awaitingApproval;
      });

      // 2. Launch approve URL in external browser
      final uri = Uri.parse(_approveUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch PayPal approval URL.');
      }

      // 3. Start polling for webhook completion
      _startPollingForCompletion();

    } catch (e) {
      setState(() {
        _status = PayPalCheckoutStatus.failed;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _startPollingForCompletion() {
    _status = PayPalCheckoutStatus.awaitingWebhook;
    _pollingTimer?.cancel();

    int secondsElapsed = 0;
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      secondsElapsed += 3;
      if (secondsElapsed > 180) { // 3 minute timeout
        timer.cancel();
        if (mounted) {
          setState(() {
            _status = PayPalCheckoutStatus.failed;
            _errorMessage = 'Payment confirmation timed out. If you completed payment, your wallet will update shortly.';
          });
        }
        return;
      }

      try {
        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        if (user == null) return;

        if (widget.paymentKind == 'plan') {
          // Check plan_payments table for matching order_id
          final res = await supabase
              .from('plan_payments')
              .select('id')
              .eq('user_id', user.id)
              .eq('order_id', _orderId!)
              .maybeSingle();

          if (res != null) {
            _onPaymentSuccess();
          }
        } else {
          // Check wallet balance or wallet_transactions
          final walletRes = await supabase
              .from('wallets')
              .select('balance')
              .eq('user_id', user.id)
              .maybeSingle();

          if (walletRes != null) {
            final currentBal = (walletRes['balance'] as num).toDouble();
            if (currentBal > _initialWalletBalance) {
              _onPaymentSuccess();
            }
          }
        }
      } catch (_) {
        // Continue polling
      }
    });
  }

  void _onPaymentSuccess() {
    _pollingTimer?.cancel();
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

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('PayPal Checkout'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.payment_rounded, size: 48, color: Color(0xFF003087)),
                    const SizedBox(height: 16),
                    Text(
                      widget.paymentReason ?? 'Wallet Top-up',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.onSurfaceColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.initialAmount != null)
                      Text(
                        '\$${widget.initialAmount!.toStringAsFixed(2)}',
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: const Color(0xFF0070BA),
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: const Color(0xFF0070BA),
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: const InputDecoration(
                          prefixText: '\$ ',
                          border: InputBorder.none,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildStatusWidget(isDark),
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
                      children: const [
                        Icon(Icons.lock_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Pay Securely with PayPal',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
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
                    child: const Text(
                      'Done',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusWidget(bool isDark) {
    switch (_status) {
      case PayPalCheckoutStatus.idle:
        return Text(
          'You will be redirected to PayPal to authorize your payment.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        );
      case PayPalCheckoutStatus.creatingOrder:
        return Column(
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Creating secure PayPal order...'),
          ],
        );
      case PayPalCheckoutStatus.awaitingApproval:
      case PayPalCheckoutStatus.awaitingWebhook:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Awaiting PayPal Confirmation...',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Please complete payment in the opened browser window.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        );
      case PayPalCheckoutStatus.success:
        return Column(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 64),
            SizedBox(height: 12),
            Text(
              'Payment Confirmed!',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        );
      case PayPalCheckoutStatus.failed:
        return Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Payment failed or was cancelled.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
          ],
        );
    }
  }
}
