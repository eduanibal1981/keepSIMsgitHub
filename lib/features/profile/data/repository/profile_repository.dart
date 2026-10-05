/// SIM Shield — Profile Repository
///
/// Concrete implementation of [ProfileContract] using Supabase.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/profile/domain/contract/profile_contract.dart';
import 'package:keep_sims/features/profile/domain/models/notification_email_status.dart';

class ProfileRepository implements ProfileContract {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<NotificationEmailStatus>> getNotificationEmailStatus() async {
    try {
      final response = await _client.functions
          .invoke(
            'notification-email-verification',
            body: const {'action': 'status'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.status != 200 || response.data is! Map) {
        return const Failure(
          AppFailure.server(
            message: 'Could not load notification email verification.',
          ),
        );
      }
      return Success(
        NotificationEmailStatus.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        ),
      );
    } catch (_) {
      return const Failure(AppFailure.network());
    }
  }

  @override
  Future<Result<UserProfile>> updateProfileDetails(UserProfile profile) async {
    try {
      final response = await _client
          .from('profiles')
          .update(profile.toDetailsWritableJson())
          .eq('id', profile.id)
          .select()
          .single();
      return Success(UserProfile.fromJson(response));
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Failure(
          AppFailure.notFound(message: 'Profile not found.'),
        );
      }
      return Failure(AppFailure.server(message: e.message));
    } catch (_) {
      return const Failure(AppFailure.network());
    }
  }

  @override
  Future<Result<UserProfile>> getProfile(String id) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', id)
          .single();

      return Success(UserProfile.fromJson(response));
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Failure(
          AppFailure.notFound(message: 'Profile not found.'),
        );
      }
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<UserProfile>> updateProfile(UserProfile profile) async {
    try {
      final response = await _client
          .from('profiles')
          .update(profile.toClientWritableJson())
          .eq('id', profile.id)
          .select()
          .single();

      return Success(UserProfile.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }
}
