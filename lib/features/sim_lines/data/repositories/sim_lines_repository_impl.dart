import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_activity_log_model.dart';
import 'package:keep_sims/features/sim_lines/domain/repositories/sim_lines_repository.dart';
import 'package:keep_sims/features/sim_lines/data/datasources/twilio_verification_service.dart';

part 'sim_lines_repository_impl.g.dart';

class SimLinesRepositoryImpl implements SimLinesRepository {
  final SupabaseClient _supabase;

  SimLinesRepositoryImpl({required SupabaseClient supabase})
    : _supabase = supabase;

  @override
  Future<List<SimLine>> getSimLines() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null)
        throw Exception('No authenticated user session found.');

      final response = await _supabase
          .from('sim_lines')
          .select()
          .order('created_at', ascending: false)
          .order('id', ascending: true);

      return (response as List)
          .map((json) => SimLine.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load SIM lines: ${e.message}');
    }
  }

  @override
  Future<SimLine> addSimLine(SimLine line) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null)
        throw Exception('No authenticated user session found.');

      final data = line.toJson();
      if (line.id.isEmpty) {
        data.remove('id');
      }
      data['user_id'] = userId;

      final response = await _supabase
          .from('sim_lines')
          .insert(data)
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

      // 2. Seed Mock Logs for testing (Successful Top-up, Failed Top-up, Health Score Update)
      final now = DateTime.now();

      // Success execution
      await _supabase.from('topup_executions').insert({
        'sim_line_id': createdLine.id,
        'user_id': userId,
        'amount': 10.00,
        'currency': 'USD',
        'status': 'success',
        'reloadly_transaction_id':
            'MOCK_TX_SUCCESS_${createdLine.id.substring(0, 4)}',
        'executed_at': now.subtract(const Duration(days: 30)).toIso8601String(),
        'completed_at': now
            .subtract(const Duration(days: 30))
            .toIso8601String(),
      });

      await _supabase.from('line_activity_log').insert({
        'sim_line_id': createdLine.id,
        'user_id': userId,
        'event_type': 'topup_success',
        'description':
            'Mock successful auto-renewal top-up of \$10.00 completed.',
        'metadata': {
          'is_mock': true,
          'amount': 10.00,
          'transaction_id': 'MOCK_TX_SUCCESS',
        },
        'created_at': now.subtract(const Duration(days: 30)).toIso8601String(),
      });

      // Failure execution
      await _supabase.from('topup_executions').insert({
        'sim_line_id': createdLine.id,
        'user_id': userId,
        'amount': 15.00,
        'currency': 'USD',
        'status': 'failed',
        'failure_reason': 'Insufficient wallet balance',
        'reloadly_transaction_id':
            'MOCK_TX_FAILED_${createdLine.id.substring(0, 4)}',
        'executed_at': now.subtract(const Duration(days: 15)).toIso8601String(),
        'completed_at': now
            .subtract(const Duration(days: 15))
            .toIso8601String(),
      });

      await _supabase.from('line_activity_log').insert({
        'sim_line_id': createdLine.id,
        'user_id': userId,
        'event_type': 'topup_failed',
        'description':
            'Mock top-up renewal of \$15.00 failed: Insufficient wallet balance.',
        'metadata': {
          'is_mock': true,
          'amount': 15.00,
          'failure_reason': 'Insufficient wallet balance',
        },
        'created_at': now.subtract(const Duration(days: 15)).toIso8601String(),
      });

      // Health update activity log
      await _supabase.from('line_activity_log').insert({
        'sim_line_id': createdLine.id,
        'user_id': userId,
        'event_type': 'health_update',
        'description':
            'Mock health score optimized from 85 to 100 after successful auto-renewal configuration.',
        'metadata': {'is_mock': true, 'old_score': 85, 'new_score': 100},
        'created_at': now.subtract(const Duration(days: 5)).toIso8601String(),
      });

      return createdLine;
    } on PostgrestException catch (e) {
      throw Exception('Failed to add SIM line: ${e.message}');
    }
  }

  @override
  Future<SimLine> updateSimLine(SimLine line) async {
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
    try {
      await _supabase.from('sim_lines').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete SIM line: ${e.message}');
    }
  }

  @override
  Future<List<Country>> getSupportedCountries() async {
    try {
      final response = await _supabase
          .from('countries')
          .select()
          .eq('is_supported', true)
          .order('name', ascending: true);

      final countries = (response as List)
          .map((json) => Country.fromJson(json as Map<String, dynamic>))
          .toList();

      const preferredOrder = [
        'Egypt',
        'India',
        'Pakistan',
        'Bangladesh',
        'Philippines',
        'Syria',
        'Lebanon',
        'Sudan',
        'Yemen',
        'Turkey',
        'Jordan',
        'Tunisia',
        'Morocco',
        'Algeria',
      ];

      countries.sort((a, b) {
        final aIndex = preferredOrder.indexOf(a.name);
        final bIndex = preferredOrder.indexOf(b.name);
        if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
        if (aIndex != -1) return -1;
        if (bIndex != -1) return 1;
        return a.name.compareTo(b.name);
      });

      return countries;
    } on PostgrestException catch (e) {
      throw Exception('Failed to load countries: ${e.message}');
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
  Future<List<LineActivityLog>> getLineActivityLogs(String simLineId) async {
    try {
      final response = await _supabase
          .from('line_activity_log')
          .select()
          .eq('sim_line_id', simLineId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => LineActivityLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load line activity logs: ${e.message}');
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

      // 2. Delete mock logs from line_activity_log (where is_mock is true in metadata JSON)
      // For cross-database safety, we can delete logs that contain mock descriptors or where metadata->>is_mock = 'true'
      await _supabase
          .from('line_activity_log')
          .delete()
          .eq('sim_line_id', simLineId)
          .eq('metadata->is_mock', true);
    } on PostgrestException catch (e) {
      throw Exception('Failed to clean mock logs: ${e.message}');
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
      if (userId == null)
        throw Exception('No authenticated user session found.');

      // Update SIM Line status and health score
      await _supabase
          .from('sim_lines')
          .update({
            'status': 'active',
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
}

@riverpod
SimLinesRepository simLinesRepository(SimLinesRepositoryRef ref) {
  return SimLinesRepositoryImpl(supabase: Supabase.instance.client);
}
