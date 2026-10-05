/// SIM Shield — Refund Funds Sheet
///
/// Customer interface for quoting and submitting cash refunds of unused paid deposits.
/// Adheres to FIFO lot provenance and 180-day gateway return policies.
library;

import 'package:flutter/material.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import '../controller/wallet_controller.dart';

class RefundFundsSheet extends ConsumerStatefulWidget {
  const RefundFundsSheet({super.key});

  @override
  ConsumerState<RefundFundsSheet> createState() => _RefundFundsSheetState();
}

class _RefundFundsSheetState extends ConsumerState<RefundFundsSheet> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _loadingQuote = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _quote;
  Map<String, dynamic>? _successResult;

  @override
  void initState() {
    super.initState();
    _fetchQuote();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuote() async {
    setState(() {
      _loadingQuote = true;
      _error = null;
    });

    try {
      final quote = await ref
          .read(walletControllerProvider.notifier)
          .quoteRefund();
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _loadingQuote = false;
        final eligible = (quote['eligible_amount'] as num?)?.toDouble() ?? 0.0;
        if (eligible > 0) {
          _amountController.text = eligible.toStringAsFixed(2);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingQuote = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _submitRefund() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid refund amount.');
      return;
    }

    final eligible = (_quote?['eligible_amount'] as num?)?.toDouble() ?? 0.0;
    if (amount > eligible + 0.001) {
      setState(
        () => _error =
            'Amount exceeds eligible refundable balance of \$${eligible.toStringAsFixed(2)}.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    await HapticHelper.mediumImpact();

    try {
      final reason = _reasonController.text.trim().isEmpty
          ? 'Customer requested refund of unused balance'
          : _reasonController.text.trim();

      final res = await ref
          .read(walletControllerProvider.notifier)
          .requestRefund(amount: amount, reason: reason);

      await HapticHelper.successFeedback();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _successResult = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.2,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.undo_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Refund Unused Funds',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'Direct return to your original PayPal capture',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_loadingQuote)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_successResult != null)
            _buildSuccessView(isDark)
          else
            _buildFormView(isDark),
        ],
      ),
    );
  }

  Widget _buildSuccessView(bool isDark) {
    final amount = (_successResult?['amount'] as num?)?.toDouble() ?? 0.0;

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Refund Request Submitted',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A hold of \$${amount.toStringAsFixed(2)} has been placed on your wallet. Your refund is being processed directly to your PayPal account.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormView(bool isDark) {
    final eligible = (_quote?['eligible_amount'] as num?)?.toDouble() ?? 0.0;
    final available = (_quote?['available_balance'] as num?)?.toDouble() ?? 0.0;
    final nonRefundable = available > eligible ? (available - eligible) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Balance breakdown card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    'Available Balance',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  Text(
                    '\$${available.toStringAsFixed(2)}',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Eligible for Cash Refund',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '\$${eligible.toStringAsFixed(2)}',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              if (nonRefundable > 0.001) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Promotional / Non-refundable',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '\$${nonRefundable.toStringAsFixed(2)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Policy Notice
        Text(
          eligible > 0
              ? 'Only unspent funds deposited via PayPal within the last 180 days are refundable to original payment methods. Promotional credits and gifts cannot be refunded to cash.'
              : 'You do not have any paid deposits within the 180-day refund window eligible for cash return. Promotional balances and expired lots can only be spent on services.',
          style: AppTextStyles.bodySmall.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),

        if (eligible > 0) ...[
          // Amount Field
          Text(
            'Refund Amount',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              prefixText: '\$ ',
              hintText: '0.00',
              filled: true,
              fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              suffixIcon: TextButton(
                onPressed: () {
                  _amountController.text = eligible.toStringAsFixed(2);
                },
                child: const Text('MAX'),
              ),
            ),
          ),
          ApproxLocalAmountPreview(_amountController),
          const SizedBox(height: 12),

          // Reason Field
          Text(
            'Reason (Optional)',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _reasonController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g., Unused trip balance, service no longer needed',
              filled: true,
              fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],

        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: (eligible <= 0 || _submitting) ? null : _submitRefund,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _amountController,
                  builder: (context, value, _) {
                    final amount = double.tryParse(value.text.trim());
                    return Text(
                      eligible <= 0
                          ? 'No Refundable Funds'
                          : amount != null && amount.isFinite && amount > 0
                          ? 'Request ${Money.usd(amount)} USD refund'
                          : 'Submit Refund Request',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
