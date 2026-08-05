import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_self_service_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_activity_log_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/payment_method_model.dart';
import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/notifications/data/repositories/notifications_repository_impl.dart';

part 'sim_lines_controller.g.dart';

@Riverpod(keepAlive: true)
class SimLinesController extends _$SimLinesController {
  @override
  FutureOr<List<SimLine>> build() async {
    final authProfile = ref.watch(authControllerProvider);
    final profileValue = authProfile.value;
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
    final userId = ref.read(authControllerProvider).value?.id;
    if (userId == null) {
      throw Exception('Cannot add SIM line: User is not authenticated.');
    }

    final previousList = state.value ?? [];
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

      // A paid line must exist on the server before anyone is told it is
      // protected. When the device reads as offline the repository silently
      // queues the row and hands back an `offline_…` placeholder — for a free
      // line that is the point, but for a paid one it means the fee was just
      // debited and nothing was created, with no error anywhere to show for it.
      // Failing here keeps the plan-fee reference unconsumed, so the retry
      // replays it rather than billing a second time.
      if (planType != 'free' && added.id.startsWith('offline_')) {
        throw Exception(
          'This line could not be saved because the device is offline. '
          'Your payment is safe and will not be charged again — reconnect and try once more.',
        );
      }

      // Auto-configure Scheduled Topups
      int frequencyDays = 30;
      double topupAmount = 0.0;
      String? offerId;
      int? offerValue;
      if (carrierRuleId != null) {
        final rule = await repo.getCarrierRuleById(carrierRuleId);
        if (rule != null) {
          frequencyDays = rule.refillIntervalDays;
          topupAmount = rule.minimumTopupAmount;
          offerId = rule.offerId;
          offerValue = rule.offerValue;
          print(
            '[addSimLine] Found rule by ID: $carrierRuleId. offerId: $offerId, offerValue: $offerValue, validity: $frequencyDays, amount: $topupAmount',
          );
        } else {
          print('[addSimLine] Rule NOT found by ID: $carrierRuleId');
        }
      } else if (added.carrierId != null) {
        final rule = await repo.getCarrierRule(added.carrierId!);
        if (rule != null) {
          frequencyDays = rule.refillIntervalDays;
          topupAmount = rule.minimumTopupAmount;
          offerId = rule.offerId;
          offerValue = rule.offerValue;
          print(
            '[addSimLine] Found rule by Carrier ID: ${added.carrierId}. offerId: $offerId, offerValue: $offerValue, validity: $frequencyDays, amount: $topupAmount',
          );
        } else {
          print(
            '[addSimLine] Rule NOT found by Carrier ID: ${added.carrierId}',
          );
        }
      }

      final topupNotifier = ref.read(scheduledTopupControllerProvider.notifier);

      // All plans (Free/Basic, Standard, Premium) get Auto-Notify.
      //
      // No safety re-adjustment here. `frequencyDays` is now
      // CarrierRule.refillIntervalDays, which has already had the margin taken
      // out of the carrier's deactivation window. The 90→85 / 30→28 / 14→13
      // mapping that used to sit here belongs to the *chip labels* a user picks
      // in the schedule sheet, where the number means "the carrier's window".
      // Applying it to an already-adjusted interval subtracts the margin twice
      // and desynchronises this schedule from the pre-paid executions
      // queue_premium_refill_executions lays down at the un-remapped interval.
      final notifyDelay = frequencyDays;

      final nextExecTime = DateTime.now().toUtc().add(
        Duration(days: notifyDelay),
      );

      final notifySchedule = ScheduledTopup(
        id: '',
        simLineId: added.id,
        userId: userId,
        amount: topupAmount,
        currency: 'USD',
        frequencyDays: frequencyDays,
        nextExecutionAt: nextExecTime,
        isActive: true,
        status: 'active',
        scheduleType: 'notify',
      );
      await topupNotifier.saveSchedule(notifySchedule);

      // Premium gets Auto-Refill scheduled directly in topup_executions
      if (planType == 'premium') {
        final refillSchedule = ScheduledTopup(
          id: '',
          simLineId: added.id,
          userId: userId,
          amount: topupAmount,
          currency: 'USD',
          frequencyDays: frequencyDays,
          nextExecutionAt: DateTime.now().toUtc().add(
            Duration(days: notifyDelay),
          ),
          isActive: true,
          status: 'active',
          scheduleType: 'refill_mini',
          offerId: offerId,
          offerValue: offerValue,
        );
        final result = await topupNotifier.saveSchedule(refillSchedule);

        // C3b-2: the plan year's mini refills are queued and priced
        // server-side from carrier_rules in one call.
        if (result is Success<ScheduledTopup> && planExpiresAt != null) {
          await repo.queuePremiumRefillExecutions(
            simLineId: added.id,
            scheduledTopupId: result.data.id,
            planExpiresAt: planExpiresAt,
          );
        }
      }

      // Send welcome notification
      try {
        final notificationsRepo = ref.read(notificationsRepositoryProvider);
        await notificationsRepo.sendNotification(
          category: 'system',
          title: 'Welcome to KeepSIMs',
          body:
              'Your line ${added.phoneNumber} has been successfully added! We will remind you every $frequencyDays days when it is time to recharge.',
          simLineId: added.id,
        );
      } catch (e) {
        print('[addSimLine] Failed to send welcome notification: $e');
      }

      return [added, ...previousList];
    });
  }

  Future<void> updateSimLine(SimLine line) async {
    final previousList = state.value ?? [];
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

        if ((wasFree && (isStandard || isPremium)) ||
            (wasStandard && isPremium)) {
          int frequencyDays = 90;
          double topupAmount = 0.0;
          String? offerId;
          int? offerValue;

          final ruleIdToUse = line.carrierRuleId ?? oldLine.carrierRuleId;
          if (ruleIdToUse != null) {
            final rule = await repo.getCarrierRuleById(ruleIdToUse);
            if (rule != null) {
              frequencyDays = rule.refillIntervalDays;
              topupAmount = rule.minimumTopupAmount;
              offerId = rule.offerId;
              offerValue = rule.offerValue;
              print(
                '[updateSimLine] Found rule by ID: $ruleIdToUse. offerId: $offerId, offerValue: $offerValue, validity: $frequencyDays, amount: $topupAmount',
              );
            } else {
              print('[updateSimLine] Rule NOT found by ID: $ruleIdToUse');
            }
          } else {
            final carrierIdToUse = line.carrierId ?? oldLine.carrierId;
            if (carrierIdToUse != null) {
              final rule = await repo.getCarrierRule(carrierIdToUse);
              if (rule != null) {
                frequencyDays = rule.refillIntervalDays;
                topupAmount = rule.minimumTopupAmount;
                offerId = rule.offerId;
                offerValue = rule.offerValue;
                print(
                  '[updateSimLine] Found rule by Carrier ID: $carrierIdToUse. offerId: $offerId, offerValue: $offerValue, validity: $frequencyDays, amount: $topupAmount',
                );
              } else {
                print(
                  '[updateSimLine] Rule NOT found by Carrier ID: $carrierIdToUse',
                );
              }
            }
          }

          final topupNotifier = ref.read(
            scheduledTopupControllerProvider.notifier,
          );

          // Standard and Premium get Auto-Notify. See addSimLine: no safety
          // re-adjustment, because refillIntervalDays already carries it.
          final notifyDelay = frequencyDays;

          final nextExecTime = DateTime.now().toUtc().add(
            Duration(days: notifyDelay),
          );

          // 1. Create Notify Schedule if it doesn't exist yet
          final schedules =
              ref.read(scheduledTopupControllerProvider).value ?? [];
          final hasNotifySchedule = schedules.any(
            (s) => s.simLineId == line.id && s.scheduleType == 'notify',
          );
          if (!hasNotifySchedule) {
            final notifySchedule = ScheduledTopup(
              id: '',
              simLineId: line.id,
              userId: line.userId,
              amount: topupAmount,
              currency: 'USD',
              frequencyDays: frequencyDays,
              nextExecutionAt: nextExecTime,
              isActive: true,
              status: 'active',
              scheduleType: 'notify',
            );
            await topupNotifier.saveSchedule(notifySchedule);
          }

          // 2. Create Refill Mini Schedule directly in topup_executions if moving to premium
          if (isPremium && oldLine.planType != 'premium') {
            final refillSchedule = ScheduledTopup(
              id: '',
              simLineId: line.id,
              userId: line.userId,
              amount: topupAmount,
              currency: 'USD',
              frequencyDays: frequencyDays,
              nextExecutionAt: DateTime.now().toUtc().add(
                Duration(days: notifyDelay),
              ),
              isActive: true,
              status: 'active',
              scheduleType: 'refill_mini',
              offerId: offerId,
              offerValue: offerValue,
            );
            final result = await topupNotifier.saveSchedule(refillSchedule);

            // C3b-2: queued and priced server-side from carrier_rules.
            if (result is Success<ScheduledTopup>) {
              await repo.queuePremiumRefillExecutions(
                simLineId: line.id,
                scheduledTopupId: result.data.id,
                planExpiresAt: line.planExpiresAt ??
                    DateTime.now().toUtc().add(const Duration(days: 365)),
              );
            }
          }
        }
      }

      return previousList
          .map((item) => item.id == line.id ? updated : item)
          .toList();
    });
  }

  Future<void> deleteSimLine(String id) async {
    final previousList = state.value ?? [];
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
      final previousList = state.value ?? [];
      final line = previousList.firstWhere((l) => l.id == simLineId);

      // Home mode is a location fact; pausing protection is a separate intent
      // (B5). Lines flagged requiresProtectionAtHome keep their schedules
      // running while home — e.g. a resident's dormant second SIM.
      final bool pauseProtection = isHome && !line.requiresProtectionAtHome;

      SimLine updatedLine = line.copyWith(
        isHomeMode: isHome,
        protectionPaused: pauseProtection,
      );
      if (!isHome) {
        // Returning to abroad mode: treat as recent refill
        updatedLine = updatedLine.copyWith(lastTopupAt: DateTime.now());
      }

      updatedLine = await repo.updateSimLine(updatedLine);

      await applyProtectionPause(
        simLineId,
        wasPaused: line.protectionPaused,
        pauseNow: pauseProtection,
      );

      state = AsyncData(
        previousList
            .map((item) => item.id == simLineId ? updatedLine : item)
            .toList(),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Marks a line as needing protection even while the user is home.
  /// If the line is currently in home mode, its protection pause is
  /// recomputed immediately (schedules resume or pause accordingly).
  Future<void> setRequiresProtectionAtHome(
    String simLineId,
    bool required,
  ) async {
    try {
      final repo = ref.read(simLinesRepositoryProvider);
      final previousList = state.value ?? [];
      final line = previousList.firstWhere((l) => l.id == simLineId);

      final bool pauseProtection = line.isHomeMode && !required;

      SimLine updatedLine = line.copyWith(
        requiresProtectionAtHome: required,
        protectionPaused: pauseProtection,
      );
      updatedLine = await repo.updateSimLine(updatedLine);

      await applyProtectionPause(
        simLineId,
        wasPaused: line.protectionPaused,
        pauseNow: pauseProtection,
      );

      state = AsyncData(
        previousList
            .map((item) => item.id == simLineId ? updatedLine : item)
            .toList(),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Freezes or unfreezes a SIM line, updating sim_lines.status, protection_paused,
  /// AND toggling scheduled_topups.is_active to ensure refill workers do not debit
  /// paused lines (fixes cosmetic freeze - C8).
  Future<void> freezeLine(String simLineId, bool freeze) async {
    try {
      final repo = ref.read(simLinesRepositoryProvider);
      final previousList = state.value ?? [];
      final line = previousList.firstWhere((l) => l.id == simLineId);

      final newStatus = freeze ? 'paused' : 'active';
      SimLine updatedLine = line.copyWith(
        status: newStatus,
        protectionPaused: freeze,
      );
      updatedLine = await repo.updateSimLine(updatedLine);

      await applyProtectionPause(
        simLineId,
        wasPaused: line.protectionPaused,
        pauseNow: freeze,
        force: true,
      );

      state = AsyncData(
        previousList
            .map((item) => item.id == simLineId ? updatedLine : item)
            .toList(),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Pauses or resumes the line's refill schedules when the protection pause
  /// state changes (or when forced by freeze/unfreeze).
  Future<void> applyProtectionPause(
    String simLineId, {
    required bool wasPaused,
    required bool pauseNow,
    bool force = false,
  }) async {
    if (!force && wasPaused == pauseNow) return;

    final schedules = ref.read(scheduledTopupControllerProvider).value ?? [];
    final lineSchedules = schedules
        .where((s) => s.simLineId == simLineId)
        .toList();

    for (final schedule in lineSchedules) {
      if (pauseNow) {
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
    if (lineSchedules.isNotEmpty && !pauseNow) {
      ref.invalidate(scheduledTopupControllerProvider);
    }
  }

  Future<void> deleteActivityLog(String id, String simLineId) async {
    final previousList = state.value ?? [];
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repo = ref.read(simLinesRepositoryProvider);
      await repo.deleteLineActivityLog(id);
      ref.invalidate(simLineActivityLogsProvider(simLineId));
      return previousList;
    });
  }

  Future<void> cleanMockLogs(String simLineId) async {
    final previousList = state.value ?? [];
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
    final previousList = state.value ?? [];
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final repo = ref.read(simLinesRepositoryProvider);
      await repo.clearAllActivityLogs(simLineId);
      ref.invalidate(simLineActivityLogsProvider(simLineId));
      return previousList;
    });
  }

  Future<void> performManualRefill(
    SimLine line,
    String paymentGatewayCode, {
    required String offerId,
    required double displayBaseUsd,
    double? amountUsd,
  }) async {
    // NOTE: Wallet deduction is now handled securely by the backend worker daemon.

    final repo = ref.read(simLinesRepositoryProvider);

    // C3b-2: request_instant_refill prices the offer server-side and queues it
    // for worker_instant_refill; sim_lines.last_topup_at is set by the DB
    // trigger when the refill actually succeeds, not at request time.
    await repo.requestInstantRefill(
      simLineId: line.id,
      offerId: offerId,
      paymentGatewayCode: paymentGatewayCode,
      displayBaseUsd: displayBaseUsd,
      amountUsd: amountUsd,
    );

    // Invalidate states. The wallet is deliberately not refreshed on a timer
    //    here: the worker's debit lands whenever it lands, so the balance is
    //    refreshed by the topupExecutionsLive subscription the moment the
    //    execution actually reaches a terminal status.
    ref.invalidateSelf();
    ref.invalidate(topupExecutionsForLineProvider(line.id));
    ref.invalidate(simLineActivityLogsProvider(line.id));
  }
}

@riverpod
Future<List<Carrier>> carriersForCountry(Ref ref, String countryId) {
  return ref.watch(simLinesRepositoryProvider).getCarriersForCountry(countryId);
}

@riverpod
Future<CarrierRule?> carrierRule(Ref ref, String carrierId) {
  return ref.watch(simLinesRepositoryProvider).getCarrierRule(carrierId);
}

/// I8: the operator's own top-up channel, for the rules sheet. Null for most
/// carriers — the sheet renders a store search from the carrier's name instead.
@riverpod
Future<CarrierSelfService?> carrierSelfService(Ref ref, String carrierId) {
  return ref.watch(simLinesRepositoryProvider).getCarrierSelfService(carrierId);
}

@riverpod
FutureOr<List<LineActivityLog>> simLineActivityLogs(Ref ref, String simLineId) {
  return ref.watch(simLinesRepositoryProvider).getLineActivityLogs(simLineId);
}

@riverpod
Future<List<Map<String, dynamic>>> zenditOffers(
  Ref ref,
  String countryId,
  String carrierId,
) {
  return ref
      .watch(simLinesRepositoryProvider)
      .fetchZenditOffers(countryId, carrierId);
}

@riverpod
Future<List<PaymentMethod>> paymentMethods(Ref ref) async {
  final repo = ref.watch(simLinesRepositoryProvider);
  return repo.getPaymentMethods();
}

@riverpod
Future<List<Country>> supportedCountries(Ref ref) {
  return ref.watch(simLinesRepositoryProvider).getSupportedCountries();
}
