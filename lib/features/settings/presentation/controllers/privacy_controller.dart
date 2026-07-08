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
  static const String _kTrackingConsentKey =
      'analytics_tracking_consent_enabled';

  @override
  FutureOr<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kTrackingConsentKey) ??
        true; // Default true or false based on policy
  }

  Future<void> toggleTrackingConsent(bool value) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kTrackingConsentKey, value);
      // In a real app, you would also toggle the analytics SDK here
      // e.g., FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(value);
      return value;
    });
  }

  Future<void> exportData() async {
    try {
      final user = ref.read(authControllerProvider).value;
      if (user == null) throw const UserFriendlyException('User not authenticated.');

      // In a comprehensive export, we would fetch all related tables.
      // Here we export the current user profile as JSON.
      final userData = {
        'profile': user.toJson(),
        'export_date': DateTime.now().toIso8601String(),
        'tracking_consent': state.value,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(userData);

      // Write to a temporary file
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/keepsims_data_export.json');
      await file.writeAsString(jsonString);

      // Share the file
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')]);
    } catch (e) {
      throw UserFriendlyException('Failed to export data: $e');
    }
  }

  Future<void> deleteAccount() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw const UserFriendlyException('User not authenticated.');
    }

    try {
      // Call the Supabase Edge Function to delete the account
      final response = await supabase.functions.invoke(
        'delete_account',
        method: HttpMethod.post,
      );

      if (response.status == 200 ||
          response.status == 201 ||
          response.status == 204) {
        // Function succeeded. Sign out locally.
        await ref.read(authControllerProvider.notifier).signOut();
      } else {
        throw const UserFriendlyException(
          'Failed to delete account. Please contact support.',
        );
      }
    } catch (e) {
      throw UserFriendlyException('Error deleting account: $e');
    }
  }
}
