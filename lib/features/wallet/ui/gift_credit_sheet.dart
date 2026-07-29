/// SIM Shield — Send Credit sheet (G3)
///
/// Feature suggestion #3 in doc/PRODUCTION_PLAN_REVIEW.md § 6.
///
/// Deliberately thin. `transfer_wallet_credit` owns every rule — minimum,
/// maximum, daily cap, which part of the balance is transferable, whether the
/// recipient can receive at all — and returns a sentence written to be shown to
/// the user. This sheet does the two things a client is actually better placed
/// to do: stop an obviously-empty form before it costs a rate-limit token, and
/// turn the two refusals that carry a number into a one-tap correction.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
import '../controller/wallet_controller.dart';
import '../model/gift_transfer_model.dart';

class GiftCreditSheet extends ConsumerStatefulWidget {
  const GiftCreditSheet({super.key});

  @override
  ConsumerState<GiftCreditSheet> createState() => _GiftCreditSheetState();
}

class _GiftCreditSheetState extends ConsumerState<GiftCreditSheet> {
  final _emailController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _busy = false;
  String? _error;
  GiftTransferResult? _sent;

  @override
  void dispose() {
    _emailController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    // The only two checks worth doing here: both would otherwise spend one of
    // the five recipient lookups an hour on a form the user has not filled in.
    if (email.isEmpty) {
      setState(() => _error = 'Enter the email address of the person to pay.');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    await HapticHelper.mediumImpact();

    try {
      final result = await ref
          .read(walletControllerProvider.notifier)
          .sendGift(
            recipientEmail: email,
            amount: amount,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );

      if (!mounted) return;

      // null means the biometric prompt was dismissed — no money moved and
      // nothing was sent, so leave the form exactly as it was.
      if (result == null) {
        setState(() => _busy = false);
        return;
      }

      if (result.success) {
        await HapticHelper.successFeedback();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _sent = result;
        });
      } else {
        setState(() {
          _busy = false;
          _error = result.message;
          // The server sends back the real ceiling on these two, so the
          // correction below can offer it.
          _suggestedAmount = result.giftable ?? _suggestedAmount;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double? _suggestedAmount;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final surface = isDark ? AppColors.darkSurface : Colors.white;

    if (_sent != null) {
      return _buildSentConfirmation(context, isDark);
    }

    // Watched, not read off the notifier: a transfer that lands while this
    // sheet is open changes the ceiling, and a stale figure here is a figure
    // the server will refuse.
    final wallet = ref.watch(walletControllerProvider).value;
    final giftable = wallet == null
        ? 0.0
        : giftableBalance(
            balance: wallet.wallet.balance,
            transactions: wallet.transactions,
          );
    final household = ref.watch(householdControllerProvider).value;
    final quickPicks = <String>{
      ...?household?.members
          .where((m) => m.memberEmail.isNotEmpty)
          .map((m) => m.memberEmail),
      ...?household?.memberships
          .where((m) => m.memberEmail.isNotEmpty)
          .map((m) => m.memberEmail),
    }.toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.card_giftcard_rounded,
                    color: isDark
                        ? AppColors.primaryLight
                        : AppColors.lightPrimary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Send credit',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'They get it in their KeepSIMs wallet straight away. '
                'Available to send: \$${giftable.toStringAsFixed(2)}.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 18),

              // Household members are the people this feature exists for, so
              // offer them instead of making the user retype an address.
              if (quickPicks.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quickPicks
                      .map(
                        (email) => ActionChip(
                          avatar: const Icon(Icons.people_alt_rounded, size: 16),
                          label: Text(
                            email,
                            style: AppTextStyles.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () async {
                            await HapticHelper.lightTick();
                            _emailController.text = email;
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
              ],

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Their email address',
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount (USD)',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _noteController,
                maxLength: 140,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Happy birthday!',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                  border: OutlineInputBorder(),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.healthRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.healthRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _error!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.healthRed,
                        ),
                      ),
                      // A refusal that came back with a number is a correction
                      // the user can take in one tap, not a dead end.
                      if (_suggestedAmount != null && _suggestedAmount! > 0) ...[
                        const SizedBox(height: 6),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            _amountController.text = _suggestedAmount!
                                .toStringAsFixed(2);
                            setState(() {
                              _error = null;
                              _suggestedAmount = null;
                            });
                          },
                          child: Text(
                            'Send \$${_suggestedAmount!.toStringAsFixed(2)} instead',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.primaryLight
                                  : AppColors.lightPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_busy ? 'Sending…' : 'Send credit'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Transfers are instant and cannot be reversed. Only credit you '
                'added yourself can be sent on.',
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSentConfirmation(BuildContext context, bool isDark) {
    final sent = _sent!;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            sent.alreadySent
                ? 'Already sent'
                : '\$${(sent.amount ?? 0).toStringAsFixed(2)} sent',
            style: AppTextStyles.titleLarge.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sent.alreadySent
                ? 'This transfer had already gone through, so nothing was sent twice.'
                : '${sent.recipientLabel} can spend it right away.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
