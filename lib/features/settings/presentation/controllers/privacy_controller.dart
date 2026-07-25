import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/core/failure.dart';

part 'privacy_controller.g.dart';

@riverpod
class PrivacyController extends _$PrivacyController {
  static const String _kTrackingConsentKey = 'analytics_tracking_consent_enabled';

  @override
  FutureOr<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    // Default consent is FALSE per GDPR/privacy compliance
    return prefs.getBool(_kTrackingConsentKey) ?? false;
  }

  Future<void> toggleTrackingConsent(bool value) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kTrackingConsentKey, value);

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        try {
          await supabase.from('alert_settings').upsert({
            'user_id': userId,
            'category': 'analytics_consent',
            'is_enabled': value,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id, category');
        } catch (_) {
          // Ignore if table schema differs
        }
      }

      return value;
    });
  }

  Future<void> exportData() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const UserFriendlyException('User not authenticated.');
    }

    try {
      final response = await supabase.rpc('export_user_data');
      final jsonString = const JsonEncoder.withIndent('  ').convert(response);

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/keepsims_gdpr_data_export.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')]);
    } catch (e) {
      throw UserFriendlyException('Failed to export data: $e');
    }
  }

  Future<Map<String, dynamic>> deleteAccount({String? reason, bool forfeitDust = false}) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw const UserFriendlyException('User not authenticated.');
    }

    try {
      final response = await supabase.functions.invoke(
        'delete_account',
        method: HttpMethod.post,
        body: {
          'reason': reason,
          'forfeit_dust': forfeitDust,
        },
      );

      if (response.status == 200 || response.status == 201) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          await ref.read(authControllerProvider.notifier).signOut();
          return data;
        } else {
          final err = data['error'] as String? ?? 'Failed to request account deletion.';
          throw UserFriendlyException(err);
        }
      } else {
        final err = (response.data is Map && response.data['error'] != null)
            ? response.data['error'].toString()
            : 'Failed to delete account. Please contact support.';
        throw UserFriendlyException(err);
      }
    } catch (e) {
      throw UserFriendlyException(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> cancelAccountDeletion() async {
    final supabase = Supabase.instance.client;
    try {
      final res = await supabase.rpc('cancel_account_deletion');
      if (res is Map && res['success'] == false) {
        throw UserFriendlyException(res['error']?.toString() ?? 'Failed to cancel deletion');
      }
    } catch (e) {
      throw UserFriendlyException('Failed to cancel deletion: $e');
    }
  }
}
