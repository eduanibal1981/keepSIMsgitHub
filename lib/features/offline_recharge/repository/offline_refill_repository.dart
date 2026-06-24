import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import '../contract/offline_refill_contract.dart';
import '../model/offline_refill_model.dart';

class OfflineRefillRepository implements OfflineRefillContract {
  final SupabaseClient _client;

  OfflineRefillRepository(this._client);

  @override
  Future<Result<OfflineRefillSettings>> getSettings() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      try {
        final response = await _client
            .from('offline_refill_settings')
            .select()
            .eq('user_id', userId)
            .single();

        return Success(OfflineRefillSettings.fromJson(response));
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST116') {
          // Dynamic initial settings if none exist
          final newSettings = {
            'user_id': userId,
            'is_enabled': true,
            'default_refill_amount': 10.00,
          };
          // Insert into Supabase
          final inserted = await _client
              .from('offline_refill_settings')
              .insert(newSettings)
              .select()
              .single();
          return Success(OfflineRefillSettings.fromJson(inserted));
        }
        return Failure(AppFailure.server(message: e.message));
      }
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<OfflineRefillSettings>> saveSettings(
    OfflineRefillSettings settings,
  ) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final data = settings
          .copyWith(userId: userId, updatedAt: DateTime.now())
          .toJson();

      // Upsert
      final response = await _client
          .from('offline_refill_settings')
          .upsert(data)
          .select()
          .single();

      return Success(OfflineRefillSettings.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<List<CarrierUssdSuggestion>>> getUssdSuggestions(
    String carrierId,
  ) async {
    try {
      final response = await _client
          .from('carrier_ussd_suggestions')
          .select()
          .eq('carrier_id', carrierId);

      final list = (response as List)
          .map(
            (json) =>
                CarrierUssdSuggestion.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      return Success(list);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }
}
