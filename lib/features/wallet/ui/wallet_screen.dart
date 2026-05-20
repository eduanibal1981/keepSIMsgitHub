/// SIM Shield — Wallet Screen
///
/// High-end dark-mode user interface representing the prepaid wallet.
/// Integrates card deposit models, transactional ledgers, and glowing SVG analytics.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import '../controller/wallet_controller.dart';
import '../model/wallet_model.dart';
import 'package:keep_sims/core/widgets/shimmer_loading.dart';
import 'package:keep_sims/core/widgets/error_state.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(walletControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Wallet Ledger',
          style: AppTextStyles.headlineLarge.copyWith(
            color: AppColors.textPrimaryDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryLight),
            onPressed: () async {
              await HapticHelper.mediumImpact();
              ref.invalidate(walletControllerProvider);
              await HapticHelper.successFeedback();
            },
          ),
        ],
      ),
      body: stateAsync.when(
        data: (state) => _buildContent(context, state),
        loading: () => const WalletShimmer(),
        error: (err, stack) => ErrorStateView(
          errorMessage: err.toString(),
          onRetry: () async {
            await HapticHelper.mediumImpact();
            ref.invalidate(walletControllerProvider);
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WalletState state) {
    final balance = state.wallet.balance;
    final isLowBalance = balance < 10.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          
          // ── Glassmorphic Neon Credit Card ───────────────────────
          _buildNeonCreditCard(balance, state.wallet.currency),
          
          const SizedBox(height: 24),

          // ── Balance Threshold Warnings ────────────────────────
          if (isLowBalance) _buildLowBalanceWarning(),

          // ── Action Row Buttons ────────────────────────────────
          _buildQuickActionButtons(context),

          const SizedBox(height: 28),

          // ── Spending Analytics (Custom curves) ─────────────────
          Text(
            'Spend Analysis',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: 12),
          _buildSpendAnalyticsChart(),

          const SizedBox(height: 28),

          // ── Ledger Transaction History Feed ────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction History',
                style: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimaryDark),
              ),
              Text(
                '${state.transactions.length} items',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiaryDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTransactionList(state.transactions),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildNeonCreditCard(double balance, String currency) {
    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative background glowing circular elements
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            
            // Glossy card reflection sheen
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            // Card content layout
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SIM SHIELD PREPAID',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Icon(
                            Icons.contactless_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ],
                      ),
                      // Card Provider Logo Mockup
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'VISA',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Wallet balance text
                  Text(
                    'Active Balance',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$${balance.toStringAsFixed(2)}',
                        style: AppTextStyles.walletBalance.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        currency,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Mock card numbers
                  Text(
                    '••••  ••••  ••••  4242',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowBalanceWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.healthRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.healthRed.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.healthRed,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Critical Balance Level',
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.healthRed),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your balance is below \$10.00. Scheduled SIM topups may fail soon.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.add_circle_rounded,
          label: 'Deposit Funds',
          color: AppColors.primaryLight,
          onTap: () => _showDepositModalSheet(context),
        ),
        _buildActionButton(
          icon: Icons.history_edu_rounded,
          label: 'Export Ledger',
          color: AppColors.secondaryLight,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ledger history exported as CSV.')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () async {
        await HapticHelper.lightTick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.darkBorder,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendAnalyticsChart() {
    return Container(
      width: double.infinity,
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prepaid Monthly Outflow',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
              ),
              Text(
                'Avg: \$14.40/mo',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.secondary),
              ),
            ],
          ),
          const Spacer(),
          // Custom SVG line curve representation
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: CustomPaint(
                painter: AnalyticsChartPainter(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Months labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildChartLabel('Dec'),
              _buildChartLabel('Jan'),
              _buildChartLabel('Feb'),
              _buildChartLabel('Mar'),
              _buildChartLabel('Apr'),
              _buildChartLabel('May'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(color: AppColors.textTertiaryDark),
    );
  }

  Widget _buildTransactionList(List<WalletTransaction> transactions) {
    if (transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.history_toggle_off_rounded, color: AppColors.textTertiaryDark, size: 40),
            const SizedBox(height: 12),
            Text(
              'No transactions recorded yet.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return _buildTransactionItem(tx);
      },
    );
  }

  Widget _buildTransactionItem(WalletTransaction tx) {
    final isDeposit = tx.type == 'deposit' || tx.type == 'auto_fund';
    final isReferral = tx.type == 'referral' || tx.type == 'referral_credit';
    final isRefund = tx.type == 'refund';
    
    Color typeColor = AppColors.warning; // Default 'topup' is warning orange
    IconData typeIcon = Icons.phonelink_ring_rounded;
    String sign = '-';

    if (isDeposit) {
      typeColor = AppColors.success;
      typeIcon = Icons.add_circle_outline_rounded;
      sign = '+';
    } else if (isReferral) {
      typeColor = AppColors.primaryLight;
      typeIcon = Icons.stars_rounded;
      sign = '+';
    } else if (isRefund) {
      typeColor = AppColors.success;
      typeIcon = Icons.stars_rounded;
      sign = '+';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder, width: 1),
      ),
      child: Row(
        children: [
          // Icon block
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              typeIcon,
              color: typeColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          // Description details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ?? (isDeposit ? 'Deposit Funds' : 'Line Renewal'),
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimaryDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  tx.createdAt != null
                      ? '${tx.createdAt!.day}/${tx.createdAt!.month}/${tx.createdAt!.year}'
                      : 'Just now',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiaryDark),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Amount text
          Text(
            '$sign\$${tx.amount.toStringAsFixed(2)}',
            style: AppTextStyles.titleLarge.copyWith(
              color: typeColor,
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Deposit Sheet Modal ───────────────────────────────────────
  void _showDepositModalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DepositModalSheet(),
    );
  }
}

/// Custom Bezier Curve Painter for Spend Analysis Charts.
class AnalyticsChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.25)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.15),
          AppColors.primary.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // Define curve keypoints representing typical SIM topup renewals
    final p0 = Offset(0, size.height * 0.7);
    final p1 = Offset(size.width * 0.2, size.height * 0.85);
    final p2 = Offset(size.width * 0.4, size.height * 0.3);
    final p3 = Offset(size.width * 0.6, size.height * 0.55);
    final p4 = Offset(size.width * 0.8, size.height * 0.15);
    final p5 = Offset(size.width, size.height * 0.45);

    // Compute curved paths
    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(size.width * 0.1, size.height * 0.8, size.width * 0.1, size.height * 0.85, p1.dx, p1.dy)
      ..cubicTo(size.width * 0.3, size.height * 0.85, size.width * 0.3, size.height * 0.3, p2.dx, p2.dy)
      ..cubicTo(size.width * 0.5, size.height * 0.3, size.width * 0.5, size.height * 0.55, p3.dx, p3.dy)
      ..cubicTo(size.width * 0.7, size.height * 0.55, size.width * 0.7, size.height * 0.15, p4.dx, p4.dy)
      ..cubicTo(size.width * 0.9, size.height * 0.15, size.width * 0.9, size.height * 0.45, p5.dx, p5.dy);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    // Render elements
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Draw glowing node dots at key vertices
    final dotPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.fill;
      
    final dotGlow = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(p2, 8, dotGlow);
    canvas.drawCircle(p2, 4, dotPaint);

    canvas.drawCircle(p4, 8, dotGlow);
    canvas.drawCircle(p4, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DepositModalSheet extends ConsumerStatefulWidget {
  const DepositModalSheet({super.key});

  @override
  ConsumerState<DepositModalSheet> createState() => _DepositModalSheetState();
}

class _DepositModalSheetState extends ConsumerState<DepositModalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '20.00');
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _selectQuickAmount(String amount) {
    setState(() {
      _amountController.text = amount;
    });
  }

  Future<void> _submitDeposit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid deposit amount.')),
      );
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    final success = await ref
        .read(walletControllerProvider.notifier)
        .deposit(amount, description: 'Deposit via Card ending in ${_cardNumberController.text.substring(_cardNumberController.text.length - 4)}');

    if (success) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'Successfully deposited \$$amount USD!',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.healthRed,
            content: Text('Failed to deposit funds. Please check card connection.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWebMobileOffset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + isWebMobileOffset),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border(
          top: BorderSide(color: AppColors.darkBorder, width: 1.5),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull Bar indicator
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.darkBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Load Credit Funds',
                    style: AppTextStyles.headlineMedium.copyWith(color: AppColors.textPrimaryDark),
                  ),
                  if (_isSubmitting)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Quick selection amounts ──────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickSelectButton('10.00'),
                  _buildQuickSelectButton('20.00'),
                  _buildQuickSelectButton('50.00'),
                  _buildQuickSelectButton('100.00'),
                ],
              ),
              const SizedBox(height: 16),

              // ── Custom Input Amount ────────────────────────────────
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimaryDark),
                decoration: InputDecoration(
                  labelText: 'Deposit Amount (USD)',
                  labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                  prefixIcon: const Icon(Icons.attach_money_rounded, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.darkBg,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.darkBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter an amount';
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0.0) return 'Enter a positive number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Credit Card Inputs ─────────────────────────────────
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                maxLength: 19,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CardNumberInputFormatter(),
                ],
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimaryDark),
                decoration: InputDecoration(
                  labelText: 'Visa Card Number',
                  labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                  prefixIcon: const Icon(Icons.credit_card_rounded, color: AppColors.secondary),
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.darkBg,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.darkBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter card number';
                  final clean = val.replaceAll(' ', '');
                  if (clean.length < 16) return 'Must be 16 digits';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CardExpiryInputFormatter(),
                      ],
                      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimaryDark),
                      decoration: InputDecoration(
                        labelText: 'Expiry (MM/YY)',
                        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.darkBg,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.darkBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Expiry required';
                        if (val.length < 5) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      obscureText: true,
                      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimaryDark),
                      decoration: InputDecoration(
                        labelText: 'CVV',
                        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.darkBg,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.darkBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'CVV required';
                        if (val.length < 3) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Submit Button ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitDeposit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    _isSubmitting ? 'Verifying Card Security...' : 'Authorize Deposit Funds',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSelectButton(String amount) {
    final active = _amountController.text == amount;
    return InkWell(
      onTap: () => _selectQuickAmount(amount),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.15) : AppColors.darkBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.darkBorder,
            width: 1.2,
          ),
        ),
        child: Text(
          '\$$amount',
          style: AppTextStyles.labelMedium.copyWith(
            color: active ? AppColors.primaryLight : AppColors.textSecondaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Helper formatter to insert spaces every 4 digits in card inputs.
class CardNumberInputFormatter extends TextInputFormatter {
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
      final nonSpaceLength = i + 1;
      if (nonSpaceLength % 4 == 0 && nonSpaceLength != text.length) {
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

/// Helper formatter to insert a slash after 2 digits in expiry inputs (MM/YY).
class CardExpiryInputFormatter extends TextInputFormatter {
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
      final nonSlashLength = i + 1;
      if (nonSlashLength == 2 && nonSlashLength != text.length) {
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
