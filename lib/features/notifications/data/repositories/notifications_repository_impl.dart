import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/notifications/data/models/notification_model.dart';
import 'package:keep_sims/features/notifications/data/models/alert_setting_model.dart';
import 'package:keep_sims/features/notifications/data/models/user_preferences_model.dart';
import 'package:keep_sims/features/notifications/domain/repositories/notifications_repository.dart';

part 'notifications_repository_impl.g.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final SupabaseClient _supabase;

  NotificationsRepositoryImpl({required SupabaseClient supabase})
    : _supabase = supabase;

  String get _currentUserId {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User is not authenticated.');
    }
    return userId;
  }

  @override
  Future<List<AppNotification>> getNotifications() async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', _currentUserId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load notifications: ${e.message}');
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to mark notification as read: ${e.message}');
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _currentUserId)
          .eq('is_read', false);
    } on PostgrestException catch (e) {
      throw Exception('Failed to mark all notifications as read: ${e.message}');
    }
  }

  @override
  Future<void> deleteNotification(String id) async {
    try {
      await _supabase.from('notifications').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete notification: ${e.message}');
    }
  }

  @override
  Future<void> clearAllNotifications() async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', _currentUserId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to clear notifications: ${e.message}');
    }
  }

  @override
  Future<List<AlertSetting>> getAlertSettings() async {
    try {
      final userId = _currentUserId;
      final response = await _supabase
          .from('alert_settings')
          .select()
          .eq('user_id', userId);

      if ((response as List).isEmpty) {
        // Seed default alert settings
        final categories = [
          'top_up_success',
          'top_up_failed',
          'wallet_low',
          'wallet_depleted',
          'line_critical',
          'line_entering_grace',
          'geo_fence_triggered',
          'welcome_home_ready',
          'referral_reward',
          'system',
        ];

        final rows = categories
            .map(
              (cat) => {
                'user_id': userId,
                'category': cat,
                'is_enabled': true,
                'channels': ['push'],
              },
            )
            .toList();

        await _supabase.from('alert_settings').insert(rows);

        // Re-fetch alert settings
        final reResponse = await _supabase
            .from('alert_settings')
            .select()
            .eq('user_id', userId);

        return (reResponse as List)
            .map((json) => AlertSetting.fromJson(json))
            .toList();
      }

      return (response as List)
          .map((json) => AlertSetting.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load alert settings: ${e.message}');
    }
  }

  @override
  Future<void> updateAlertSetting(AlertSetting setting) async {
    try {
      await _supabase
          .from('alert_settings')
          .update({
            'is_enabled': setting.isEnabled,
            'channels': setting.channels,
          })
          .eq('id', setting.id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update alert setting: ${e.message}');
    }
  }

  @override
  Future<UserPreferences> getUserPreferences() async {
    try {
      final userId = _currentUserId;
      final response = await _supabase
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Seed default preferences
        final inserted = await _supabase
            .from('user_preferences')
            .insert({
              'user_id': userId,
              'quiet_hours_start': '22:00:00',
              'quiet_hours_end': '07:00:00',
              'weekly_digest_enabled': true,
              'theme': 'system',
              'language': 'en',
            })
            .select()
            .single();

        return UserPreferences.fromJson(inserted);
      }

      return UserPreferences.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to load user preferences: ${e.message}');
    }
  }

  @override
  Future<void> updateUserPreferences(UserPreferences preferences) async {
    try {
      await _supabase
          .from('user_preferences')
          .update(preferences.toJson())
          .eq('id', preferences.id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update user preferences: ${e.message}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getNotificationChannels() async {
    try {
      final userId = _currentUserId;
      final response = await _supabase
          .from('notification_channels')
          .select()
          .eq('user_id', userId);

      final existingChannels = List<Map<String, dynamic>>.from(
        response as List,
      );
      final existingTypes = existingChannels
          .map((c) => c['channel_type'] as String)
          .toSet();

      // Temporarily disabled webhook for MVP:
      // final defaultTypes = ['push', 'email', 'telegram', 'whatsapp', 'webhook'];
      final defaultTypes = ['push', 'email', 'telegram', 'whatsapp'];
      final missingTypes = defaultTypes
          .where((t) => !existingTypes.contains(t))
          .toList();

      if (missingTypes.isNotEmpty) {
        final newChannels = missingTypes
            .map(
              (type) => {
                'user_id': userId,
                'channel_type': type,
                'is_enabled': type == 'push',
                'config': {},
              },
            )
            .toList();

        final inserted = await _supabase
            .from('notification_channels')
            .insert(newChannels)
            .select();

        existingChannels.addAll(
          List<Map<String, dynamic>>.from(inserted as List),
        );
      }

      // Filter out webhook so it doesn't show in the UI for existing users who already have the row
      final filteredChannels = existingChannels
          .where((c) => c['channel_type'] != 'webhook')
          .toList();

      return filteredChannels;
    } on PostgrestException catch (e) {
      throw Exception('Failed to load notification channels: ${e.message}');
    }
  }

  @override
  Future<void> updateNotificationChannel({
    required String channelType,
    required bool isEnabled,
    required Map<String, dynamic> config,
  }) async {
    try {
      final userId = _currentUserId;

      // Upsert the channel configuration
      await _supabase.from('notification_channels').upsert({
        'user_id': userId,
        'channel_type': channelType,
        'is_enabled': isEnabled,
        'config': config,
      }, onConflict: 'user_id, channel_type');
    } on PostgrestException catch (e) {
      throw Exception('Failed to update notification channel: ${e.message}');
    }
  }

  @override
  Future<void> simulateNotification(
    String category,
    String title,
    String body, {
    String? simLineId,
    int delayMinutes = 0,
  }) async {
    try {
      if (delayMinutes > 0) {
        await _supabase.rpc(
          'schedule_delayed_notification',
          params: {
            'p_user_id': _currentUserId,
            'p_category': category,
            'p_title': title,
            'p_body': body,
            'p_delay_minutes': delayMinutes,
          },
        );
      } else {
        await _supabase.from('notifications').insert({
          'user_id': _currentUserId,
          'category': category,
          'title': title,
          'body': body,
          'is_read': false,
          'action_url': simLineId != null ? '/sim_lines/$simLineId' : null,
          'sim_line_id': simLineId,
          'delivered_via': ['push'],
        });
      }
    } on PostgrestException catch (e) {
      throw Exception('Failed to simulate notification: ${e.message}');
    }
  }
}

@riverpod
NotificationsRepository notificationsRepository(
  NotificationsRepositoryRef ref,
) {
  return NotificationsRepositoryImpl(supabase: Supabase.instance.client);
}
