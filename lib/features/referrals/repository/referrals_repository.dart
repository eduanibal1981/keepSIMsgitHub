/// SIM Shield — Referrals Repository
///
/// Implements [ReferralsContract] using Supabase.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import '../contract/referrals_contract.dart';
import '../model/referral_model.dart';

class ReferralsRepository implements ReferralsContract {
  final SupabaseClient _client;

  ReferralsRepository(this._client);

  @override
  Future<Result<List<Referral>>> getReferrals() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      // Fetch referrals where current user is the referrer, joining the referred profile details
      final response = await _client
          .from('referrals')
          .select('*, referred_profile:profiles!referrals_referred_id_fkey(*)')
          .eq('referrer_id', userId)
          .order('created_at', ascending: false);

      final referralsList = (response as List)
          .map((json) => Referral.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(referralsList);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> applyReferral(String referralCode) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      // Execute atomic postgres transaction via RPC
      await _client.rpc(
        'apply_referral',
        params: {'p_referred_id': userId, 'p_referral_code': referralCode},
      );

      return const Success(null);
    } on PostgrestException catch (e) {
      // Map Postgrest validation exceptions (self-referral, invalid code)
      return Failure(AppFailure.validation(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }
}
