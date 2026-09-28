import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_self_service_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_activity_log_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/payment_method_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_liveness_result.dart';
import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';
import 'package:keep_sims/features/sim_lines/domain/repositories/sim_lines_repository.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:keep_sims/features/notifications/domain/notification_event_catalog.dart';

part 'sim_lines_controller.g.dart';

/// The line was created and paid for, but its pre-paid year of refills could
/// not be queued.
///
/// This is a *different* outcome from "the save failed", and conflating the two
/// is what put an unpaid premium line into production on 2026-08-08: the insert
/// had already succeeded when `queue_premium_refill_executions` raised KS403,
/// so the screen reported "Failed to save SIM line" over a row that exists.
/// The user then cannot retry — the phone number is taken — and the line sits
/// there labelled Premium with nothing scheduled behind it.
///
/// Callers must treat this as: the line is real, the money is spent, say so,
/// and do not offer a retry that would only collide with the row.
class PremiumRefillQueueException implements Exception {
  const PremiumRefillQueueException(this.simLineId, this.cause);

  final String simLineId;
  final Object cause;

  @override
  String toString() => cause.toString();
}

@Riverpod(keepAlive: true)
class SimLinesController extends _$SimLinesController {
  Timer? _pendingPollTimer;

  @override
  FutureOr<List<SimLine>> build() async {
    ref.onDispose(() {
      _pendingPollTimer?.cancel();
    });

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

    // If any line is in pending verification state, schedule a short periodic poll
    // to ensure the dashboard reflects the active state immediately upon backend completion.
    final hasPending = lines.any((l) => l.carrierStatus == 'pending' || l.status == 'pending');
    if (hasPending) {
      _schedulePendingCheck();
    }

    return lines;
  }

  void _schedulePendingCheck() {
    _pendingPollTimer?.cancel();
    _pendingPollTimer = Timer(const Duration(seconds: 3), () async {
      final authProfile = ref.read(authControllerProvider).value;
      if (authProfile == null) return;

      try {
        final repo = ref.read(simLinesRepositoryProvider);
        final freshLines = await repo.getSimLines();
        final hasPending = freshLines.any((l) => l.carrierStatus == 'pending' || l.status == 'pending');

        freshLines.sort((a, b) {
          final aName = (a.nickname ?? a.phoneNumber).toLowerCase();
          final bName = (b.nickname ?? b.phoneNumber).toLowerCase();
          return aName.compareTo(bName);
        });

        state = AsyncData(freshLines);
        ref.invalidate(scheduledTopupControllerProvider);

        if (hasPending) {
          _schedulePendingCheck();
        }
      } catch (_) {
        _schedulePendingCheck();
      }
    });
  }

  Future<SimLine> addSimLine({
    required String phoneNumber,
    String? nickname,
    String avatarIcon = 'sim_card',
    String? countryId,
    String? carrierId,
    required String protectionTier,
    String planType = 'free',
    DateTime? planExpiresAt,
    String? carrierRuleId,
    bool isCarrierVerified = false,
    String carrierStatus = 'pending',
    String? detectedOperatorName,
    DateTime? carrierVerifiedAt,
    bool isDraft = false,
  }) async {
    final userId = ref.read(authControllerProvider).value?.id;
    if (userId == null) {
      throw Exception('Cannot add SIM line: User is not authenticated.');
    }

    final previousList = state.value ?? [];
    SimLine? addedLine;
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    final nextState = await AsyncValue.guard(() async {
      final repo = ref.read(simLinesRepositoryProvider);

      // Protection is active regardless of current country location.
      // Lines start active (isHomeMode: false, protectionPaused: false)
      // and do not auto-pause on location changes.
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
        isHomeMode: false,
        protectionPaused: false,
        isCarrierVerified: isCarrierVerified,
        carrierStatus: carrierStatus,
        detectedOperatorName: detectedOperatorName,
        carrierVerifiedAt: carrierVerifiedAt,
      );

      final added = await repo.addSimLine(newLine);
      addedLine = added;

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

      // If draft line (e.g. during Premium setup before recharge confirmation), do not create schedules yet
      if (isDraft) {
        return [added, ...previousList];
      }

      // Auto-configure Scheduled Topups for non-draft lines
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
        }
      } else if (added.carrierId != null) {
        final rule = await repo.getCarrierRule(added.carrierId!);
        if (rule != null) {
          frequencyDays = rule.refillIntervalDays;
          topupAmount = rule.minimumTopupAmount;
          offerId = rule.offerId;
          offerValue = rule.offerValue;
        }
      }

      final topupNotifier = ref.read(scheduledTopupControllerProvider.notifier);

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
      final notifyResult = await topupNotifier.saveSchedule(notifySchedule);

      Result<ScheduledTopup>? refillResult;
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
          maxAuthorizedUsd: topupAmount,
          engineVersion: 2,
          intentKind: 'exact_airtime',
        );
        refillResult = await topupNotifier.saveSchedule(refillSchedule);

        if (refillResult is Success<ScheduledTopup> && planExpiresAt != null) {
          await _queuePremiumRefills(
            repo,
            simLineId: added.id,
            scheduledTopupId: refillResult.data.id,
            planExpiresAt: planExpiresAt,
          );
        }
      }

      // Send truthful setup confirmation based on actual persisted outcomes (N1)
      try {
        final notificationsRepo = ref.read(notificationsRepositoryProvider);
        if (planType == 'premium') {
          if (refillResult is Success<ScheduledTopup>) {
            await notificationsRepo.emitEvent(
              eventType: NotificationEventType.autoRechargeScheduled,
              templateData: {
                'nickname': added.nickname,
                'phone_number': added.phoneNumber,
                'date': refillResult.data.nextExecutionAt,
              },
              simLineId: added.id,
              sourceEventKey: 'setup_${added.id}',
              scheduledAt: refillResult.data.nextExecutionAt,
            );
          } else {
            await notificationsRepo.emitEvent(
              eventType: NotificationEventType.lineSetupIncomplete,
              templateData: {
                'nickname': added.nickname,
                'phone_number': added.phoneNumber,
              },
              simLineId: added.id,
              sourceEventKey: 'setup_incomplete_${added.id}',
            );
          }
        } else {
          if (notifyResult is Success<ScheduledTopup>) {
            await notificationsRepo.emitEvent(
              eventType: NotificationEventType.lineAdded,
              templateData: {
                'nickname': added.nickname,
                'phone_number': added.phoneNumber,
                'date': notifyResult.data.nextExecutionAt,
              },
              simLineId: added.id,
              sourceEventKey: 'setup_${added.id}',
              scheduledAt: notifyResult.data.nextExecutionAt,
            );
          } else {
            await notificationsRepo.emitEvent(
              eventType: NotificationEventType.lineSetupIncomplete,
              templateData: {
                'nickname': added.nickname,
                'phone_number': added.phoneNumber,
              },
              simLineId: added.id,
              sourceEventKey: 'setup_incomplete_${added.id}',
            );
          }
        }
      } catch (e) {
        debugPrint('[addSimLine] Failed to emit setup notification: $e');
      }

      return [added, ...previousList];
    });

    state = nextState;
    if (nextState.hasError) {
      throw nextState.error!;
    }

    if (!isDraft &&
        (planType == 'premium' || planType == 'standard') &&
        addedLine != null) {
      schedulePostRefillCheck(addedLine!.id);
    }

    return addedLine!;
  }

  /// Queues the pre-paid year, returning the failure instead of throwing.
  ///
  /// Retried once, because the call is idempotent by construction — it cancels
  /// this schedule's pending executions before re-inserting them — so a dropped
  /// socket costs a round-trip rather than a line that is Premium in name only.
  /// A second failure is reported, never swallowed: a premium line with an
  /// empty queue looks identical to a working one from the app, and would only
  /// be discovered when the number was already gone.
  Future<PremiumRefillQueueException?> _queuePremiumRefills(
    SimLinesRepository repo, {
    required String simLineId,
    required String scheduledTopupId,
    required DateTime planExpiresAt,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await repo.queuePremiumRefillExecutions(
          simLineId: simLineId,
          scheduledTopupId: scheduledTopupId,
          planExpiresAt: planExpiresAt,
        );
        return null;
      } catch (e) {
        if (attempt == 1) {
          return PremiumRefillQueueException(simLineId, e);
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    return null;
  }

  Future<void> updateSimLine(SimLine line) async {
    final previousList = state.value ?? [];
    PremiumRefillQueueException? queueFailure;
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    final nextState = await AsyncValue.guard(() async {
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
              maxAuthorizedUsd: topupAmount,
              engineVersion: 2,
              intentKind: 'exact_airtime',
            );
            final result = await topupNotifier.saveSchedule(refillSchedule);

            // C3b-2: queued and priced server-side from carrier_rules.
            if (result is Success<ScheduledTopup>) {
              queueFailure = await _queuePremiumRefills(
                repo,
                simLineId: line.id,
                scheduledTopupId: result.data.id,
                planExpiresAt:
                    line.planExpiresAt ??
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

    state = nextState;
    if (nextState.hasError) {
      throw nextState.error!;
    }

    if (line.planType == 'premium' || line.planType == 'standard') {
      schedulePostRefillCheck(line.id);
    }

    if (queueFailure != null) throw queueFailure!;
  }

  Future<void> deleteSimLine(String id) async {
    final previousList = state.value ?? [];
    state = const AsyncLoading<List<SimLine>>().copyWithPrevious(state);
    try {
      final repo = ref.read(simLinesRepositoryProvider);
      await repo.deleteSimLine(id);

      // Invalidate auto-refill schedules to keep local state synced with Supabase cascade deletes
      ref.invalidate(scheduledTopupControllerProvider);

      state = AsyncData(previousList.where((item) => item.id != id).toList());
    } catch (e) {
      state = AsyncData(previousList);
      rethrow;
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

    schedulePostRefillCheck(line.id);
  }

  /// Schedules staggered background refreshes to pick up server-worker refill
  /// completions (which take 2-5s) without requiring the user to manually hit
  /// the refresh button.
  void schedulePostRefillCheck([String? simLineId]) {
    Timer(
      const Duration(milliseconds: 2500),
      () => _triggerAutoRefresh(simLineId),
    );
    Timer(
      const Duration(milliseconds: 5500),
      () => _triggerAutoRefresh(simLineId),
    );
    Timer(
      const Duration(milliseconds: 10000),
      () => _triggerAutoRefresh(simLineId),
    );
  }

  Future<void> _triggerAutoRefresh([String? targetLineId]) async {
    try {
      final repo = ref.read(simLinesRepositoryProvider);
      final freshLines = await repo.getSimLines();
      freshLines.sort((a, b) {
        final aName = (a.nickname ?? a.phoneNumber).toLowerCase();
        final bName = (b.nickname ?? b.phoneNumber).toLowerCase();
        return aName.compareTo(bName);
      });
      state = AsyncData(freshLines);
      ref.invalidate(scheduledTopupControllerProvider);
      if (targetLineId != null) {
        ref.invalidate(topupExecutionsForLineProvider(targetLineId));
        ref.invalidate(simLineActivityLogsProvider(targetLineId));
      }
    } catch (_) {
      // Ignore background refresh errors
    }
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

@riverpod
Future<SimLivenessResult> simLivenessValidation(
  Ref ref, {
  required String phoneNumber,
  String? countryCode,
}) {
  return ref
      .watch(simLinesRepositoryProvider)
      .validateSimLiveness(phoneNumber, countryCode: countryCode);
}

@riverpod
Future<bool> hasRealLiveVerification(Ref ref, String simLineId) {
  return ref.watch(simLinesRepositoryProvider).hasRealLiveVerification(simLineId);
}
