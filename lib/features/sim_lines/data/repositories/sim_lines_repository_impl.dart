import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_activity_log_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/payment_method_model.dart';
import 'package:keep_sims/features/sim_lines/domain/repositories/sim_lines_repository.dart';
import 'package:keep_sims/features/sim_lines/data/datasources/twilio_verification_service.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/core/services/sync_queue_service.dart';

part 'sim_lines_repository_impl.g.dart';

class SimLinesRepositoryImpl implements SimLinesRepository {
  final SupabaseClient _supabase;
  final LocalCacheService _cache;
  final ConnectivityService _connectivity;
  final SyncQueue _syncQueue;

  SimLinesRepositoryImpl({
    required SupabaseClient supabase,
    required LocalCacheService cache,
    required ConnectivityService connectivity,
    required SyncQueue syncQueue,
  }) : _supabase = supabase,
       _cache = cache,
       _connectivity = connectivity,
       _syncQueue = syncQueue;

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

      final response = await _supabase
          .from('sim_lines')
          .select()
          .order('created_at', ascending: false)
          .order('id', ascending: true);

      final list = (response as List)
          .map((json) => SimLine.fromJson(json as Map<String, dynamic>))
          .toList();

      await _cache.writeJson('cached_sim_lines', response);
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

  @override
  Future<SimLine> addSimLine(SimLine line) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('No authenticated user session found.');

    final localId = line.id.isEmpty
        ? 'offline_${DateTime.now().microsecondsSinceEpoch}'
        : line.id;
    final updatedLine = line.copyWith(id: localId, userId: userId);
    final data = updatedLine.toJson();

    if (_connectivity.isOffline) {
      final cached = _cache.readJson('cached_sim_lines') as List? ?? [];
      final updatedCache = [data, ...cached];
      await _cache.writeJson('cached_sim_lines', updatedCache);

      await _syncQueue.addToQueue('sim_line_add', data);
      return updatedLine;
    }

    try {
      final dataToSend = line.toJson();
      if (line.id.isEmpty) {
        dataToSend.remove('id');
      }
      dataToSend['user_id'] = userId;

      final response = await _supabase
          .from('sim_lines')
          .insert(dataToSend)
          .select()
          .single();

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
    final data = line.toJson();

    if (_connectivity.isOffline) {
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
          .update(line.toJson())
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
        return cached
            .map((json) => Country.fromJson(json as Map<String, dynamic>))
            .toList();
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
        'india',
        'pakistan',
        'bangladesh',
        'philippines',
        'nepal',
        'sri lanka',
      ];

      final countries = (response as List)
          .map((json) => Country.fromJson(json as Map<String, dynamic>))
          .where((c) => targetCountries.contains(c.name.toLowerCase()))
          .toList();

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
        return cached
            .map((json) => Country.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to load countries: ${e.message}');
    } catch (e) {
      final cached = _cache.readJson('cached_countries');
      if (cached is List) {
        return cached
            .map((json) => Country.fromJson(json as Map<String, dynamic>))
            .toList();
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
    try {
      final response = await _supabase
          .from('carriers')
          .select()
          .eq('country_id', countryId)
          .eq('is_supported', true)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => Carrier.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load carriers: ${e.message}');
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
      // 1. Delete mock executions from topup_executions
      await _supabase
          .from('topup_executions')
          .delete()
          .eq('sim_line_id', simLineId)
          .like('reloadly_transaction_id', 'MOCK_%');

      // 2. Delete mock logs from line_activity_log (where metadata->>is_mock is 'true')
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
      await _supabase
          .from('line_activity_log')
          .delete()
          .eq('sim_line_id', simLineId);
      final cacheKey = 'cached_logs_$simLineId';
      await _cache.writeJson(cacheKey, []);
    } on PostgrestException catch (e) {
      throw Exception('Failed to clear activity logs: ${e.message}');
    }
  }

  @override
  Future<void> recordManualTopupExecution({
    required String simLineId,
    required double baseCostUsd,
    required String paymentGatewayCode,
    required String status,
    String? failureReason,
    String? offerId,
    int? offerValue,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user session found.');
      }

      // Insert pending topup execution into the central queue
      await _supabase.from('topup_executions').insert({
        'sim_line_id': simLineId,
        'user_id': userId,
        'amount': baseCostUsd,
        'base_cost_usd': baseCostUsd,
        'payment_gateway_code': paymentGatewayCode,
        'currency': 'USD',
        // status is passed from the controller ('routing', 'pending_payment', or 'failed')
        'status': status,
        'failure_reason': ?failureReason,
        'offer_id': ?offerId,
        'offer_value': ?offerValue,
        'execution_type': 'refill_instant',
        'execution_time': DateTime.now().toIso8601String(),
        'executed_at': null,
      });

      // Also log the activity
      await _supabase.from('line_activity_log').insert({
        'sim_line_id': simLineId,
        'user_id': userId,
        'event_type': status != 'failed' ? 'topup_success' : 'topup_failed',
        'description': status != 'failed'
            ? 'Manual Refill of \$${baseCostUsd.toStringAsFixed(2)} successful.'
            : 'Manual Refill of \$${baseCostUsd.toStringAsFixed(2)} failed: $failureReason',
        'metadata': {
          'amount': baseCostUsd,
          'type': 'manual_refill',
          if (status == 'failed') 'failure_reason': failureReason,
        },
        'created_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to record manual topup execution: ${e.message}');
    }
  }

  @override
  Future<void> scheduleTopupExecution({
    required String simLineId,
    required double amount,
    required DateTime executionTime,
    required String executionType,
    String? offerId,
    int? offerValue,
    String? scheduledTopupId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user session found.');
      }

      await _supabase.from('topup_executions').insert({
        'sim_line_id': simLineId,
        'user_id': userId,
        'amount': amount,
        'base_cost_usd': amount,
        'currency': 'USD',
        'status': 'pending',
        'execution_type': executionType,
        'execution_time': executionTime.toIso8601String(),
        'executed_at': null,
        'offer_id': offerId,
        'offer_value': offerValue,
        'payment_gateway_code': null,
        'scheduled_topup_id': scheduledTopupId,
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to schedule topup execution: ${e.message}');
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
  Future<void> confirmLineVerification(String simLineId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user session found.');
      }

      // Update SIM Line verification_status and health score
      await _supabase
          .from('sim_lines')
          .update({
            'verification_status': 'verified',
            'health_score': 100,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', simLineId);

      // Insert verification log
      await _supabase.from('line_activity_log').insert({
        'sim_line_id': simLineId,
        'user_id': userId,
        'event_type': 'health_update',
        'description':
            'SIM line verified active via Twilio Missed Call check. Health optimized to 100.',
        'metadata': {
          'verified_at': DateTime.now().toIso8601String(),
          'channel': 'twilio_missed_call',
        },
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to confirm line verification: ${e.message}');
    }
  }

  @override
  Future<void> cancelCall(String callSid) async {
    await TwilioVerificationService.cancelCall(callSid);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchZenditOffers(String countryId, String carrierId) async {
    try {
      print('DEBUG: fetchZenditOffers called with countryId: $countryId, carrierId: $carrierId');
      // 1. Get Country ISO code
      print('DEBUG: Fetching country...');
      final countryRes = await _supabase
          .from('countries')
          .select('iso_code') // Using iso_code as per the Country model
          .eq('id', countryId)
          .single();
      final countryCode = countryRes['iso_code'] as String;
      print('DEBUG: Found countryCode: $countryCode');

      // 2. Get Carrier mapping
      print('DEBUG: Fetching carrier...');
      final carrierRes = await _supabase
          .from('carriers')
          .select('zen_carrier')
          .eq('id', carrierId)
          .single();
      final zenCarrier = carrierRes['zen_carrier'] as String?;
      print('DEBUG: Found zenCarrier: $zenCarrier');

      // 3. Invoke Edge Function
      print('DEBUG: Invoking fetch_zendit_offers edge function...');
      final response = await _supabase.functions.invoke(
        'fetch_zendit_offers',
        body: {
          'countryCode': countryCode,
          'zenCarrier': zenCarrier,
        },
      );
      print('DEBUG: Edge function response status: ${response.status}');

      if (response.status != 200) {
        throw Exception('Failed to fetch offers: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      final offers = data['offers'] as List<dynamic>;
      print('DEBUG: Successfully parsed ${offers.length} offers.');
      return offers.cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      print('DEBUG: PostgrestException: ${e.message}');
      throw Exception('Database error fetching mappings: ${e.message}');
    } catch (e, stackTrace) {
      print('DEBUG: General Exception: $e');
      print('DEBUG: StackTrace: $stackTrace');
      throw Exception('Error fetching Zendit offers: $e');
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
