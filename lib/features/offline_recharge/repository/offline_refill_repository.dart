import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import '../contract/offline_refill_contract.dart';
import '../model/offline_refill_model.dart';

class OfflineRefillRepository implements OfflineRefillContract {
  final SupabaseClient _client;
  final LocalCacheService _cache;
  final ConnectivityService _connectivity;

  OfflineRefillRepository(this._client, this._cache, this._connectivity);

  @override
  Future<Result<OfflineRefillSettings>> getSettings() async {
    const cacheKey = 'cached_offline_refill_settings';

    if (_connectivity.isOffline) {
      final cached = _cache.readJson(cacheKey);
      if (cached != null) {
        return Success(
          OfflineRefillSettings.fromJson(cached as Map<String, dynamic>),
        );
      }
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        final mockSettings = OfflineRefillSettings(
          userId: userId,
          isEnabled: true,
          defaultRefillAmount: 10.00,
        );
        return Success(mockSettings);
      }
      return const Failure(
        AppFailure.auth(message: 'No internet connection and not logged in.'),
      );
    }

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

        await _cache.writeJson(cacheKey, response);
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
          await _cache.writeJson(cacheKey, inserted);
          return Success(OfflineRefillSettings.fromJson(inserted));
        }
        final cached = _cache.readJson(cacheKey);
        if (cached != null) {
          return Success(
            OfflineRefillSettings.fromJson(cached as Map<String, dynamic>),
          );
        }
        return Failure(AppFailure.server(message: e.message));
      }
    } catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached != null) {
        return Success(
          OfflineRefillSettings.fromJson(cached as Map<String, dynamic>),
        );
      }
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup')) {
        return const Failure(AppFailure.network());
      }
      return Failure(AppFailure.unknown(message: errStr));
    }
  }

  @override
  Future<Result<OfflineRefillSettings>> saveSettings(
    OfflineRefillSettings settings,
  ) async {
    const cacheKey = 'cached_offline_refill_settings';
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

      if (_connectivity.isOffline) {
        await _cache.writeJson(cacheKey, data);
        return Success(settings);
      }

      // Upsert
      final response = await _client
          .from('offline_refill_settings')
          .upsert(data)
          .select()
          .single();

      await _cache.writeJson(cacheKey, response);
      return Success(OfflineRefillSettings.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup')) {
        return const Failure(AppFailure.network());
      }
      return Failure(AppFailure.unknown(message: errStr));
    }
  }

  @override
  Future<Result<List<CarrierUssdSuggestion>>> getUssdSuggestions(
    String carrierId,
  ) async {
    final cacheKey = 'cached_ussd_suggestions_$carrierId';

    if (_connectivity.isOffline) {
      final cached = _cache.readJson(cacheKey);
      if (cached is List) {
        return Success(
          cached
              .map(
                (json) => CarrierUssdSuggestion.fromJson(
                  json as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
      }
      return const Success([]);
    }

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

      await _cache.writeJson(cacheKey, response);
      return Success(list);
    } on PostgrestException catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached is List) {
        return Success(
          cached
              .map(
                (json) => CarrierUssdSuggestion.fromJson(
                  json as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
      }
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached is List) {
        return Success(
          cached
              .map(
                (json) => CarrierUssdSuggestion.fromJson(
                  json as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
      }
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup')) {
        return const Failure(AppFailure.network());
      }
      return Failure(AppFailure.unknown(message: errStr));
    }
  }
}
