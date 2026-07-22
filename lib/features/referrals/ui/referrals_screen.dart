/// SIM Shield — Referrals & Earnings UI Screen
///
/// Clean, modern points-based referral dashboard with points balance, progress indicator,
/// code copy/share capabilities, redemption controls, and localization support.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import '../controller/referrals_controller.dart';
import '../model/referral_model.dart';

class ReferralsScreen extends ConsumerStatefulWidget {
  const ReferralsScreen({super.key});

  @override
  ConsumerState<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends ConsumerState<ReferralsScreen> {
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isApplying = false;
  bool _isRedeeming = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _copyToClipboard(
    BuildContext context,
    String code,
    AppLocalizations l,
  ) async {
    await HapticHelper.mediumImpact();
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.codeCopied),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleApplyCode(AppLocalizations l) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isApplying = true);
    final code = _codeController.text.trim();
    final error = await ref
        .read(referralsControllerProvider.notifier)
        .applyReferral(code);

    if (!mounted) return;
    setState(() => _isApplying = false);

    final messenger = ScaffoldMessenger.of(context);
    if (error == null) {
      _codeController.clear();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.applyCodeSuccess),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleRedeem(AppLocalizations l) async {
    await HapticHelper.mediumImpact();
    setState(() => _isRedeeming = true);

    final error = await ref
        .read(referralsControllerProvider.notifier)
        .redeemPoints();

    if (!mounted) return;
    setState(() => _isRedeeming = false);

    final messenger = ScaffoldMessenger.of(context);
    if (error == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.redeemSuccess),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    final summaryAsync = ref.watch(referralsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.referralsTitle,
          style: AppTextStyles.titleLarge.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 12),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.onSurfaceColor,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(referralsControllerProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (summary) {
          final pointsNeeded = (10 - (summary.pointsBalance % 10));
          final effectivePointsNeeded = summary.pointsBalance >= 10
              ? 0
              : pointsNeeded;
          final progressRatio = (summary.pointsBalance % 10) / 10.0;
          final canRedeem = summary.pointsBalance >= 10;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(referralsControllerProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subtitle / Banner
                  Text(
                    l.referralsSubtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.onSurfaceColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Referral Code Card
                  _buildCodeCard(context, summary.referralCode, l, isDark),

                  const SizedBox(height: 20),

                  // Points Balance & Redemption Card
                  _buildPointsCard(
                    context,
                    summary,
                    effectivePointsNeeded,
                    progressRatio,
                    canRedeem,
                    l,
                    isDark,
                  ),

                  const SizedBox(height: 24),

                  // Apply Code Section
                  _buildApplyCodeCard(context, l, isDark),

                  const SizedBox(height: 24),

                  // How it works
                  _buildHowItWorksCard(context, l, isDark),

                  const SizedBox(height: 24),

                  // Referred Friends List
                  _buildReferredFriendsSection(
                    context,
                    summary.referredFriends,
                    l,
                    isDark,
                  ),

                  const SizedBox(height: 24),

                  // Points History Section
                  _buildPointHistorySection(
                    context,
                    summary.pointHistory,
                    l,
                    isDark,
                  ),

                  const SizedBox(height: 24),

                  // Redemption History Section
                  _buildRedemptionHistorySection(
                    context,
                    summary.redemptions,
                    l,
                    isDark,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCodeCard(
    BuildContext context,
    String code,
    AppLocalizations l,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFF38BDF8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.card_giftcard_rounded,
                color: isDark
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF0284C7),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                l.referralCode,
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SelectableText(
                  code.isEmpty ? '—' : code,
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: isDark ? Colors.white : AppColors.primary,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: code.isEmpty
                      ? null
                      : () => _copyToClipboard(context, code, l),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(l.copyCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsCard(
    BuildContext context,
    ReferralSummary summary,
    int effectivePointsNeeded,
    double progressRatio,
    bool canRedeem,
    AppLocalizations l,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                    l.pointsBalance,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.onSurfaceColor.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${summary.pointsBalance}',
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l.pointsUnit,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: context.onSurfaceColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: canRedeem ? 1.0 : progressRatio,
              minHeight: 10,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(
                canRedeem ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            canRedeem
                ? l.redeemSuccess.split('!')[0]
                : l.progressToNextRedemption(effectivePointsNeeded),
            style: AppTextStyles.caption.copyWith(
              color: canRedeem
                  ? AppColors.success
                  : context.onSurfaceColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          // Redeem Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (canRedeem && !_isRedeeming)
                  ? () => _handleRedeem(l)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isRedeeming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      l.redeemButton,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: canRedeem
                            ? Colors.white
                            : context.onSurfaceColor.withValues(alpha: 0.3),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyCodeCard(
    BuildContext context,
    AppLocalizations l,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.applyCodeTitle,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: context.onSurfaceColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: l.applyCodeHint,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return l.applyCodeHint;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isApplying ? null : () => _handleApplyCode(l),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  child: _isApplying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l.applyCodeButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksCard(
    BuildContext context,
    AppLocalizations l,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l.howItWorksTitle,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.onSurfaceColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStepRow(l.howItWorksStep1, context),
          const SizedBox(height: 8),
          _buildStepRow(l.howItWorksStep2, context),
          const SizedBox(height: 8),
          _buildStepRow(l.howItWorksStep3, context),
        ],
      ),
    );
  }

  Widget _buildStepRow(String text, BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(
        color: context.onSurfaceColor.withValues(alpha: 0.75),
        height: 1.4,
      ),
    );
  }

  Widget _buildReferredFriendsSection(
    BuildContext context,
    List<ReferredFriend> friends,
    AppLocalizations l,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l.referredFriendsTitle} (${friends.length})',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: context.onSurfaceColor,
          ),
        ),
        const SizedBox(height: 10),
        if (friends.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Text(
              l.noReferredFriends,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: friends.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final friend = friends[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
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
                      radius: 18,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      child: Text(
                        friend.displayName != null &&
                                friend.displayName!.isNotEmpty
                            ? friend.displayName![0].toUpperCase()
                            : 'F',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friend.displayName ?? 'Referred Friend',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.onSurfaceColor,
                            ),
                          ),
                          if (friend.createdAt != null)
                            Text(
                              friend.createdAt!.toIso8601String().split('T')[0],
                              style: AppTextStyles.caption.copyWith(
                                color: context.onSurfaceColor.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildPointHistorySection(
    BuildContext context,
    List<ReferralPointEntry> history,
    AppLocalizations l,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.pointHistoryTitle,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: context.onSurfaceColor,
          ),
        ),
        const SizedBox(height: 10),
        if (history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Text(
              l.noPointsEarned,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length > 5 ? 5 : history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = history[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '+${item.points} ${l.pointsUnit}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                          if (item.createdAt != null)
                            Text(
                              item.createdAt!.toIso8601String().split('T')[0],
                              style: AppTextStyles.caption.copyWith(
                                color: context.onSurfaceColor.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRedemptionHistorySection(
    BuildContext context,
    List<ReferralRedemptionEntry> redemptions,
    AppLocalizations l,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.redemptionHistoryTitle,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: context.onSurfaceColor,
          ),
        ),
        const SizedBox(height: 10),
        if (redemptions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Text(
              l.noRedemptions,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: redemptions.length > 5 ? 5 : redemptions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = redemptions[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.remove_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '-${item.pointsSpent} ${l.pointsUnit} -> \$2.00 Credit',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          if (item.createdAt != null)
                            Text(
                              item.createdAt!.toIso8601String().split('T')[0],
                              style: AppTextStyles.caption.copyWith(
                                color: context.onSurfaceColor.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
