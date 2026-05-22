import 'package:keep_sims/features/notifications/data/models/notification_model.dart';
import 'package:keep_sims/features/notifications/data/models/alert_setting_model.dart';
import 'package:keep_sims/features/notifications/data/models/user_preferences_model.dart';

abstract class NotificationsRepository {
  Future<List<AppNotification>> getNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
  Future<void> deleteNotification(String id);
  Future<void> clearAllNotifications();

  Future<List<AlertSetting>> getAlertSettings();
  Future<void> updateAlertSetting(AlertSetting setting);

  Future<UserPreferences> getUserPreferences();
  Future<void> updateUserPreferences(UserPreferences preferences);

  Future<void> simulateNotification(
    String category,
    String title,
    String body, {
    String? simLineId,
  });
}
