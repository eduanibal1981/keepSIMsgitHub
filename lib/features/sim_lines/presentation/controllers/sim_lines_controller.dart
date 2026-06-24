import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_activity_log_model.dart';
import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';

part 'sim_lines_controller.g.dart';

@Riverpod(keepAlive: true)
class SimLinesController extends _$SimLinesController {
  @override
  FutureOr<List<SimLine>> build() async {
    final authProfile = ref.watch(authControllerProvider);
    final profileValue = authProfile.valueOrNull;
    if (profileValue == null) {
      return const [];
    }

    final repo = ref.watch(simLinesRepositoryProvider);
    final lines = await repo.getSimLines();

    // Sort deterministically by nickname (if available) then phone number
    // to prevent the list from randomly rearranging when updated.
    lines.sort((a, b) {
      final aName = (a.nickname ?? a.phoneNumber).toLowerCase();
      final bName = (b.nickname ?? b.phoneNumber).toLowerCase();
      return aName.compareTo(bName);
    });

    return lines;
  }

  Future<void> addSimLine({
    required String phoneNumber,
    String? nickname,
    required String avatarIcon,
    String? countryId,
    String? carrierId,
    required String protectionTier,
    String planType = 'free',
    DateTime? planExpiresAt,
    String? carrierRuleId,
  }) async {
    final userId = ref.read(authControllerProvider).valueOrNull?.id;
    if (userId == null)
      throw Exception('Cannot add SIM line: User is not authenticated.');

    final previousList = state.valueOrNull ?? [];
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repo = ref.read(simLinesRepositoryProvider);

      final newLine = SimLine(
        id: '',
        userId: userId,
        phoneNumber: phoneNumber,
        nickname: nickname,
        avatarIcon: avatarIcon,
        countryId: countryId,
        carrierId: carrierId,
        protectionTier: protectionTier,
        planType: planType,
        planExpiresAt: planExpiresAt,
        carrierRuleId: carrierRuleId,
      );

      final added = await repo.addSimLine(newLine);

      // Auto-configure Scheduled Topups
      int frequencyDays = 30;
      final targetRuleId = carrierRuleId ?? added.carrierId;
      if (targetRuleId != null) {
        final rule = await repo.getCarrierRule(targetRuleId);
        if (rule != null) {
          frequencyDays = rule.topupValidityDays;
        }
      }

      final topupNotifier = ref.read(scheduledTopupControllerProvider.notifier);

      // All plans (Free/Basic, Standard, Premium) get Auto-Notify
      int notifyDelay = frequencyDays;
      if (frequencyDays == 90 || frequencyDays == 85) notifyDelay = 85;
      else if (frequencyDays == 30) notifyDelay = 28;
      else if (frequencyDays == 14) notifyDelay = 13;
      
      final notifySchedule = ScheduledTopup(
        id: '',
        simLineId: added.id,
        userId: userId,
        amount: 0.0,
        currency: 'USD',
        frequencyDays: frequencyDays,
        nextExecutionAt: DateTime.now().toUtc().add(Duration(days: notifyDelay)),
        isActive: true,
        status: 'active',
        scheduleType: 'notify',
      );
      await topupNotifier.saveSchedule(notifySchedule);

      // Premium gets Auto-Refill
      if (planType == 'premium') {
        final refillSchedule = ScheduledTopup(
          id: '',
          simLineId: added.id,
          userId: added.userId,
          amount: 0.0,
          currency: 'USD',
          frequencyDays: frequencyDays,
          nextExecutionAt: DateTime.now().toUtc().add(Duration(days: notifyDelay)),
          isActive: true,
          status: 'active',
          scheduleType: 'refill mini',
        );
        await topupNotifier.saveSchedule(refillSchedule);
      }

      return [added, ...previousList];
    });
  }

  Future<void> updateSimLine(SimLine line) async {
    final previousList = state.valueOrNull ?? [];
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repo = ref.read(simLinesRepositoryProvider);
      final updated = await repo.updateSimLine(line);

      final oldLine = previousList.where((l) => l.id == line.id).firstOrNull;
      if (oldLine != null) {
        final wasFree = oldLine.planType == 'free';
        final wasStandard = oldLine.planType == 'standard';
        final isStandard = line.planType == 'standard';
        final isPremium = line.planType == 'premium';

        if ((wasFree && (isStandard || isPremium)) || (wasStandard && isPremium)) {
          int frequencyDays = 90;
          final carrierIdToUse = line.carrierId ?? oldLine.carrierId;
          if (carrierIdToUse != null) {
            final rule = await repo.getCarrierRule(carrierIdToUse);
            if (rule != null) {
              frequencyDays = rule.topupValidityDays;
            }
          }

          final topupNotifier = ref.read(scheduledTopupControllerProvider.notifier);

          // Standard and Premium get Auto-Notify
          int notifyDelay = frequencyDays;
          if (frequencyDays == 90 || frequencyDays == 85) {
            notifyDelay = 85;
          } else if (frequencyDays == 30) {
            notifyDelay = 28;
          } else if (frequencyDays == 14) {
            notifyDelay = 13;
          }

          // 1. Create Notify Schedule if it doesn't exist yet
          final schedules = ref.read(scheduledTopupControllerProvider).valueOrNull ?? [];
          final hasNotifySchedule = schedules.any((s) => s.simLineId == line.id && s.scheduleType == 'notify');
          if (!hasNotifySchedule) {
            final notifySchedule = ScheduledTopup(
              id: '',
              simLineId: line.id,
              userId: line.userId,
              amount: 0.0,
              currency: 'USD',
              frequencyDays: frequencyDays,
              nextExecutionAt: DateTime.now().toUtc().add(Duration(days: notifyDelay)),
              isActive: true,
              status: 'active',
              scheduleType: 'notify',
            );
            await topupNotifier.saveSchedule(notifySchedule);
          }

          // 2. Create Refill Mini Schedule if moving to premium from a non-premium plan
          if (isPremium && oldLine.planType != 'premium') {
            final refillSchedule = ScheduledTopup(
              id: '',
              simLineId: line.id,
              userId: line.userId,
              amount: 0.0,
              currency: 'USD',
              frequencyDays: frequencyDays,
              nextExecutionAt: DateTime.now().toUtc().add(Duration(days: notifyDelay)),
              isActive: true,
              status: 'active',
              scheduleType: 'refill mini',
            );
            await topupNotifier.saveSchedule(refillSchedule);
          }
        }
      }

      return previousList
          .map((item) => item.id == line.id ? updated : item)
          .toList();
    });
  }

  Future<void> deleteSimLine(String id) async {
    final previousList = state.valueOrNull ?? [];
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repo = ref.read(simLinesRepositoryProvider);
      await repo.deleteSimLine(id);

      // Invalidate auto-refill schedules to keep local state synced with Supabase cascade deletes
      ref.invalidate(scheduledTopupControllerProvider);

      return previousList.where((item) => item.id != id).toList();
    });
  }

  Future<void> toggleHomeMode(String simLineId, bool isHome) async {
    try {
      final repo = ref.read(simLinesRepositoryProvider);
      final previousList = state.valueOrNull ?? [];
      final line = previousList.firstWhere((l) => l.id == simLineId);

      SimLine updatedLine = line.copyWith(isHomeMode: isHome);
      if (!isHome) {
        // Returning to abroad mode: treat as recent refill
        updatedLine = updatedLine.copyWith(lastTopupAt: DateTime.now());
      }

      updatedLine = await repo.updateSimLine(updatedLine);

      final schedules =
          ref.read(scheduledTopupControllerProvider).valueOrNull ?? [];
      final lineSchedules = schedules
          .where((s) => s.simLineId == simLineId)
          .toList();

      for (final schedule in lineSchedules) {
        if (isHome) {
          // Pause schedule
          await ref
              .read(scheduledTopupControllerProvider.notifier)
              .toggleActive(schedule.id, false);
        } else {
          // Resume and adjust nextExecutionAt
          final nextDue = DateTime.now().add(
            schedule.frequencyDays == 0
                ? const Duration(hours: 1)
                : Duration(days: schedule.frequencyDays),
          );
          final updatedSchedule = schedule.copyWith(
            isActive: true,
            status: 'active',
            nextExecutionAt: nextDue,
          );

          final topupRepo = ref.read(scheduledTopupRepositoryProvider);
          await topupRepo.updateSchedule(updatedSchedule);
        }
      }
      if (lineSchedules.isNotEmpty && !isHome) {
        ref.invalidate(scheduledTopupControllerProvider);
      }

      state = AsyncData(
        previousList
            .map((item) => item.id == simLineId ? updatedLine : item)
            .toList(),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> deleteActivityLog(String id, String simLineId) async {
    final previousList = state.valueOrNull ?? [];
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repo = ref.read(simLinesRepositoryProvider);
      await repo.deleteLineActivityLog(id);
      ref.invalidate(simLineActivityLogsProvider(simLineId));
      return previousList;
    });
  }

  Future<void> cleanMockLogs(String simLineId) async {
    final previousList = state.valueOrNull ?? [];
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repo = ref.read(simLinesRepositoryProvider);
      await repo.cleanMockLogs(simLineId);
      ref.invalidate(simLineActivityLogsProvider(simLineId));
      ref.invalidate(topupExecutionsForLineProvider(simLineId));

      return previousList;
    });
  }

  Future<void> clearAllActivityLogs(String simLineId) async {
    final previousList = state.valueOrNull ?? [];
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repo = ref.read(simLinesRepositoryProvider);
      await repo.clearAllActivityLogs(simLineId);
      ref.invalidate(simLineActivityLogsProvider(simLineId));
      return previousList;
    });
  }

  Future<void> performManualRefill(SimLine line, double amount) async {
    // 1. Deduct from wallet
    final success = await ref
        .read(walletControllerProvider.notifier)
        .deduct(
          amount,
          description: 'Manual Refill for ${line.nickname ?? line.phoneNumber}',
        );

    final repo = ref.read(simLinesRepositoryProvider);

    if (success) {
      // 2. Update SimLine lastTopupAt
      final updatedLine = line.copyWith(lastTopupAt: DateTime.now());
      await repo.updateSimLine(updatedLine);

      // 3. Record successful execution
      await repo.recordManualTopupExecution(
        simLineId: line.id,
        amount: amount,
        status: 'success',
      );

      // 4. Log Activity
      ref.invalidateSelf();
      ref.invalidate(topupExecutionsForLineProvider(line.id));
      ref.invalidate(simLineActivityLogsProvider(line.id));
    } else {
      // Record failed execution
      await repo.recordManualTopupExecution(
        simLineId: line.id,
        amount: amount,
        status: 'failed',
        failureReason: 'Insufficient wallet balance',
      );

      // Let the walletController state throw/handle the UI, or we can just invalidate
      ref.invalidateSelf();
      ref.invalidate(topupExecutionsForLineProvider(line.id));
      ref.invalidate(simLineActivityLogsProvider(line.id));
    }
  }
}

@riverpod
Future<List<Country>> supportedCountries(SupportedCountriesRef ref) {
  return ref.watch(simLinesRepositoryProvider).getSupportedCountries();
}

@riverpod
Future<List<Carrier>> carriersForCountry(
  CarriersForCountryRef ref,
  String countryId,
) {
  return ref.watch(simLinesRepositoryProvider).getCarriersForCountry(countryId);
}

@riverpod
Future<CarrierRule?> carrierRule(
  CarrierRuleRef ref,
  String carrierId,
) {
  return ref
      .watch(simLinesRepositoryProvider)
      .getCarrierRule(carrierId);
}

@riverpod
FutureOr<List<LineActivityLog>> simLineActivityLogs(
  SimLineActivityLogsRef ref,
  String simLineId,
) {
  return ref.watch(simLinesRepositoryProvider).getLineActivityLogs(simLineId);
}
