/// SIM Shield — Dashboard Controller
///
/// Reactively aggregates metrics and recent timeline logs.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';

import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';

part 'dashboard_controller.g.dart';

/// Aggregated dashboard state structure.
class DashboardState {
  final int totalLines;
  final double walletBalance;
  final int nextTopUpDays;
  final int nextTopUpTotalDays;
  final int overallHealthScore;
  final List<DashboardActivity> recentActivities;
  final String? lastChargeDate;
  final String? lastChargePhone;
  final String? nextTopUpId;
  final String? nextTopUpPhone;
  final String? nextTopUpNickname;
  final DateTime? nextTopUpDate;
  final String? nextTopUpStatus;

  const DashboardState({
    required this.totalLines,
    required this.walletBalance,
    required this.nextTopUpDays,
    required this.nextTopUpTotalDays,
    required this.overallHealthScore,
    required this.recentActivities,
    this.lastChargeDate,
    this.lastChargePhone,
    this.nextTopUpId,
    this.nextTopUpPhone,
    this.nextTopUpNickname,
    this.nextTopUpDate,
    this.nextTopUpStatus,
  });
}

/// A timeline activity item displayed on the dashboard feed.
class DashboardActivity {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'topup', 'deposit', 'alert', 'info'
  final String timeAgo;
  final bool isSuccess;

  const DashboardActivity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.timeAgo,
    required this.isSuccess,
  });
}

/// Managing aggregated dashboard state.
@Riverpod(keepAlive: true)
class DashboardController extends _$DashboardController {
  @override
  FutureOr<DashboardState> build() async {
    // Reactively watch auth status and await resolution
    final profile = await ref.watch(authControllerProvider.future);
    if (profile == null) {
      throw Exception('User is not authenticated');
    }

    // Await both sub-providers to resolve, ensuring we remain in a true AsyncLoading state in the UI
    final walletState = await ref.watch(walletControllerProvider.future);
    final simLines = await ref.watch(simLinesControllerProvider.future);
    final schedules = await ref.watch(scheduledTopupControllerProvider.future);

    return _fetchDashboardData(walletState, simLines, schedules, profile);
  }

  DashboardState _loadingState() {
    return const DashboardState(
      totalLines: 0,
      walletBalance: 0.0,
      nextTopUpDays: 0,
      nextTopUpTotalDays: 30,
      overallHealthScore: 100,
      recentActivities: [],
      nextTopUpId: null,
      nextTopUpPhone: null,
      nextTopUpNickname: null,
      nextTopUpDate: null,
      nextTopUpStatus: null,
    );
  }

  /// Aggregates real wallet and sim line state values.
  DashboardState _fetchDashboardData(
    WalletState walletState,
    List<SimLine> simLines,
    List<ScheduledTopup> schedules,
    UserProfile? profile,
  ) {
    final balance = walletState.wallet.balance;
    final transactions = walletState.transactions;

    // Convert transactions to recent activities
    final recentActivities = <DashboardActivity>[];
    for (final tx in transactions.take(4)) {
      final isDeposit = tx.type == 'deposit' || tx.type == 'auto_fund';
      final isReferral = tx.type == 'referral' || tx.type == 'referral_credit';
      final isRefund = tx.type == 'refund';

      String typeStr = 'topup';
      if (isDeposit || isReferral || isRefund) {
        typeStr = 'deposit';
      }

      // Calculate timeAgo
      String timeAgoStr = 'Just now';
      if (tx.createdAt != null) {
        final diff = DateTime.now().difference(tx.createdAt!);
        if (diff.inMinutes < 60) {
          timeAgoStr = '${diff.inMinutes} mins ago';
        } else if (diff.inHours < 24) {
          timeAgoStr = '${diff.inHours} hours ago';
        } else {
          timeAgoStr = '${diff.inDays} days ago';
        }
      }

      recentActivities.add(
        DashboardActivity(
          id: tx.id,
          title:
              tx.description ?? (isDeposit ? 'Deposit Funds' : 'Line Renewal'),
          subtitle: isDeposit
              ? '+\$${tx.amount.toStringAsFixed(2)} USD added'
              : '-\$${tx.amount.toStringAsFixed(2)} USD',
          type: typeStr,
          timeAgo: timeAgoStr,
          isSuccess: true,
        ),
      );
    }

    // 1. Calculate Active Lines (including shared ones)
    final totalLines = simLines.where((l) => l.status == 'active').length;

    // Filter to only consider owned lines for last charged and nearest top-up calculations
    final currentUserId = profile?.id;
    final ownedLines = simLines
        .where((l) => l.userId == currentUserId)
        .toList();

    // 2. Find last auto-charged line
    SimLine? lastChargedLine;
    for (final line in ownedLines) {
      if (line.lastTopupAt != null) {
        if (lastChargedLine == null ||
            line.lastTopupAt!.isAfter(lastChargedLine.lastTopupAt!)) {
          lastChargedLine = line;
        }
      }
    }

    String? lastChargeDate;
    String? lastChargePhone;
    if (lastChargedLine != null) {
      final date = lastChargedLine.lastTopupAt!;
      lastChargeDate = '${date.day}/${date.month}/${date.year}';
      lastChargePhone = lastChargedLine.phoneNumber;
    }

    // 3. Calculate next top up days and find nearest line
    int nextTopUpDays = 0; // Show 0 in circular progress if none
    int nextTopUpTotalDays = 30;
    bool foundNextDue = false;
    SimLine? nextDueLine;
    DateTime? nextDueLineDate;

    bool isPremiumUser =
        profile?.subscriptionTier == 'premium' || profile?.isPowerUser == true;

    for (final line in ownedLines) {
      final lineSchedules = schedules
          .where(
            (s) => s.simLineId == line.id && s.isActive && s.status == 'active',
          )
          .toList();
      final refillSchedule = lineSchedules
          .where((s) => s.scheduleType.startsWith('refill'))
          .firstOrNull;
      final notifySchedule = lineSchedules
          .where((s) => s.scheduleType == 'notify')
          .firstOrNull;

      bool isPremiumLine =
          line.protectionTier.toLowerCase() == 'premium' || isPremiumUser;

      final DateTime? targetDate = isPremiumLine
          ? refillSchedule?.nextExecutionAt
          : notifySchedule?.nextExecutionAt;

      if (targetDate != null) {
        final diff = targetDate.difference(DateTime.now()).inDays;
        if (diff >= 0 && (!foundNextDue || diff < nextTopUpDays)) {
          nextTopUpDays = diff;
          nextDueLine = line;
          nextDueLineDate = targetDate;
          final schedule = isPremiumLine ? refillSchedule : notifySchedule;
          if (schedule != null && schedule.frequencyDays >= 0) {
            nextTopUpTotalDays = schedule.frequencyDays;
          } else {
            nextTopUpTotalDays = 30;
          }
          foundNextDue = true;
        }
      }
    }

    return DashboardState(
      totalLines: totalLines,
      walletBalance: balance,
      nextTopUpDays: nextTopUpDays,
      nextTopUpTotalDays: nextTopUpTotalDays,
      overallHealthScore: 96,
      recentActivities: recentActivities,
      lastChargeDate: lastChargeDate,
      lastChargePhone: lastChargePhone,
      nextTopUpId: nextDueLine?.id,
      nextTopUpPhone: nextDueLine?.phoneNumber,
      nextTopUpNickname: nextDueLine?.nickname,
      nextTopUpDate: nextDueLineDate,
      nextTopUpStatus: nextDueLine?.status,
    );
  }

  /// Triggers a visual, manual refresh of the home aggregates
  Future<void> refreshDashboard() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      ref.invalidate(walletControllerProvider);
      ref.invalidate(simLinesControllerProvider);
      ref.invalidate(scheduledTopupControllerProvider);
      final profile = await ref.read(authControllerProvider.future);
      final walletState = await ref.read(walletControllerProvider.future);
      final simLines = await ref.read(simLinesControllerProvider.future);
      final schedules = await ref.read(scheduledTopupControllerProvider.future);
      return _fetchDashboardData(walletState, simLines, schedules, profile);
    });
  }
}
