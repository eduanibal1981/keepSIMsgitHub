/// KeepSIMs — Referrals Repository
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
  Future<Result<ReferralSummary>> getSummary() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      // 1. Fetch user's referral code from profile
      final profileRes = await _client
          .from('profiles')
          .select('referral_code')
          .eq('id', userId)
          .single();

      final referralCode = (profileRes['referral_code'] as String?) ?? '';

      // 2. Fetch point history where current user is referrer
      final pointsRes = await _client
          .from('referral_points')
          .select('*')
          .eq('referrer_id', userId)
          .order('created_at', ascending: false);

      final pointHistory = (pointsRes as List)
          .map((json) => ReferralPointEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      final totalPointsEarned = pointHistory.fold<int>(0, (sum, p) => sum + p.points);

      // 3. Fetch redemptions history for current user
      final redemptionsRes = await _client
          .from('referral_redemptions')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final redemptions = (redemptionsRes as List)
          .map((json) => ReferralRedemptionEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      final pointsSpent = redemptions.fold<int>(0, (sum, r) => sum + r.pointsSpent);

      final pointsBalance = (totalPointsEarned - pointsSpent).clamp(0, 999999);

      // 4. Fetch referred friends list
      final referralsRes = await _client
          .from('referrals')
          .select('*, referred_profile:profiles!referrals_referred_user_id_fkey(full_name, avatar_url)')
          .eq('referrer_id', userId)
          .order('created_at', ascending: false);

      final referredFriends = (referralsRes as List).map((json) {
        final profileMap = json['referred_profile'] as Map<String, dynamic>?;
        final name = profileMap?['full_name'] as String?;
        final avatar = profileMap?['avatar_url'] as String?;
        final itemMap = Map<String, dynamic>.from(json as Map);
        itemMap['display_name'] = name;
        itemMap['avatar_url'] = avatar;
        return ReferredFriend.fromJson(itemMap);
      }).toList();

      final summary = ReferralSummary(
        pointsBalance: pointsBalance,
        totalPointsEarned: totalPointsEarned,
        pointsSpent: pointsSpent,
        referralCode: referralCode,
        referredFriends: referredFriends,
        pointHistory: pointHistory,
        redemptions: redemptions,
      );

      return Success(summary);
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

      final res = await _client.rpc(
        'apply_referral',
        params: {'p_referred_id': userId, 'p_referral_code': referralCode},
      );

      if (res is Map && res['success'] == false) {
        final err = (res['error'] as String?) ?? 'Failed to apply referral code';
        return Failure(AppFailure.validation(message: err));
      }

      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.validation(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> redeemPoints() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final res = await _client.rpc('redeem_referral_points');
      final resultMap = Map<String, dynamic>.from(res as Map);

      return Success(resultMap);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.validation(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }
}
