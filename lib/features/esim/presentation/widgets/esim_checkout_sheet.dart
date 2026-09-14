import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/utils/error_formatter.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_provider_factory.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';
import 'package:keep_sims/features/esim/presentation/widgets/esim_order_status_modal.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/features/payments/presentation/screens/paypal_checkout_screen.dart';

class EsimCheckoutSheet extends ConsumerStatefulWidget {
  final EsimPlan plan;
  final String? speedDetail;

  const EsimCheckoutSheet({super.key, required this.plan, this.speedDetail});

  static Future<void> show(BuildContext context, EsimPlan plan, {String? speedDetail}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EsimCheckoutSheet(plan: plan, speedDetail: speedDetail),
    );
  }

  @override
  ConsumerState<EsimCheckoutSheet> createState() => _EsimCheckoutSheetState();
}

class _EsimCheckoutSheetState extends ConsumerState<EsimCheckoutSheet> {
  bool _isSubmitting = false;
  bool _isLoadingWallet = true;
  double _walletBalance = 0.0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchWalletBalance();
  }

  Future<void> _fetchWalletBalance() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final res = await Supabase.instance.client
            .from('wallets')
            .select('balance')
            .eq('user_id', userId)
            .maybeSingle();

        if (res != null) {
          setState(() {
            _walletBalance = (res['balance'] as num?)?.toDouble() ?? 0.0;
            _isLoadingWallet = false;
          });
          return;
        }
      }
      setState(() => _isLoadingWallet = false);
    } catch (_) {
      setState(() => _isLoadingWallet = false);
    }
  }

  Future<void> _handleConfirmPurchase() async {
    if (_walletBalance < widget.plan.priceUsd) {
      setState(() {
        _errorMessage =
            'Insufficient wallet balance. Please top up your wallet first.';
      });
      return;
    }

    final authGuard = ref.read(paymentAuthGuardProvider);
    final authResult = await authGuard.confirmPayment(
      reason: 'Authenticate to confirm eSIM purchase',
    );
    if (authResult == BiometricResult.cancelled ||
        authResult == BiometricResult.failed ||
        authResult == BiometricResult.lockedOut) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(esimRepositoryProvider);
      final orderId = await repository.requestPurchase(widget.plan.id);

      if (!mounted) return;
      Navigator.pop(context); // Close checkout sheet

      // Show Live Order Status Dialog
      EsimOrderStatusModal.show(context, orderId, widget.plan.name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = RateLimitErrorFormatter.format(e, context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double balanceAfter = _walletBalance - widget.plan.priceUsd;
    final bool hasSufficientBalance = _walletBalance >= widget.plan.priceUsd;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sheet Title
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                'Confirm eSIM Purchase',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Plan Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.plan.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${widget.plan.priceUsd.toStringAsFixed(2)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        // G11. Note what is deliberately NOT converted in this
                        // sheet: the wallet-balance breakdown below and the
                        // "Confirm & Pay $x" button. The user is charged
                        // dollars against a dollar balance, and a local figure
                        // on the commit control would put the app's number and
                        // their card statement in disagreement.
                        ApproxLocalText(
                          widget.plan.priceUsd,
                          textAlign: TextAlign.end,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(
                      label: Text(
                        widget.plan.dataAmountMB <= 0
                            ? 'Unlimited'
                            : (widget.plan.dataAmountMB >= 1024
                                ? '${(widget.plan.dataAmountMB / 1024).toStringAsFixed(1)} GB'
                                : '${widget.plan.dataAmountMB} MB'),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('${widget.plan.durationDays} Days'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                if (widget.speedDetail != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.speed_rounded, size: 14, color: Colors.teal),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.speedDetail!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Wallet Balance Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Wallet Balance:'),
                    _isLoadingWallet
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            '\$${_walletBalance.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('eSIM Cost:'),
                    Text(
                      '-\$${widget.plan.priceUsd.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Balance After Purchase:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '\$${(hasSufficientBalance ? balanceAfter : 0.0).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasSufficientBalance ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Activation Policy Notice
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Validity period begins automatically upon first connection to a supported network.',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ),
            ],
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 20),

          // Action Button
          ElevatedButton(
            onPressed: (_isSubmitting || _isLoadingWallet)
                ? null
                : (hasSufficientBalance
                    ? _handleConfirmPurchase
                    : () {
                        final shortfall = widget.plan.priceUsd - _walletBalance;
                        final depositAmount = shortfall < 5.00 ? 5.00 : shortfall;
                        final navigator = Navigator.of(context);
                        navigator.push(
                          MaterialPageRoute(
                            builder: (_) => PayPalCheckoutScreen(
                              initialAmount: depositAmount,
                              paymentReason:
                                  'Add funds for eSIM ${widget.plan.name}',
                              paymentKind: 'deposit',
                              onSuccess: () async {
                                navigator.pop();
                                _fetchWalletBalance();
                              },
                            ),
                          ),
                        );
                      }),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    hasSufficientBalance
                        ? 'Confirm & Pay \$${widget.plan.priceUsd.toStringAsFixed(2)}'
                        : () {
                            final shortfall = widget.plan.priceUsd - _walletBalance;
                            final depositAmount = shortfall < 5.00 ? 5.00 : shortfall;
                            return 'Add \$${depositAmount.toStringAsFixed(2)} & Continue';
                          }(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
