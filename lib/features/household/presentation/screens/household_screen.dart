import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/widgets/shimmer_loading.dart';
import 'package:keep_sims/core/widgets/empty_state.dart';
import 'package:keep_sims/core/widgets/error_state.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import '../controllers/household_controller.dart';
import '../providers/household_spend_provider.dart';
import '../../data/models/household_member_model.dart';
import '../../data/models/household_spend_model.dart';
import '../../domain/repositories/household_repository.dart';

const _kIndigo = Color(0xFF6366F1);
const _kBlue = Color(0xFF3B82F6);
const _kPurple = Color(0xFFA855F7);
const _kAmber = Color(0xFFF59E0B);
const _kGreen = Color(0xFF10B981);

class HouseholdScreen extends ConsumerStatefulWidget {
  const HouseholdScreen({super.key});

  @override
  ConsumerState<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends ConsumerState<HouseholdScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Guards every mutation. Without it a double-tap on Accept fires the RPC
  /// twice; the second call returns NOT_FOUND and the user sees a failure
  /// message for something that actually worked.
  bool _busy = false;

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

  AppLocalizations get _l => AppLocalizations.of(context)!;

  String _money(double v) => '\$${v.toStringAsFixed(2)}';

  /// Runs a mutation and reports the outcome.
  ///
  /// The repository returns an envelope rather than throwing, so a refusal
  /// carries a sentence from the server. That matters most for the cases the
  /// old code reported as success — a member's `leave` used to delete zero rows
  /// and still show "left the household".
  Future<void> _run(
    Future<HouseholdActionResult> Function() action, {
    required String successMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await action();
      if (!mounted) return;
      if (result.success) {
        await HapticHelper.successFeedback();
      } else {
        await HapticHelper.mediumImpact();
      }
      if (!mounted) return;
      _toast(
        result.success
            ? successMessage
            : (result.message ?? _l.householdActionFailed),
        isError: !result.success,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.warning : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(householdControllerProvider);
    final isDark = context.isDarkMode;
    final pendingCount = stateAsync.value?.invitations.length ?? 0;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _l.householdTitle,
          style: AppTextStyles.headlineMedium.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _kIndigo,
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
          tabs: [
            Tab(text: _l.householdTabMyFamily),
            // An invitation the invitee never notices is the same as no
            // invitation, so the count rides on the tab itself.
            Tab(
              child: _TabLabelWithBadge(
                label: _l.householdTabReceived,
                count: pendingCount,
              ),
            ),
            Tab(text: _l.householdTabJoined),
          ],
        ),
      ),
      body: stateAsync.when(
        skipLoadingOnRefresh: true,
        data: (state) => TabBarView(
          controller: _tabController,
          children: [
            _refreshable(_buildMyFamilyTab(state.members)),
            _refreshable(_buildReceivedTab(state.invitations)),
            _refreshable(
              ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildAllowanceBanner(),
                  _buildJoinedList(state.memberships),
                ],
              ),
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
        onPressed: _busy
            ? null
            : () async {
                await HapticHelper.lightTick();
                if (!mounted) return;
                _showInviteDialog();
              },
        backgroundColor: _busy ? Colors.grey : _kIndigo,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: Text(
          _l.householdInviteMember,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _refreshable(Widget child) => RefreshIndicator(
    onRefresh: () => ref.read(householdControllerProvider.notifier).refresh(),
    child: child,
  );

  // ── Tab 1: My Family (people I invited) ────────────────────────────
  Widget _buildMyFamilyTab(List<HouseholdMember> members) {
    if (members.isEmpty) {
      return _scrollableEmpty(
        EmptyStateView(
          icon: Icons.people_outline_rounded,
          title: _l.householdEmptyTitle,
          description: _l.householdEmptyDesc,
          buttonText: _l.householdInviteMember,
          onButtonPressed: _busy ? null : () => _showInviteDialog(),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: members.length,
      itemBuilder: (context, index) => _memberCard(members[index]),
    );
  }

  Widget _memberCard(HouseholdMember member) {
    final isDark = context.isDarkMode;
    // A declined invite stays in the table — the owner has to be told that,
    // otherwise it reads as an active member who simply never appears.
    final isPending = member.inviteStatus == 'pending';
    final isDeclined = member.inviteStatus == 'declined';
    final isMuted = isPending || isDeclined;
    final name = member.memberName?.trim().isNotEmpty == true
        ? member.memberName!
        : member.memberEmail;

    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      padding: const EdgeInsets.all(16.0),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isMuted
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04))
                    : _kIndigo.withValues(alpha: 0.1),
                child: Text(
                  name.characters.first.toUpperCase(),
                  style: TextStyle(
                    color: isMuted
                        ? (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                        : _kIndigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (member.memberName?.trim().isNotEmpty == true) ...[
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _pill(
                          isPending
                              ? _l.householdStatusPending
                              : (isDeclined
                                    ? _l.householdStatusDeclined
                                    : _l.householdStatusAccepted),
                          isPending
                              ? _kAmber
                              : (isDeclined ? Colors.redAccent : _kGreen),
                        ),
                        _pill(
                          member.role == 'manager'
                              ? _l.householdRoleManager
                              : _l.householdRoleViewer,
                          member.role == 'manager' ? _kPurple : _kBlue,
                        ),
                      ],
                    ),
                    if (isMuted) ...[
                      const SizedBox(height: 6),
                      Text(
                        isPending
                            ? _l.householdPendingHint
                            : _l.householdDeclinedHint,
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: _l.householdRemoveTitle,
                icon: const Icon(
                  Icons.person_remove_outlined,
                  color: Colors.redAccent,
                ),
                onPressed: _busy
                    ? null
                    : () async {
                        await HapticHelper.lightTick();
                        if (!mounted) return;
                        _confirmRemove(member, name);
                      },
              ),
            ],
          ),
          // G6: the wallet-sharing half of the row.
          _buildSpendFooter(member),
        ],
      ),
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
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.lightBorder,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  row.isFunded
                      ? _l.householdSpendsMyWallet(
                          _money(row.spentMtdUsd),
                          _money(row.monthlyCapUsd),
                        )
                      : (canFund
                            ? _l.householdPaysOwnWallet
                            : _l.householdManagersOnly),
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
                onPressed: canFund && !_busy
                    ? () => _showCapDialog(member, row)
                    : null,
                child: Text(
                  row.isFunded ? _l.householdChangeLimit : _l.householdSetLimit,
                ),
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
                  ? _l.householdRemainingQueued(
                      _money(row.remainingUsd),
                      _money(row.inFlightUsd),
                    )
                  : _l.householdRemainingThisMonth(_money(row.remainingUsd)),
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
        title: Text(_l.householdSpendingLimitFor(row.displayName)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _l.householdSpendingLimitDesc,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.onSurfaceColor.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: monthlyCtl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _l.householdMonthlyLimit,
                  prefixText: '\$ ',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: perTxnCtl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _l.householdMaxPerRefill,
                  prefixText: '\$ ',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_l.cancel),
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
              _toast(
                result.success
                    ? (monthly > 0
                          ? _l.householdLimitSaved(
                              row.displayName,
                              _money(monthly),
                            )
                          : _l.householdLimitCleared(row.displayName))
                    : (result.message ?? _l.householdLimitFailed),
                isError: !result.success,
              );
            },
            child: Text(_l.householdSave),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Invitations sent to me ──────────────────────────────────
  Widget _buildReceivedTab(List<HouseholdMember> invitations) {
    final isDark = context.isDarkMode;
    if (invitations.isEmpty) {
      return _scrollableEmpty(
        EmptyStateView(
          icon: Icons.mail_outline_rounded,
          title: _l.householdNoInvitesTitle,
          description: _l.householdNoInvitesDesc,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: invitations.length,
      itemBuilder: (context, index) {
        final invite = invitations[index];
        final isManager = invite.role == 'manager';

        return Container(
          margin: const EdgeInsets.only(bottom: 14.0),
          padding: const EdgeInsets.all(18.0),
          decoration: _cardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _kBlue.withValues(alpha: 0.1),
                    child: const Icon(Icons.house_rounded, color: _kBlue),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invite.ownerName?.trim().isNotEmpty == true
                              ? invite.ownerName!
                              : _l.householdFamilyAccount,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: context.onSurfaceColor,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isManager
                              ? _l.householdInvitedYouManager
                              : _l.householdInvitedYouViewer,
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
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => ref
                                  .read(householdControllerProvider.notifier)
                                  .declineInvite(invite.id),
                              successMessage: _l.householdInviteDeclined,
                            ),
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
                        _l.householdDecline,
                        style: TextStyle(color: context.onSurfaceColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => ref
                                  .read(householdControllerProvider.notifier)
                                  .acceptInvite(invite.id),
                              successMessage: _l.householdInviteAccepted,
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kIndigo,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _l.householdAccept,
                        style: const TextStyle(
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

  // ── Tab 3: Households I have joined ────────────────────────────────
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
        final Color accent = a.remainingUsd <= 0
            ? AppColors.warning
            : AppColors.success;
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
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _l.householdOwnerFunds(a.ownerLabel),
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
                    ? _l.householdAllowanceExhausted(_money(a.monthlyCapUsd))
                    : _l.householdAllowanceRemaining(
                            _money(a.remainingUsd),
                            _money(a.monthlyCapUsd),
                          ) +
                          (a.perTxnCapUsd != null
                              ? _l.householdAllowancePerTxn(
                                  _money(a.perTxnCapUsd!),
                                )
                              : ''),
                style: AppTextStyles.caption.copyWith(color: accent),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildJoinedList(List<HouseholdMember> memberships) {
    final isDark = context.isDarkMode;
    if (memberships.isEmpty) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: EmptyStateView(
          icon: Icons.vpn_key_outlined,
          title: _l.householdNotJoinedTitle,
          description: _l.householdNotJoinedDesc,
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: memberships.length,
      itemBuilder: (context, index) {
        final membership = memberships[index];
        final ownerLabel = membership.ownerName?.trim().isNotEmpty == true
            ? membership.ownerName!
            : _l.householdSharedHousehold;

        return Container(
          margin: const EdgeInsets.only(bottom: 14.0),
          padding: const EdgeInsets.all(16.0),
          decoration: _cardDecoration(isDark),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _kGreen.withValues(alpha: 0.1),
                child: const Icon(Icons.lock_open_rounded, color: _kGreen),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ownerLabel,
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _pill(
                      membership.role == 'manager'
                          ? _l.householdRoleManagerFull
                          : _l.householdRoleViewerFull,
                      membership.role == 'manager' ? _kPurple : _kBlue,
                      fontSize: 9,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await HapticHelper.lightTick();
                        if (!mounted) return;
                        _confirmLeave(membership, ownerLabel);
                      },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(_l.householdLeave),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Invite dialog ──────────────────────────────────────────────────
  void _showInviteDialog() {
    final emailController = TextEditingController();
    String selectedRole = 'viewer';
    final isDark = context.isDarkMode;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setModalState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: isDark
                ? BorderSide.none
                : const BorderSide(color: AppColors.lightBorder),
          ),
          title: Text(
            _l.householdInviteTitle,
            style: AppTextStyles.headlineMedium.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _l.householdInviteDesc,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  autofocus: true,
                  style: TextStyle(color: context.onSurfaceColor),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: InputDecoration(
                    labelText: _l.householdEmailLabel,
                    labelStyle: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    border: _inviteBorder(isDark),
                    enabledBorder: _inviteBorder(isDark),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _kIndigo),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _l.householdAccessLevel,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _roleCard(
                        selected: selectedRole == 'viewer',
                        color: _kBlue,
                        icon: Icons.visibility_rounded,
                        title: _l.householdRoleViewer,
                        hint: _l.householdRoleViewerHint,
                        onTap: () async {
                          await HapticHelper.lightTick();
                          setModalState(() => selectedRole = 'viewer');
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _roleCard(
                        selected: selectedRole == 'manager',
                        color: _kPurple,
                        icon: Icons.manage_accounts_rounded,
                        title: _l.householdRoleManager,
                        hint: _l.householdRoleManagerHint,
                        onTap: () async {
                          await HapticHelper.lightTick();
                          setModalState(() => selectedRole = 'manager');
                        },
                      ),
                    ),
                  ],
                ),
                // Handing someone the manager role is the decision with money
                // attached, so the consequence is stated at the moment of choice
                // rather than left in the spend-limit screen they may never open.
                if (selectedRole == 'manager') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kPurple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: _kPurple,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _l.householdManagerWarning,
                            style: AppTextStyles.caption.copyWith(
                              color: context.onSurfaceColor.withValues(
                                alpha: 0.8,
                              ),
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
          actions: [
            TextButton(
              onPressed: () async {
                await HapticHelper.lightTick();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(
                _l.cancel,
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
                  if (!mounted) return;
                  _toast(_l.householdInvalidEmail, isError: true);
                  return;
                }
                await HapticHelper.mediumImpact();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (!mounted) return;
                await _sendInvite(email, selectedRole);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kIndigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _l.householdSendInvite,
                style: const TextStyle(
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

  /// Invite has its own runner because the success copy depends on whether the
  /// invitee already has an account: with one they get a notification now,
  /// without one nothing visibly happens until they register, and an owner who
  /// is not told that will assume the invite failed.
  Future<void> _sendInvite(String email, String role) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(householdControllerProvider.notifier)
          .sendInvite(email, role);
      if (!mounted) return;
      if (result.success) {
        await HapticHelper.successFeedback();
      } else {
        await HapticHelper.mediumImpact();
      }
      if (!mounted) return;
      _toast(
        result.success
            ? _l.householdInviteSent(email)
            : (result.message ?? _l.householdActionFailed),
        isError: !result.success,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _confirmRemove(HouseholdMember member, String name) {
    _confirmDestructive(
      title: _l.householdRemoveTitle,
      body: _l.householdRemoveConfirm(name),
      confirmLabel: _l.remove,
      onConfirm: () => _run(
        () => ref
            .read(householdControllerProvider.notifier)
            .removeMember(member.id),
        successMessage: _l.householdRemoved(name),
      ),
    );
  }

  void _confirmLeave(HouseholdMember membership, String ownerLabel) {
    _confirmDestructive(
      title: _l.householdLeaveTitle,
      body: _l.householdLeaveConfirm(ownerLabel),
      confirmLabel: _l.householdLeave,
      onConfirm: () => _run(
        () => ref
            .read(householdControllerProvider.notifier)
            .leaveHousehold(membership.id),
        successMessage: _l.householdLeft,
      ),
    );
  }

  void _confirmDestructive({
    required String title,
    required String body,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
  }) {
    final isDark = context.isDarkMode;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark
              ? BorderSide.none
              : const BorderSide(color: AppColors.lightBorder),
        ),
        title: Text(title, style: TextStyle(color: context.onSurfaceColor)),
        content: Text(
          body,
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
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(
              _l.cancel,
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await HapticHelper.mediumImpact();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              await onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(
              confirmLabel,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Small shared pieces ────────────────────────────────────────────
  BoxDecoration _cardDecoration(bool isDark) => BoxDecoration(
    color: isDark ? AppColors.darkCard.withValues(alpha: 0.4) : AppColors.lightCard,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.lightBorder,
      width: 1.0,
    ),
  );

  OutlineInputBorder _inviteBorder(bool isDark) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(
      color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lightBorder,
    ),
  );

  Widget _pill(String text, Color color, {double fontSize = 10}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _roleCard({
    required bool selected,
    required Color color,
    required IconData icon,
    required String title,
    required String hint,
    required VoidCallback onTap,
  }) {
    final isDark = context.isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color
                : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppColors.lightBorder),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected
                  ? color
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.onSurfaceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              textAlign: TextAlign.center,
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
    );
  }

  /// Empty states have to stay scrollable or pull-to-refresh dies exactly when
  /// the user most wants it — an empty Invitations tab is the screen people
  /// tug at while waiting for an invite to land.
  Widget _scrollableEmpty(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: child,
      ),
    ),
  );
}

class _TabLabelWithBadge extends StatelessWidget {
  const _TabLabelWithBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: const BoxDecoration(
              color: _kIndigo,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            alignment: Alignment.center,
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
