/// SIM Shield — Referrals & Earnings UI Screen
///
/// Features rich glassmorphism, glowing custom badges, dual metric counters,
/// simulated visual VIP pass card sharing, and validation warning sheets.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import '../controller/referrals_controller.dart';

class ReferralsScreen extends ConsumerStatefulWidget {
  const ReferralsScreen({super.key});

  @override
  ConsumerState<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends ConsumerState<ReferralsScreen> {
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  void _showShareSimulation(BuildContext context, String code) {
    final isDark = context.isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Share Invitation Pass',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Invite your expat friends to secure their prepaid SIMs. Both you and your friend will receive \$2.00 wallet credit immediately upon code validation!',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ShareTargetButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Invited friends via WhatsApp successfully!',
                          ),
                        ),
                      );
                    },
                  ),
                  _ShareTargetButton(
                    icon: Icons.telegram,
                    label: 'Telegram',
                    color: const Color(0xFF0088CC),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Invited friends via Telegram successfully!',
                          ),
                        ),
                      );
                    },
                  ),
                  _ShareTargetButton(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    color: isDark ? AppColors.primary : AppColors.lightPrimary,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Email invitation template created!'),
                        ),
                      );
                    },
                  ),
                  _ShareTargetButton(
                    icon: Icons.link,
                    label: 'Copy Link',
                    color: isDark
                        ? AppColors.secondary
                        : AppColors.lightSecondary,
                    onTap: () {
                      Navigator.pop(context);
                      Clipboard.setData(
                        ClipboardData(
                          text: 'https://keepsims.com/invite?code=$code',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Dynamic registration link copied to clipboard!',
                          ),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitReferralCode(ReferralsState referralsState) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _errorMessage = null;
    });

    final enteredCode = _codeController.text.trim();
    final error = await ref
        .read(referralsControllerProvider.notifier)
        .applyReferral(enteredCode);

    if (error != null) {
      setState(() {
        _errorMessage = error;
      });
    } else {
      _codeController.clear();
      if (mounted) {
        final isDark = context.isDarkMode;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? AppColors.secondary : AppColors.lightSecondary,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.stars,
                  color: isDark
                      ? AppColors.secondary
                      : AppColors.lightSecondary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Bonus Credited! 🎉',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'Welcome credit applied successfully! Your wallet has been credited with \$2.00 reward balance immediately.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'AWESOME',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isDark
                        ? AppColors.secondary
                        : AppColors.lightSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(authControllerProvider);
    final referralsAsync = ref.watch(referralsControllerProvider);
    final isDark = context.isDarkMode;

    final profile = profileState.value;
    final userReferralCode = profile?.referralCode ?? 'SS######';
    final hasReferredBy =
        profile?.referredBy != null && profile!.referredBy!.isNotEmpty;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.onSurfaceColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Refer & Earn',
          style: AppTextStyles.headlineMedium.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [AppColors.darkBg, Color(0xFF131326)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : LinearGradient(
                  colors: [context.scaffoldBackgroundColor, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: referralsAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(
              color: isDark ? AppColors.primary : AppColors.lightPrimary,
            ),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load referrals',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: context.onSurfaceColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    err.toString(),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () =>
                        ref.invalidate(referralsControllerProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.primary
                          : AppColors.lightPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (state) {
            final double earnedAmount = state.referrals.length * 2.00;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Double Metric Summary Counters
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'Total Invited',
                          value: '${state.referrals.length}',
                          subtitle: 'Friends referred',
                          icon: Icons.people_outline,
                          glowColor: isDark
                              ? AppColors.primary
                              : AppColors.lightPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _MetricCard(
                          title: 'Total Earnings',
                          value: '\$${earnedAmount.toStringAsFixed(2)}',
                          subtitle: 'Wallet credit',
                          icon: Icons.account_balance_wallet_outlined,
                          glowColor: isDark
                              ? AppColors.secondary
                              : AppColors.lightSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. Holographic Protected Shield Share Pass
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(
                              colors: [Color(0xFF25254A), Color(0xFF161633)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [
                                context.primaryColor.withValues(alpha: 0.08),
                                Colors.white,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            (isDark
                                    ? AppColors.primary
                                    : AppColors.lightPrimary)
                                .withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isDark
                                      ? AppColors.primary
                                      : AppColors.lightPrimary)
                                  .withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        (isDark
                                                ? AppColors.primary
                                                : AppColors.lightPrimary)
                                            .withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.verified_user_outlined,
                                    color: isDark
                                        ? AppColors.secondary
                                        : AppColors.lightSecondary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SIM SHIELD',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: context.onSurfaceColor,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    Text(
                                      'Active Line Protection',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: isDark
                                            ? AppColors.secondary
                                            : AppColors.lightSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      (isDark
                                              ? AppColors.secondary
                                              : AppColors.lightSecondary)
                                          .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                'VIP PASS',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: isDark
                                      ? AppColors.secondaryLight
                                      : AppColors.lightSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Divider(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            height: 1,
                          ),
                        ),
                        Text(
                          'YOUR EXCLUSIVES REFERRAL CODE',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  userReferralCode,
                                  style: AppTextStyles.displayLarge.copyWith(
                                    color: context.onSurfaceColor,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: userReferralCode),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Referral code copied to clipboard!',
                                    ),
                                    backgroundColor: AppColors.success,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.primary
                                      : AppColors.lightPrimary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.copy,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Copy',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Share this pass code with friends. Once they enter your code, both of your accounts get credited with a \$2.00 reward bonus instantly!',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showShareSimulation(context, userReferralCode),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark
                                    ? AppColors.secondary
                                    : AppColors.lightPrimary,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              Icons.share_outlined,
                              color: isDark
                                  ? AppColors.secondary
                                  : AppColors.lightPrimary,
                              size: 18,
                            ),
                            label: Text(
                              'SHARE PASS CARD',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: isDark
                                    ? AppColors.secondary
                                    : AppColors.lightPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Redeem Welcome Code Card
                  Text(
                    'Claim Referral Bonus',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: hasReferredBy
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppColors.success,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Bonus Already Claimed',
                                    style: AppTextStyles.titleMedium.copyWith(
                                      color: context.onSurfaceColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'You successfully claimed your \$2.00 welcome bonus using referral code: ${profile.referredBy}. Enjoy expat shield protection!',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          )
                        : Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Were you referred by a friend? Enter their referral code below to claim your free \$2.00 start-up credit!',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _codeController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  style: TextStyle(
                                    color: context.onSurfaceColor,
                                    letterSpacing: 1.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'ENTER CODE (e.g. SSXXXXXX)',
                                    hintStyle: TextStyle(
                                      color: isDark
                                          ? AppColors.textTertiaryDark
                                          : AppColors.textTertiaryLight,
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? AppColors.darkBg
                                        : AppColors.lightBg,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? AppColors.primary
                                            : AppColors.lightPrimary,
                                      ),
                                    ),
                                    errorStyle: const TextStyle(
                                      color: AppColors.error,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter a referral code';
                                    }
                                    if (value.trim().length < 6) {
                                      return 'Code must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: AppColors.error,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(color: AppColors.error),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: state.isSubmitting
                                        ? null
                                        : () => _submitReferralCode(state),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark
                                          ? AppColors.secondary
                                          : AppColors.lightPrimary,
                                      foregroundColor: isDark
                                          ? AppColors.textPrimaryLight
                                          : Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      disabledBackgroundColor:
                                          (isDark
                                                  ? AppColors.secondary
                                                  : AppColors.lightPrimary)
                                              .withValues(alpha: 0.4),
                                    ),
                                    child: state.isSubmitting
                                        ? SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: isDark
                                                  ? AppColors.textPrimaryLight
                                                  : Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            'CLAIM WELCOME BONUS',
                                            style: AppTextStyles.labelLarge
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1,
                                                ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // 4. Friends Ledger
                  Text(
                    'Referred Friends List',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (state.referrals.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.supervised_user_circle_outlined,
                            color:
                                (isDark
                                        ? AppColors.textTertiaryDark
                                        : AppColors.textTertiaryLight)
                                    .withValues(alpha: 0.4),
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No referrals logged yet',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: context.onSurfaceColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Share your referral code and invite expats to get \$2.00 rewards!',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.referrals.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = state.referrals[index];
                        final name =
                            item.referredProfile?.fullName ??
                            'Shield Expat Friend';
                        final email =
                            item.referredProfile?.email ??
                            'Verification pending';

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor:
                                    (isDark
                                            ? AppColors.primary
                                            : AppColors.lightPrimary)
                                        .withValues(alpha: 0.2),
                                child: Text(
                                  _getInitials(name),
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: isDark
                                        ? AppColors.primaryLight
                                        : AppColors.lightPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: AppTextStyles.titleMedium.copyWith(
                                        color: context.onSurfaceColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (isDark
                                              ? AppColors.success
                                              : AppColors.lightSuccess)
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '+\$${item.rewardAmount.toStringAsFixed(2)}',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: isDark
                                        ? AppColors.healthGreen
                                        : AppColors.lightSuccess,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color glowColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.labelSmall.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                icon,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.headlineLarge.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.bold,
              shadows: isDark
                  ? [Shadow(color: glowColor.withValues(alpha: 0.3), blurRadius: 10)]
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareTargetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareTargetButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
