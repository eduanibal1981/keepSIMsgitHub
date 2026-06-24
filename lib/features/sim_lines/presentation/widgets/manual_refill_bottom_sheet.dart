import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';

class ManualRefillBottomSheet extends ConsumerStatefulWidget {
  final SimLine simLine;

  const ManualRefillBottomSheet({super.key, required this.simLine});

  @override
  ConsumerState<ManualRefillBottomSheet> createState() =>
      _ManualRefillBottomSheetState();
}

class _ManualRefillBottomSheetState
    extends ConsumerState<ManualRefillBottomSheet> {
  double _selectedAmount = 5.0;
  bool _isLoading = false;

  final List<double> _predefinedAmounts = [5.0, 10.0, 15.0, 20.0];

  Future<void> _handleRefill() async {
    setState(() => _isLoading = true);

    try {
      await ref
          .read(simLinesControllerProvider.notifier)
          .performManualRefill(widget.simLine, _selectedAmount);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully refilled \$${_selectedAmount.toStringAsFixed(2)} for ${widget.simLine.phoneNumber}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletControllerProvider);

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
              border: Border.all(
                color: AppColors.darkBorder,
                width: 1,
              ),
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
                            valueColor: AlwaysStoppedAnimation(AppColors.primary),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select Amount',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _predefinedAmounts.map((amount) {
              final isSelected = _selectedAmount == amount;
              return ChoiceChip(
                label: Text('\$${amount.toStringAsFixed(0)}'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedAmount = amount);
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundColor: AppColors.darkCard,
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppColors.primaryLight
                      : AppColors.textSecondaryDark,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.darkBorder,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleRefill,
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
                    'Confirm \$${_selectedAmount.toStringAsFixed(2)} Refill',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
