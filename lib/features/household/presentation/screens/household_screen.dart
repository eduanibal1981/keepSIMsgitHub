import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/widgets/shimmer_loading.dart';
import 'package:keep_sims/core/widgets/empty_state.dart';
import 'package:keep_sims/core/widgets/error_state.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import '../controllers/household_controller.dart';
import '../providers/household_spend_provider.dart';
import '../../data/models/household_member_model.dart';
import '../../data/models/household_spend_model.dart';

class HouseholdScreen extends ConsumerStatefulWidget {
  const HouseholdScreen({super.key});

  @override
  ConsumerState<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends ConsumerState<HouseholdScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticHelper.lightTick();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(householdControllerProvider);
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.onSurfaceColor),
          onPressed: () async {
            await HapticHelper.lightTick();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Household Sharing',
          style: AppTextStyles.headlineMedium.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6366F1),
          labelColor: context.onSurfaceColor,
          unselectedLabelColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          labelStyle: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: AppTextStyles.bodyMedium,
          dividerColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.lightBorder.withValues(alpha: 0.3),
          tabs: const [
            Tab(text: 'My Family'),
            Tab(text: 'Received'),
            Tab(text: 'Joined'),
          ],
        ),
      ),
      body: stateAsync.when(
        data: (state) => TabBarView(
          controller: _tabController,
          children: [
            _buildMyFamilyTab(state.members),
            _buildReceivedTab(state.invitations),
            Column(
              children: [
                _buildAllowanceBanner(),
                Expanded(child: _buildJoinedTab(state.memberships)),
              ],
            ),
          ],
        ),
        loading: () => const SIMLinesShimmer(),
        error: (err, stack) => ErrorStateView(
          errorMessage: err.toString(),
          onRetry: () async {
            await HapticHelper.mediumImpact();
            ref.invalidate(householdControllerProvider);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await HapticHelper.lightTick();
          _showInviteDialog(context);
        },
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Invite Member',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── Tab 1: My Family (Members I invited) ───────────────────────────
  Widget _buildMyFamilyTab(List<HouseholdMember> members) {
    final isDark = context.isDarkMode;
    if (members.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Your Household is Empty',
        description:
            'Invite family members by email to share your prepaid SIM lines and renewals.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final isPending = member.inviteStatus == 'pending';

        return Container(
          margin: const EdgeInsets.only(bottom: 14.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCard.withValues(alpha: 0.4)
                : AppColors.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
            children: [
              // Avatar representation
              CircleAvatar(
                radius: 24,
                backgroundColor: isPending
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04))
                    : const Color(0xFF6366F1).withValues(alpha: 0.1),
                child: Text(
                  (member.memberName ?? member.memberEmail)
                      .substring(0, 1)
                      .toUpperCase(),
                  style: TextStyle(
                    color: isPending
                        ? (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                        : const Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.memberName ?? member.memberEmail,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (member.memberName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        member.memberEmail,
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Badges
                    Row(
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isPending
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                                : const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isPending ? 'PENDING' : 'ACCEPTED',
                            style: TextStyle(
                              color: isPending
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF10B981),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: member.role == 'manager'
                                ? const Color(0xFFA855F7).withValues(alpha: 0.1)
                                : const Color(0xFF3B82F6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            member.role.toUpperCase(),
                            style: TextStyle(
                              color: member.role == 'manager'
                                  ? const Color(0xFFA855F7)
                                  : const Color(0xFF3B82F6),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons (Revoke or Remove)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                onPressed: () async {
                  await HapticHelper.lightTick();
                  _confirmRemove(context, member);
                },
              ),
            ],
          ),
              // G6: the wallet-sharing half of the row.
              _buildSpendFooter(member),
            ],
          ),
        );
      },
    );
  }

  // ── G6: per-member spend cap + month-to-date usage ──────────────────
  //
  // `monthly_cap_usd = 0` is the default on every membership and means "may
  // NOT spend my wallet" — not "no limit". The copy has to make that
  // unambiguous, because the failure mode of getting it backwards is a
  // stranger spending the owner's balance.
  Widget _buildSpendFooter(HouseholdMember member) {
    final isDark = context.isDarkMode;
    final summaryAsync = ref.watch(householdSpendSummaryProvider);

    final HouseholdSpendRow? row = summaryAsync.value
        ?.where((r) => r.memberRowId == member.id)
        .firstOrNull;

    if (row == null) return const SizedBox.shrink();

    final bool canFund = row.canBeFunded;
    final Color accent = row.isExhausted
        ? AppColors.warning
        : (row.isFunded ? AppColors.success : AppColors.info);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.lightBorder,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  row.isFunded
                      ? 'Spends my wallet · \$${row.spentMtdUsd.toStringAsFixed(2)} of '
                          '\$${row.monthlyCapUsd.toStringAsFixed(2)} this month'
                      : (canFund
                          ? 'Pays with their own wallet'
                          : 'Managers only — a viewer cannot spend your wallet'),
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: canFund ? () => _showCapDialog(member, row) : null,
                child: Text(row.isFunded ? 'Change limit' : 'Set a limit'),
              ),
            ],
          ),
          if (row.isFunded) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: row.usedFraction,
                minHeight: 6,
                backgroundColor: accent.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              // In-flight is called out separately because it is money that has
              // not left the wallet yet but is already spoken for — the owner
              // will otherwise read the balance and the cap and find they
              // disagree.
              row.inFlightUsd > 0
                  ? '\$${row.remainingUsd.toStringAsFixed(2)} left · '
                      '\$${row.inFlightUsd.toStringAsFixed(2)} queued, not yet charged'
                  : '\$${row.remainingUsd.toStringAsFixed(2)} left this month',
              style: AppTextStyles.caption.copyWith(color: accent),
            ),
          ],
        ],
      ),
    );
  }

  void _showCapDialog(HouseholdMember member, HouseholdSpendRow row) {
    final monthlyCtl = TextEditingController(
      text: row.monthlyCapUsd > 0 ? row.monthlyCapUsd.toStringAsFixed(2) : '',
    );
    final perTxnCtl = TextEditingController(
      text: row.perTxnCapUsd != null ? row.perTxnCapUsd!.toStringAsFixed(2) : '',
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Spending limit for ${row.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How much of YOUR wallet they may spend on your SIM lines each '
              'calendar month. Set 0 to switch it off — they will go back to '
              'paying with their own wallet.',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: monthlyCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monthly limit (USD)',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: perTxnCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Max per refill (optional)',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final monthly = double.tryParse(monthlyCtl.text.trim()) ?? 0.0;
              final perTxn = perTxnCtl.text.trim().isEmpty
                  ? null
                  : double.tryParse(perTxnCtl.text.trim());

              Navigator.of(dialogContext).pop();
              await HapticHelper.lightTick();

              final result = await ref
                  .read(householdCapControllerProvider.notifier)
                  .setCap(
                    memberRowId: member.id,
                    monthlyCapUsd: monthly,
                    perTxnCapUsd: perTxn,
                  );

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.success
                        ? (monthly > 0
                            ? '${row.displayName} can now spend up to '
                                '\$${monthly.toStringAsFixed(2)} of your wallet a month.'
                            : '${row.displayName} pays with their own wallet again.')
                        : (result.message ?? 'Could not update the limit.'),
                  ),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Received Invites (Invites sent to me) ───────────────────
  Widget _buildReceivedTab(List<HouseholdMember> invitations) {
    final isDark = context.isDarkMode;
    if (invitations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.mail_outline_rounded,
        title: 'No Invitations',
        description:
            'You do not have any pending household invitations at this time.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: invitations.length,
      itemBuilder: (context, index) {
        final invite = invitations[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 14.0),
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCard.withValues(alpha: 0.4)
                : AppColors.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.house_rounded,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invite.ownerName ?? 'Family Account',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: context.onSurfaceColor,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Invited you as a ${invite.role.toUpperCase()}',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        await HapticHelper.mediumImpact();
                        _handleRespond(invite.id, false);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Decline',
                        style: TextStyle(color: context.onSurfaceColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await HapticHelper.mediumImpact();
                        _handleRespond(invite.id, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 3: Joined Households (Households I've joined) ──────────────
  // G6: the member's side. A member cannot read the owner's wallet or ledger
  // — RLS is right about that — so without this banner they would discover
  // their spending limit only by hitting it mid-refill.
  Widget _buildAllowanceBanner() {
    final allowances = ref.watch(myHouseholdAllowancesProvider).value;
    if (allowances == null) return const SizedBox.shrink();

    final funded = allowances.where((a) => a.isFunded).toList(growable: false);
    if (funded.isEmpty) return const SizedBox.shrink();

    return Column(
      children: funded.map((a) {
        final Color accent =
            a.remainingUsd <= 0 ? AppColors.warning : AppColors.success;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 18, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${a.ownerLabel} funds your refills',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: a.usedFraction,
                  minHeight: 6,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                a.remainingUsd <= 0
                    ? 'You have used the whole \$${a.monthlyCapUsd.toStringAsFixed(2)} '
                        'for this month. Refills on their lines will be refused '
                        'until it resets.'
                    : '\$${a.remainingUsd.toStringAsFixed(2)} of '
                        '\$${a.monthlyCapUsd.toStringAsFixed(2)} left this month'
                        '${a.perTxnCapUsd != null ? ' · max \$${a.perTxnCapUsd!.toStringAsFixed(2)} per refill' : ''}',
                style: AppTextStyles.caption.copyWith(color: accent),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildJoinedTab(List<HouseholdMember> memberships) {
    final isDark = context.isDarkMode;
    if (memberships.isEmpty) {
      return _buildEmptyState(
        icon: Icons.vpn_key_outlined,
        title: 'Not Joined in Family Accounts',
        description:
            'You have not joined any family households. Received invitations will appear under the tab.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: memberships.length,
      itemBuilder: (context, index) {
        final membership = memberships[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 14.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCard.withValues(alpha: 0.4)
                : AppColors.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                child: const Icon(
                  Icons.lock_open_rounded,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membership.ownerName ?? 'Shared Household',
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: membership.role == 'manager'
                            ? const Color(0xFFA855F7).withValues(alpha: 0.1)
                            : const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        membership.role == 'manager'
                            ? 'MANAGER (READ/WRITE)'
                            : 'VIEWER (READ-ONLY)',
                        style: TextStyle(
                          color: membership.role == 'manager'
                              ? const Color(0xFFA855F7)
                              : const Color(0xFF3B82F6),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  await HapticHelper.lightTick();
                  _confirmLeave(context, membership);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Invite Dialog ──────────────────────────────────────────────────
  void _showInviteDialog(BuildContext context) {
    final emailController = TextEditingController();
    String selectedRole = 'viewer';
    final isDark = context.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: isDark
                ? BorderSide.none
                : const BorderSide(color: AppColors.lightBorder),
          ),
          title: Text(
            'Invite Family Member',
            style: AppTextStyles.headlineMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter email below to invite them to view or manage your shared SIM lines.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                style: TextStyle(color: context.onSurfaceColor),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : AppColors.lightBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : AppColors.lightBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              Text(
                'Access Permissions',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              // Role selection row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        await HapticHelper.lightTick();
                        setModalState(() => selectedRole = 'viewer');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selectedRole == 'viewer'
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.black.withValues(alpha: 0.02)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedRole == 'viewer'
                                ? const Color(0xFF3B82F6)
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : AppColors.lightBorder),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.visibility_rounded,
                              color: selectedRole == 'viewer'
                                  ? const Color(0xFF3B82F6)
                                  : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Viewer',
                              style: TextStyle(
                                color: context.onSurfaceColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Read-only',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        await HapticHelper.lightTick();
                        setModalState(() => selectedRole = 'manager');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selectedRole == 'manager'
                              ? const Color(0xFFA855F7).withValues(alpha: 0.12)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.black.withValues(alpha: 0.02)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedRole == 'manager'
                                ? const Color(0xFFA855F7)
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : AppColors.lightBorder),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.manage_accounts_rounded,
                              color: selectedRole == 'manager'
                                  ? const Color(0xFFA855F7)
                                  : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Manager',
                              style: TextStyle(
                                color: context.onSurfaceColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Read/Write',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await HapticHelper.lightTick();
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  await HapticHelper.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid email address'),
                    ),
                  );
                  return;
                }
                await HapticHelper.mediumImpact();
                Navigator.pop(context);
                _handleSendInvite(email, selectedRole);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Send Invite',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Operations Trigger Helpers ─────────────────────────────────────
  void _handleSendInvite(String email, String role) async {
    try {
      await ref
          .read(householdControllerProvider.notifier)
          .sendInvite(email, role);
      await HapticHelper.successFeedback();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully sent invitation to $email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
          ),
        );
      }
    }
  }

  void _handleRespond(String inviteId, bool accept) async {
    try {
      await HapticHelper.mediumImpact();
      if (accept) {
        await ref
            .read(householdControllerProvider.notifier)
            .acceptInvite(inviteId);
        await HapticHelper.successFeedback();
      } else {
        await ref
            .read(householdControllerProvider.notifier)
            .declineInvite(inviteId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'Invitation accepted!' : 'Invitation declined',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _confirmRemove(BuildContext context, HouseholdMember member) {
    final isDark = context.isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark
              ? BorderSide.none
              : const BorderSide(color: AppColors.lightBorder),
        ),
        title: Text(
          'Remove Family Member',
          style: TextStyle(color: context.onSurfaceColor),
        ),
        content: Text(
          'Are you sure you want to revoke access/remove ${member.memberEmail} from your household?',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await HapticHelper.lightTick();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await HapticHelper.mediumImpact();
              Navigator.pop(context);
              await ref
                  .read(householdControllerProvider.notifier)
                  .removeMember(member.id);
              await HapticHelper.successFeedback();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmLeave(BuildContext context, HouseholdMember membership) {
    final isDark = context.isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark
              ? BorderSide.none
              : const BorderSide(color: AppColors.lightBorder),
        ),
        title: Text(
          'Leave Household',
          style: TextStyle(color: context.onSurfaceColor),
        ),
        content: Text(
          'Are you sure you want to leave the household shared by ${membership.ownerName ?? 'Family Owner'}? You will lose all access to their shared lines.',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await HapticHelper.lightTick();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await HapticHelper.mediumImpact();
              Navigator.pop(context);
              await ref
                  .read(householdControllerProvider.notifier)
                  .leaveHousehold(membership.id);
              await HapticHelper.successFeedback();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Helper: Empty state ────────────────────────────────────────────
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return EmptyStateView(icon: icon, title: title, description: description);
  }
}
