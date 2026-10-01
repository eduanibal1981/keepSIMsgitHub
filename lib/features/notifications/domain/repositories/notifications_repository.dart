import 'package:keep_sims/features/notifications/data/models/notification_model.dart';
import 'package:keep_sims/features/notifications/data/models/alert_setting_model.dart';
import 'package:keep_sims/features/notifications/data/models/user_preferences_model.dart';

import 'package:keep_sims/features/notifications/domain/notification_event_catalog.dart';

abstract class NotificationsRepository {
  Future<List<AppNotification>> getNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
  Future<void> deleteNotification(String id);
  Future<void> clearAllNotifications();

  Future<List<AlertSetting>> getAlertSettings();
  Future<void> updateAlertSetting(AlertSetting setting);

  Future<UserPreferences> getUserPreferences();
  Future<bool> hasWeeklyDigestConsent();
  Future<void> updateUserPreferences(
    UserPreferences preferences, {
    bool? digestConsentChange,
  });

  Future<List<Map<String, dynamic>>> getNotificationChannels();
  Future<Map<String, Map<String, dynamic>>> getChannelCatalog();
  Future<void> updateNotificationChannel({
    required String channelType,
    required bool isEnabled,
    required Map<String, dynamic> config,
  });

  Future<void> simulateNotification(
    String category,
    String title,
    String body, {
    String? simLineId,
    int delayMinutes = 0,
  });

  Future<void> sendNotification({
    required String category,
    required String title,
    required String body,
    String? simLineId,
    String? channelType,
  });

  Future<void> emitEvent({
    required NotificationEventType eventType,
    required Map<String, dynamic> templateData,
    String? simLineId,
    String? sourceEventKey,
    DateTime? scheduledAt,
    DateTime? expiresAt,
    Map<String, dynamic>? target,
    String? language,
  });
}
