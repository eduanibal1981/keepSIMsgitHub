import 'package:keep_sims/features/sim_lines/domain/line_refill_quote.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_self_service_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_activity_log_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/payment_method_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_liveness_result.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_verification_quote_model.dart';
import 'package:keep_sims/features/sim_lines/domain/repositories/sim_lines_repository.dart';
import 'package:keep_sims/features/sim_lines/data/datasources/twilio_verification_service.dart';
import 'package:keep_sims/features/sim_lines/data/datasources/telnyx_verification_service.dart';
import 'package:keep_sims/core/services/auth_session_manager.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/device_identity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/core/services/sync_queue_service.dart';
import 'package:keep_sims/core/utils/phone_number_validator.dart';

part 'sim_lines_repository_impl.g.dart';

class SimLinesRepositoryImpl implements SimLinesRepository {
  final SupabaseClient _supabase;
  final LocalCacheService _cache;
  final ConnectivityService _connectivity;
  final SyncQueue _syncQueue;

  /// G10 device binding. Optional so existing construction sites and tests keep
  /// compiling; it defaults to the real one, never to a no-op.
  final DeviceIdentityService _deviceIdentity;

  SimLinesRepositoryImpl({
    required SupabaseClient supabase,
    required LocalCacheService cache,
    required ConnectivityService connectivity,
    required SyncQueue syncQueue,
    DeviceIdentityService? deviceIdentity,
  }) : _supabase = supabase,
       _cache = cache,
       _connectivity = connectivity,
       _syncQueue = syncQueue,
       _deviceIdentity =
           deviceIdentity ?? DeviceIdentityService(supabase: supabase);

  @override
  Future<List<SimLine>> getSimLines() async {
    if (_connectivity.isOffline) {
      final cached = _cache.readJson('cached_sim_lines');
      if (cached is List) {
        return cached
            .map((json) => SimLine.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user session found.');
      }

      final response = await AuthSessionManager.withAuthRecovery(
        _supabase,
        () => _supabase
            .from('sim_lines')
            .select()
            .order('created_at', ascending: false)
            .order('id', ascending: true),
      );

      final list = (response as List)
          .map((json) => SimLine.fromJson(json as Map<String, dynamic>))
          .toList();

      await _cache.writeJson('cached_sim_lines', response);
      // Fill the offline-recharge caches for these lines' carriers while we have
      // a connection (C3b-3). Fire-and-forget: a warm failure must never break
      // the sim-line load.
      unawaited(_warmOfflineRefillCaches(list));
      return list;
    } on PostgrestException catch (e) {
      final cached = _cache.readJson('cached_sim_lines');
      if (cached is List) {
        return cached
            .map((json) => SimLine.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to load SIM lines: ${e.message}');
    } catch (e) {
      final cached = _cache.readJson('cached_sim_lines');
      if (cached is List) {
        return cached
            .map((json) => SimLine.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup')) {
        throw Exception('No internet connection. Please check your network.');
      }
      throw Exception('Failed to load SIM lines: $errStr');
    }
  }

  /// Pre-fills the offline-recharge caches (carrier list + carrier rule per
  /// line) so `offline_refill_screen` works on a cold first offline open
  /// (C3b-3). Best-effort: every fetch here already writes its own cache and
  /// swallows failures, so this only ever fills, never breaks.
  Future<void> _warmOfflineRefillCaches(List<SimLine> lines) async {
    final countryIds = <String>{};
    final carrierIds = <String>{};
    for (final line in lines) {
      final countryId = line.countryId;
      final carrierId = line.carrierId;
      if (countryId != null && countryId.isNotEmpty) countryIds.add(countryId);
      if (carrierId != null && carrierId.isNotEmpty) carrierIds.add(carrierId);
    }
    for (final countryId in countryIds) {
      try {
        await getCarriersForCountry(countryId);
      } catch (_) {
        /* cache fill only */
      }
    }
    for (final carrierId in carrierIds) {
      try {
        await getCarrierRule(carrierId);
      } catch (_) {
        /* cache fill only */
      }
    }
  }

  @override
  Future<SimLine> addSimLine(SimLine line) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('No authenticated user session found.');

    final localId = line.id.isEmpty
        ? (_connectivity.isOffline && line.planType == 'free'
              ? const Uuid().v4()
              : 'offline_${DateTime.now().microsecondsSinceEpoch}')
        : line.id;
    final updatedLine = line.copyWith(
      id: localId,
      userId: userId,
      verificationStatus: 'unverified',
      isCarrierVerified: false,
      carrierStatus: 'pending',
      carrierVerifiedAt: null,
      detectedOperatorName: null,
      healthScore: 0,
    );
    final data = updatedLine.toJson();

    if (_connectivity.isOffline) {
      final cached = _cache.readJson('cached_sim_lines') as List? ?? [];
      final updatedCache = [data, ...cached];
      await _cache.writeJson('cached_sim_lines', updatedCache);

      await _syncQueue.addToQueue('sim_line_add', data);
      return updatedLine;
    }

    try {
      final dataToSend = line.toJson()
        ..removeWhere(
          (key, _) => const {
            'verification_status',
            'health_score',
            'is_carrier_verified',
            'carrier_status',
            'carrier_verified_at',
            'detected_operator_name',
          }.contains(key),
        );
      if (line.id.isEmpty) {
        dataToSend.remove('id');
      }
      // I2: `toJson()` emits `created_at: null` / `updated_at: null` for a new
      // line, and an explicit NULL **overrides the column DEFAULT** — that is
      // why one production row has a null `created_at`. Let the database stamp
      // them.
      dataToSend.remove('created_at');
      dataToSend.remove('updated_at');
      dataToSend['user_id'] = userId;

      // Bounded so a socket left half-open by the app being backgrounded (for
      // the PayPal browser, say) surfaces as an error instead of hanging the
      // caller forever behind a spinner.
      final response = await _supabase
          .from('sim_lines')
          .insert(dataToSend)
          .select()
          .single()
          .timeout(const Duration(seconds: 20));

      final createdLine = SimLine.fromJson(response);

      // 1. Seed Genuine Created Log
      await _supabase.from('line_activity_log').insert({
        'sim_line_id': createdLine.id,
        'user_id': userId,
        'event_type': 'created',
        'description': 'SIM Line registered successfully in SIM Shield.',
        'metadata': {'carrier_name': line.nickname ?? 'SIM'},
      });

      return createdLine;
    } on PostgrestException catch (e) {
      throw Exception('Failed to add SIM line: ${e.message}');
    }
  }

  @override
  Future<SimLine> updateSimLine(SimLine line) async {
    final payload = line.toClientWritableJson();
    if (_connectivity.isOffline) {
      final data = Map<String, dynamic>.from(payload)..['id'] = line.id;
      final cached = _cache.readJson('cached_sim_lines') as List? ?? [];
      final updatedCache = cached.map((item) {
        if (item is Map && item['id'] == line.id) return data;
        return item;
      }).toList();
      await _cache.writeJson('cached_sim_lines', updatedCache);

      await _syncQueue.addToQueue('sim_line_update', data);
      return line;
    }

    try {
      final response = await _supabase
          .from('sim_lines')
          .update(payload)
          .eq('id', line.id)
          .select()
          .single();

      return SimLine.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update SIM line: ${e.message}');
    }
  }

  @override
  Future<void> deleteSimLine(String id) async {
    if (_connectivity.isOffline) {
      final cached = _cache.readJson('cached_sim_lines') as List? ?? [];
      final updatedCache = cached
          .where((item) => item is Map && item['id'] != id)
          .toList();
      await _cache.writeJson('cached_sim_lines', updatedCache);

      await _syncQueue.addToQueue('sim_line_delete', {'id': id});
      return;
    }

    try {
      await _supabase.from('sim_lines').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete SIM line: ${e.message}');
    }
  }

  @override
  Future<List<Country>> getSupportedCountries() async {
    if (_connectivity.isOffline) {
      final cached = _cache.readJson('cached_countries');
      if (cached is List) {
        final list = <Country>[];
        for (final item in cached) {
          try {
            list.add(Country.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
        return list;
      }
      return [];
    }

    try {
      final response = await _supabase
          .from('countries')
          .select()
          .eq('is_supported', true)
          .order('name', ascending: true);

      const targetCountries = [
        'saudi arabia',
        'united arab emirates',
        'uae',
        'qatar',
        'kuwait',
        'bahrain',
        'oman',
        'egypt',
        'syria',
        'iraq',
        'lebanon',
        'india',
        'pakistan',
        'bangladesh',
        'philippines',
        'nepal',
        'sri lanka',
      ];

      final countries = <Country>[];
      for (final item in (response as List)) {
        try {
          final c = Country.fromJson(item as Map<String, dynamic>);
          if (targetCountries.contains(c.name.toLowerCase()) || c.isSupported) {
            countries.add(c);
          }
        } catch (e) {
          debugPrint(
            '[getSupportedCountries] Skipped an invalid country record.',
          );
        }
      }

      countries.sort((a, b) {
        final aIndex = targetCountries.indexOf(a.name.toLowerCase());
        final bIndex = targetCountries.indexOf(b.name.toLowerCase());
        if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
        if (aIndex != -1) return -1;
        if (bIndex != -1) return 1;
        return a.name.compareTo(b.name);
      });

      await _cache.writeJson(
        'cached_countries',
        countries.map((c) => c.toJson()).toList(),
      );
      return countries;
    } on PostgrestException catch (e) {
      final cached = _cache.readJson('cached_countries');
      if (cached is List) {
        final list = <Country>[];
        for (final item in cached) {
          try {
            list.add(Country.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
        if (list.isNotEmpty) return list;
      }
      throw Exception('Failed to load countries: ${e.message}');
    } catch (e) {
      final cached = _cache.readJson('cached_countries');
      if (cached is List) {
        final list = <Country>[];
        for (final item in cached) {
          try {
            list.add(Country.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
        if (list.isNotEmpty) return list;
      }
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup')) {
        throw Exception('No internet connection. Please check your network.');
      }
      throw Exception('Failed to load countries: $errStr');
    }
  }

  @override
  Future<List<Carrier>> getCarriersForCountry(String countryId) async {
    // Cached per country so the offline-recharge screen has the line's carrier
    // (its default_refill_amount, gateway number) when the device is offline —
    // the one state that screen exists for (C3b-3). Without this the provider
    // threw offline and the UI fell back to a single hardcoded Oman number for
    // every carrier.
    final cacheKey = 'cached_carriers_$countryId';

    if (_connectivity.isOffline) {
      final cached = _cache.readJson(cacheKey);
      if (cached is List) {
        return cached
            .map((json) => Carrier.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    try {
      final response = await _supabase
          .from('carriers')
          .select()
          .eq('country_id', countryId)
          .eq('is_supported', true)
          .order('name', ascending: true);

      await _cache.writeJson(cacheKey, response);
      return (response as List)
          .map((json) => Carrier.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached is List) {
        return cached
            .map((json) => Carrier.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to load carriers: ${e.message}');
    } catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached is List) {
        return cached
            .map((json) => Carrier.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup')) {
        throw Exception('No internet connection. Please check your network.');
      }
      throw Exception('Failed to load carriers: $errStr');
    }
  }

  @override
  Future<CarrierRule?> getCarrierRule(String carrierId) async {
    final cacheKey = 'cached_carrier_rule_$carrierId';

    if (_connectivity.isOffline) {
      final cached = _cache.readJson(cacheKey);
      if (cached != null) {
        return CarrierRule.fromJson(cached as Map<String, dynamic>);
      }
      return null;
    }

    try {
      final response = await _supabase
          .from('carrier_rules')
          .select()
          .eq('carrier_id', carrierId)
          .eq('rule_type', 'default')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      dynamic ruleData;
      if (response == null) {
        // Fallback to prepaid if default rule_type doesn't exist
        final prepaidResponse = await _supabase
            .from('carrier_rules')
            .select()
            .eq('carrier_id', carrierId)
            .eq('rule_type', 'prepaid')
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (prepaidResponse == null) {
          return null;
        }
        ruleData = prepaidResponse;
      } else {
        ruleData = response;
      }

      await _cache.writeJson(cacheKey, ruleData);
      return CarrierRule.fromJson(ruleData);
    } on PostgrestException catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached != null) {
        return CarrierRule.fromJson(cached as Map<String, dynamic>);
      }
      throw Exception('Failed to load carrier rule: ${e.message}');
    } catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached != null) {
        return CarrierRule.fromJson(cached as Map<String, dynamic>);
      }
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup')) {
        throw Exception('No internet connection. Please check your network.');
      }
      throw Exception('Failed to load carrier rule: $errStr');
    }
  }

  @override
  Future<CarrierRule?> getCarrierRuleById(String ruleId) async {
    final cacheKey = 'cached_carrier_rule_id_$ruleId';

    if (_connectivity.isOffline) {
      final cached = _cache.readJson(cacheKey);
      if (cached != null) {
        return CarrierRule.fromJson(cached as Map<String, dynamic>);
      }
      return null;
    }

    try {
      final response = await _supabase
          .from('carrier_rules')
          .select()
          .eq('id', ruleId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      await _cache.writeJson(cacheKey, response);
      return CarrierRule.fromJson(response);
    } on PostgrestException catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached != null) {
        return CarrierRule.fromJson(cached as Map<String, dynamic>);
      }
      throw Exception('Failed to load carrier rule by id: ${e.message}');
    } catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached != null) {
        return CarrierRule.fromJson(cached as Map<String, dynamic>);
      }
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup')) {
        throw Exception('No internet connection. Please check your network.');
      }
      throw Exception('Failed to load carrier rule by id: $errStr');
    }
  }

  /// The operator's own top-up channel (I8). Absent for most carriers, and
  /// absence is a normal answer, not a failure — the rules sheet degrades to a
  /// store search built from the carrier's name.
  ///
  /// Never throws. This feeds an advisory panel, and a carrier with no row must
  /// not turn the sheet into an error state.
  @override
  Future<CarrierSelfService?> getCarrierSelfService(String carrierId) async {
    final cacheKey = 'cached_carrier_self_service_$carrierId';

    if (_connectivity.isOffline) {
      final cached = _cache.readJson(cacheKey);
      if (cached != null) {
        return CarrierSelfService.fromJson(cached as Map<String, dynamic>);
      }
      return null;
    }

    try {
      final response = await _supabase
          .from('carrier_self_service')
          .select()
          .eq('carrier_id', carrierId)
          .maybeSingle();

      if (response == null) return null;
      await _cache.writeJson(cacheKey, response);
      return CarrierSelfService.fromJson(response);
    } catch (_) {
      final cached = _cache.readJson(cacheKey);
      if (cached != null) {
        return CarrierSelfService.fromJson(cached as Map<String, dynamic>);
      }
      return null;
    }
  }

  @override
  Future<List<LineActivityLog>> getLineActivityLogs(String simLineId) async {
    final cacheKey = 'cached_logs_$simLineId';

    if (_connectivity.isOffline) {
      final cached = _cache.readJson(cacheKey);
      if (cached is List) {
        return cached
            .map(
              (json) => LineActivityLog.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    }

    try {
      final response = await _supabase
          .from('line_activity_log')
          .select()
          .eq('sim_line_id', simLineId)
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((json) => LineActivityLog.fromJson(json as Map<String, dynamic>))
          .toList();

      await _cache.writeJson(cacheKey, response);
      return list;
    } on PostgrestException catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached is List) {
        return cached
            .map(
              (json) => LineActivityLog.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      }
      throw Exception('Failed to load line activity logs: ${e.message}');
    } catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached is List) {
        return cached
            .map(
              (json) => LineActivityLog.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      }
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup')) {
        throw Exception('No internet connection. Please check your network.');
      }
      throw Exception('Failed to load line activity logs: $errStr');
    }
  }

  @override
  Future<void> deleteLineActivityLog(String id) async {
    try {
      await _supabase.from('line_activity_log').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete line activity log: ${e.message}');
    }
  }

  @override
  Future<void> cleanMockLogs(String simLineId) async {
    try {
      // topup_executions is no longer client-writable (C3b-2), and the old
      // delete here was a silent no-op anyway (the table never had a DELETE
      // policy). Only the mock activity-log entries are cleanable.
      await _supabase
          .from('line_activity_log')
          .delete()
          .eq('sim_line_id', simLineId)
          .eq('metadata->>is_mock', 'true');
    } on PostgrestException catch (e) {
      throw Exception('Failed to clean mock logs: ${e.message}');
    }
  }

  @override
  Future<void> clearAllActivityLogs(String simLineId) async {
    try {
      // Option A: Money trail events (topup_*) are immutable; only non-financial
      // events (health_update, created, etc.) are deleted.
      await _supabase
          .from('line_activity_log')
          .delete()
          .eq('sim_line_id', simLineId)
          .not('event_type', 'in', [
            'topup_requested',
            'topup_success',
            'topup_failed',
            'topup_refunded',
            'topup_cancelled',
            'topup_retry_queued',
          ]);
      final cacheKey = 'cached_logs_$simLineId';
      await _cache.writeJson(cacheKey, []);
    } on PostgrestException catch (e) {
      throw Exception('Failed to clear activity logs: ${e.message}');
    }
  }

  @override
  Future<LineRefillQuote> fetchCustomerRefillQuote({
    required String simLineId,
    required String offerId,
    int? offerValue,
  }) async {
    final result = await _supabase.rpc(
      'get_customer_refill_quote',
      params: {
        'p_sim_line_id': simLineId,
        'p_offer_id': offerId,
        'p_offer_value': offerValue,
      },
    );
    return LineRefillQuote.fromJson(
      Map<String, dynamic>.from(result as Map),
      simLineId: simLineId,
    );
  }

  @override
  Future<String> requestInstantRefill({
    required String simLineId,
    required String offerId,
    required String paymentGatewayCode,
    required double authorizedTotalUsd,
    int? offerValue,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user session found.');
      }

      // Only a retail authorization ceiling and dispatch value leave the app.
      final executionId = await _supabase.rpc(
        'request_retail_instant_refill',
        params: {
          'p_sim_line_id': simLineId,
          'p_offer_id': offerId,
          'p_max_authorized_usd': authorizedTotalUsd,
          'p_offer_value': offerValue,
          // G10: a claim, scored server-side. Null (an older build) is treated
          // as more suspicious than a known device, never as clean.
          'p_device_id': await _deviceIdentity.deviceId(),
        },
      );

      // Server DB trigger trg_topup_executions_activity automatically logs the
      // activity trail on topup_executions INSERT and status transitions.

      return executionId as String;
    } on PostgrestException catch (e) {
      // G10 (KS451): this refusal is raised, so the server's own audit row was
      // rolled back with the transaction. Put it back before rethrowing — see
      // the header of 20260809030000_g10d_durable_block_audit.sql.
      if (e.code == 'KS451') {
        await _deviceIdentity.reportBlock(
          action: 'instant_refill',
          amountUsd: authorizedTotalUsd,
        );
        throw Exception('DEVICE_BLOCKED');
      }
      throw Exception('Failed to request refill: ${e.message}');
    }
  }

  @override
  Future<void> initializeLineSchedules(String simLineId) async {
    if (_connectivity.isOffline) {
      // Free offline creation uses a durable UUID, so replay initializes the
      // same line after its queued insert. No paid settings are cached here.
      await _syncQueue.addToQueue('line_schedule_initialize', {
        'sim_line_id': simLineId,
        'user_id': _supabase.auth.currentUser?.id,
      });
      return;
    }
    final response = await _supabase.rpc(
      'initialize_line_schedules',
      params: {'p_sim_line_id': simLineId},
    );
    if (response is! Map || response['success'] != true) {
      throw Exception('Schedule setup could not be confirmed.');
    }
    if (response['needs_authorization'] == true) {
      throw Exception(
        'Review the current refill price in Auto-Refill settings to authorize the next occurrence.',
      );
    }
  }

  @override
  Future<String?> triggerMissedCall(String phoneNumber) async {
    return TwilioVerificationService.triggerMissedCall(phoneNumber);
  }

  @override
  Future<bool> checkCallStatus(String callSid) async {
    final status = await TwilioVerificationService.fetchCallStatus(callSid);
    return status == TwilioCallStatus.ringing ||
        status == TwilioCallStatus.completed ||
        status == TwilioCallStatus.busy ||
        status == TwilioCallStatus.noAnswer ||
        status == TwilioCallStatus.inProgress;
  }

  @override
  Future<String?> triggerSmsVerification(String phoneNumber) async {
    return TelnyxVerificationService.sendVerificationSms(phoneNumber);
  }

  @override
  Future<TelnyxSmsResult> checkSmsDeliveryStatus(String messageId) async {
    return TelnyxVerificationService.fetchMessageStatus(messageId);
  }

  @override
  Future<void> cancelCall(String callSid) async {
    await TwilioVerificationService.cancelCall(callSid);
  }

  Future<void> _ensureValidSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null && session.isExpired) {
        await _supabase.auth.refreshSession();
      }
    } catch (_) {
      // Continue and let the operation proceed or fail with auth exception
    }
  }

  @override
  Future<LineVerificationQuote> quoteLineVerification(String simLineId) async {
    try {
      await _ensureValidSession();
      final res = await _supabase.rpc(
        'quote_line_verification',
        params: {'p_sim_line_id': simLineId},
      );
      return LineVerificationQuote.fromJson(
        Map<String, dynamic>.from(res as Map),
      );
    } on PostgrestException catch (e) {
      if (e.message.toLowerCase().contains('jwt') ||
          e.message.toLowerCase().contains('token')) {
        try {
          await _supabase.auth.refreshSession();
          final retryRes = await _supabase.rpc(
            'quote_line_verification',
            params: {'p_sim_line_id': simLineId},
          );
          return LineVerificationQuote.fromJson(
            Map<String, dynamic>.from(retryRes as Map),
          );
        } catch (_) {}
      }
      throw Exception('Failed to generate verification quote: ${e.message}');
    }
  }

  @override
  Future<Map<String, dynamic>> startLineVerification({
    required String simLineId,
    required String method,
    String? idempotencyKey,
  }) async {
    final requestKey = idempotencyKey ?? const Uuid().v4();
    try {
      await _ensureValidSession();
      final response = await _supabase.functions.invoke(
        'liveness-verification',
        body: {
          'action': 'start',
          'simLineId': simLineId,
          'method': method,
          'idempotencyKey': requestKey,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['error'] != null) {
          throw Exception(data['error']);
        }
        return data;
      }
      throw Exception('Unexpected response starting verification: $data');
    } catch (e) {
      if (e.toString().toLowerCase().contains('jwt') ||
          e.toString().toLowerCase().contains('unauthorized')) {
        try {
          await _supabase.auth.refreshSession();
          final retryResp = await _supabase.functions.invoke(
            'liveness-verification',
            body: {
              'action': 'start',
              'simLineId': simLineId,
              'method': method,
              'idempotencyKey': requestKey,
            },
          );
          final data = retryResp.data;
          if (data is Map<String, dynamic>) {
            if (data['error'] != null) {
              throw Exception(data['error']);
            }
            return data;
          }
        } catch (_) {}
      }
      throw Exception(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> getLineVerificationAttemptStatus(
    String attemptId,
  ) async {
    try {
      await _ensureValidSession();
      final response = await _supabase.functions.invoke(
        'liveness-verification',
        body: {'action': 'status', 'attemptId': attemptId},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw Exception('Unexpected response fetching attempt status: $data');
    } catch (e) {
      if (e.toString().toLowerCase().contains('jwt') ||
          e.toString().toLowerCase().contains('unauthorized')) {
        try {
          await _supabase.auth.refreshSession();
          final retryResp = await _supabase.functions.invoke(
            'liveness-verification',
            body: {'action': 'status', 'attemptId': attemptId},
          );
          final data = retryResp.data;
          if (data is Map<String, dynamic>) {
            return data;
          }
        } catch (_) {}
      }
      throw Exception(e.toString());
    }
  }

  /// Offers for a carrier in the add-line flow, which has no SIM line id yet.
  ///
  /// K3/K5: this used to read `carriers.api_provider` plus `zen_carrier` /
  /// `dt_carrier` and then query `provider_offers_cache` itself — client-side
  /// supplier dispatch over columns that no longer exist. Those columns held one
  /// supplier per carrier, so a carrier reachable through two was unrepresentable
  /// and the branch for `ding`/`reloadly` silently returned nothing.
  ///
  /// `list_carrier_offers` resolves the supplier server-side from
  /// `carrier_provider_map`, applies the same routability test the purchase path
  /// applies, and returns the effective price — so an admin's manual price shows
  /// here without a client release. `countryId` is no longer needed: the carrier
  /// already determines the country. It stays in the signature so the provider
  /// key and its callers are untouched.
  @override
  Future<List<Map<String, dynamic>>> fetchZenditOffers(
    String countryId,
    String carrierId,
  ) async {
    try {
      final rows = await _supabase.rpc(
        'list_carrier_offers',
        params: {'p_carrier_id': carrierId},
      );

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map<Map<String, dynamic>>(
            (r) => {
              'offerId': r['offer_id'],
              'description': r['offer_name'] ?? r['offer_id'],
              'priceType': r['price_type'],
              'isRange': r['price_type'] == 'RANGE',
              // The server already applied any manual override, so this is
              // what the user will actually be charged.
              'retailPriceUsd': (r['price_usd'] as num?)?.toDouble(),
              'priceMinUsd': (r['price_min_usd'] as num?)?.toDouble(),
              'priceMaxUsd': (r['price_max_usd'] as num?)?.toDouble(),
              'min': r['send_min'],
              'max': r['send_max'],
              'sendCurrencyDivisor': r['send_currency_divisor'] ?? 100,
              'send': {'currency': r['send_currency']},
              'provider': r['provider'],
              'isStale': r['is_stale'] ?? false,
            },
          )
          .toList(); // Already ranked cheapest-first server-side.
    } on PostgrestException catch (e) {
      throw Exception('Database error fetching offers: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching carrier offers: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchLineRefillOffers(
    String simLineId,
  ) async {
    try {
      // I1: one call, every enabled supplier for this line's carrier, already
      // ranked cheapest-first server-side. This replaces the Dart-side provider
      // switch, which listed DTOne offers that `request_instant_refill` then
      // refused because it only ever validated against the Zendit view.
      final rows = await _supabase.rpc(
        'list_refill_offers',
        params: {'p_sim_line_id': simLineId},
      );

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map<Map<String, dynamic>>(
            (r) => {
              'offerId': r['offer_id'],
              'description': r['offer_name'] ?? r['offer_id'],
              'benefitSummary':
                  r['benefit_summary'] ?? r['offer_name'] ?? r['offer_id'],
              'serviceType': r['service_type'] ?? 'airtime',
              'dataMb': (r['data_mb'] as num?)?.toInt(),
              'durationDays': (r['duration_days'] as num?)?.toInt(),
              'deliveryType': r['delivery_type'] ?? 'direct',
              'priceType': r['price_type'],
              'isRange': r['price_type'] == 'RANGE',
              'retailPriceUsd': (r['price_fixed_usd'] as num?)?.toDouble(),
              'priceMinUsd': (r['price_min_usd'] as num?)?.toDouble(),
              'priceMaxUsd': (r['price_max_usd'] as num?)?.toDouble(),
              'min': r['send_min'],
              'max': r['send_max'],
              'sendCurrencyDivisor': r['send_currency_divisor'] ?? 100,
              'send': {'currency': r['send_currency']},
              // Carried for display/diagnostics only — the server picks the
              // supplier again at purchase time from the same ranking, so a
              // stale client cannot steer a purchase to a chosen supplier.
              'provider': r['provider'],
              'isStale': r['is_stale'] == true,
            },
          )
          // Deliberately NOT re-sorted here. The RPC's ORDER BY is the ranking
          // that `request_instant_refill` re-applies when it resolves the
          // offer; a second sort in Dart is how a list and a purchase disagree.
          .where((o) => o['isStale'] != true)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Database error fetching offers: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching refill offers: $e');
    }
  }

  @override
  Future<List<PaymentMethod>> getPaymentMethods() async {
    try {
      final response = await _supabase
          .from('payment_gateways')
          .select()
          .eq('is_active', true)
          .order('code', ascending: false);

      return (response as List)
          .map((json) => PaymentMethod.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load payment methods: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load payment methods: $e');
    }
  }

  @override
  Future<void> recordManualExternalRecharge({
    required String simLineId,
    required DateTime rechargeDate,
    double? amount,
    String? note,
  }) async {
    try {
      await _supabase.rpc(
        'record_manual_external_recharge',
        params: {
          'p_sim_line_id': simLineId,
          'p_recharge_date': rechargeDate.toUtc().toIso8601String(),
          'p_amount': amount,
          'p_note': note,
        },
      );
    } on PostgrestException catch (e) {
      throw Exception('Failed to record manual recharge: ${e.message}');
    } catch (e) {
      throw Exception('Error recording manual recharge: $e');
    }
  }

  @override
  Future<SimLivenessResult> validateSimLiveness(
    String phoneNumber, {
    String? countryCode,
  }) async {
    final cleanPhone = phoneNumber.trim();
    final cacheKey = 'liveness_v2_$cleanPhone';

    // 1. Instant National Numbering Plan & Carrier Detection
    final localLookup = PhoneNumberValidator.validateAndDetect(
      phoneNumber: cleanPhone,
      countryIsoCode: countryCode,
      dialingCode: PhoneNumberValidator.getDialingCodeForIso(countryCode),
    );

    // If local format is explicitly invalid (e.g. wrong digits or invalid prefix)
    if (!localLookup.isValidFormat) {
      return SimLivenessResult(
        isActive: false,
        carrierStatus: 'inactive',
        message: localLookup.message,
        verifiedAt: DateTime.now(),
      );
    }

    if (_connectivity.isOffline) {
      final cached = _cache.readJson(cacheKey);
      if (cached is Map<String, dynamic>) {
        try {
          return SimLivenessResult.fromJson(cached);
        } catch (_) {}
      }
      return SimLivenessResult(
        isActive: false,
        carrierStatus: 'pending',
        detectedOperatorName: localLookup.detectedCarrierName,
        message: localLookup.detectedCarrierName != null
            ? '${localLookup.detectedCarrierName} validated (Valid line format)'
            : 'Line format validated (Offline)',
        verifiedAt: DateTime.now(),
      );
    }

    try {
      final response = await _supabase.functions.invoke(
        'validate-sim-liveness',
        body: {
          'phoneNumber': cleanPhone,
          if (countryCode != null && countryCode.isNotEmpty)
            'countryCode': countryCode,
        },
      );

      SimLivenessResult? remoteResult;
      if (response.status == 200 && response.data != null) {
        final Map<String, dynamic> data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : (response.data as Map<String, dynamic>);

        remoteResult = SimLivenessResult.fromJson(data);
        await _cache.writeJson(cacheKey, data);
      } else if (response.data != null) {
        final Map<String, dynamic> data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : (response.data as Map<String, dynamic>);
        remoteResult = SimLivenessResult.fromJson(data);
      }

      if (remoteResult != null) return remoteResult;

      // If response body was null, but local format is valid
      return SimLivenessResult(
        isActive: false,
        carrierStatus: 'pending',
        detectedOperatorName: localLookup.detectedCarrierName,
        message: localLookup.detectedCarrierName != null
            ? '${localLookup.detectedCarrierName} validated (Valid line format)'
            : 'Valid line format detected',
        verifiedAt: DateTime.now(),
      );
    } catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached is Map<String, dynamic>) {
        try {
          return SimLivenessResult.fromJson(cached);
        } catch (_) {}
      }
      return SimLivenessResult(
        isActive: false,
        carrierStatus: 'pending',
        detectedOperatorName: localLookup.detectedCarrierName,
        message: localLookup.detectedCarrierName != null
            ? '${localLookup.detectedCarrierName} validated (Valid line format)'
            : 'Line format validated',
        verifiedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> sendSimOtp({
    required String phoneNumber,
    required String channel,
    String? countryCode,
  }) async {
    final cleanPhone = phoneNumber.trim();
    try {
      final response = await _supabase.functions.invoke(
        'send-sim-otp',
        body: {
          'phoneNumber': cleanPhone,
          'channel': channel,
          if (countryCode != null && countryCode.isNotEmpty)
            'countryCode': countryCode,
        },
      );

      if (response.data != null) {
        final Map<String, dynamic> data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : (response.data as Map<String, dynamic>);
        return data;
      }
      return {'success': false, 'message': 'Unexpected response from server.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  @override
  Future<SimLivenessResult> verifySimOtp({
    required String phoneNumber,
    required String code,
    String? operatorName,
    String? countryCode,
  }) async {
    final cleanPhone = phoneNumber.trim();
    final cacheKey = 'liveness_$cleanPhone';

    try {
      final response = await _supabase.functions.invoke(
        'verify-sim-otp',
        body: {
          'phoneNumber': cleanPhone,
          'code': code.trim(),
          if (operatorName != null && operatorName.isNotEmpty)
            'operatorName': operatorName,
          if (countryCode != null && countryCode.isNotEmpty)
            'countryCode': countryCode,
        },
      );

      if (response.data != null) {
        final Map<String, dynamic> data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : (response.data as Map<String, dynamic>);

        final result = SimLivenessResult.fromJson(data);
        if (result.isActive) {
          await _cache.writeJson(cacheKey, data);
        }
        return result;
      }

      return SimLivenessResult(
        isActive: false,
        carrierStatus: 'unsupported',
        message: 'Could not verify code. Please try again.',
        verifiedAt: DateTime.now(),
      );
    } catch (e) {
      return SimLivenessResult(
        isActive: false,
        carrierStatus: 'unsupported',
        message: 'Verification failed: $e',
        verifiedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<bool> hasRealLiveVerification(String simLineId) async {
    try {
      final line = await _supabase
          .from('sim_lines')
          .select('id')
          .eq('id', simLineId)
          .eq('verification_status', 'verified')
          .eq('is_carrier_verified', true)
          .maybeSingle();
      return line != null;
    } catch (_) {
      return false;
    }
  }
}

@riverpod
SimLinesRepository simLinesRepository(Ref ref) {
  final cache = ref.watch(localCacheServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider.notifier);
  final syncQueue = ref.watch(syncQueueProvider.notifier);
  return SimLinesRepositoryImpl(
    supabase: Supabase.instance.client,
    cache: cache,
    connectivity: connectivity,
    syncQueue: syncQueue,
  );
}
