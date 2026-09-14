/// Remote Data Source for Return Trips & Packages
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/return_trip.dart';
import '../../domain/entities/return_trip_package.dart';
import '../../domain/entities/active_return_trip_info.dart';

class ReturnTripRemoteDataSource {
  final SupabaseClient _client;

  ReturnTripRemoteDataSource({required SupabaseClient client}) : _client = client;

  Future<List<ReturnTripPackage>> getPackagesForLine(String simLineId) async {
    final response = await _client.rpc(
      'get_return_trip_packages_for_line',
      params: {'p_sim_line_id': simLineId},
    );

    if (response == null || response is! List) {
      return [];
    }

    return response
        .map((e) => ReturnTripPackage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ReturnTrip?> getActiveTripForLine(String simLineId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('return_trips')
        .select()
        .eq('user_id', userId)
        .eq('sim_line_id', simLineId)
        .inFilter('status', ['planning', 'data_ready', 'arrived'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return ReturnTrip.fromJson(response);
  }

  Future<ActiveReturnTripInfo?> getActiveReturnTripInfo(String simLineId) async {
    final response = await _client.rpc(
      'get_active_return_trip_for_line',
      params: {'p_sim_line_id': simLineId},
    );

    if (response == null || response is! List || response.isEmpty) {
      return null;
    }

    final first = response.first;
    if (first == null || first is! Map) return null;
    return ActiveReturnTripInfo.fromJson(Map<String, dynamic>.from(first));
  }

  Future<List<ActiveReturnTripInfo>> getReturnTripHistory(String simLineId) async {
    final response = await _client.rpc(
      'get_return_trip_history_for_line',
      params: {'p_sim_line_id': simLineId},
    );

    if (response == null || response is! List) {
      return [];
    }

    return response
        .where((e) => e != null && e is Map)
        .map((e) => ActiveReturnTripInfo.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ReturnTrip> saveReturnTrip({
    required String simLineId,
    required String destinationCountryId,
    required DateTime arrivalDate,
    required String status,
    String? chosenPackageType,
    String? chosenPackageId,
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('User must be authenticated to save a return trip');
    }

    final payload = {
      'user_id': userId,
      'sim_line_id': simLineId,
      'destination_country_id': destinationCountryId,
      'arrival_date': arrivalDate.toIso8601String().split('T').first,
      'status': status,
      'chosen_package_type': chosenPackageType,
      'chosen_package_id': chosenPackageId,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Check if an active future/today trip already exists for this line
    final existing = await getActiveTripForLine(simLineId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isExistingActive = existing != null &&
        !existing.arrivalDate.isBefore(today) &&
        existing.status != 'completed' &&
        existing.status != 'cancelled';

    Map<String, dynamic> result;

    if (isExistingActive) {
      result = await _client
          .from('return_trips')
          .update(payload)
          .eq('id', existing.id)
          .select()
          .single();
    } else {
      result = await _client
          .from('return_trips')
          .insert(payload)
          .select()
          .single();
    }

    return ReturnTrip.fromJson(result);
  }

  Future<void> cancelTrip(String tripId) async {
    await _client
        .from('return_trips')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', tripId);
  }

  Future<void> updateArrivalDate(String tripId, DateTime newArrivalDate) async {
    await _client
        .from('return_trips')
        .update({
          'arrival_date': newArrivalDate.toIso8601String().split('T').first,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', tripId);
  }
}
