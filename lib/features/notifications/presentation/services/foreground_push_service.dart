import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Android renders background FCM messages itself. Only foreground fallback
/// messages come through this bridge; OneSignal retains its own renderer.
class ForegroundPushService {
  static const _channel = MethodChannel('com.keep_sims/notifications');
  final Set<String> _shown = {};

  Future<void> initialize(void Function(Map<String, dynamic>) onTap) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    void handle(dynamic value) {
      if (value is String) onTap(Map<String, dynamic>.from(jsonDecode(value) as Map));
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'notificationTap') handle(call.arguments);
    });
    try {
      handle(await _channel.invokeMethod<String>('getInitialTap'));
      await trimBacklog();
    } catch (error) {
      debugPrint('[ForegroundPush] Initial tap unavailable: $error');
    }
  }

  Future<void> trimBacklog() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final ids = await _channel.invokeListMethod<int>('trimBacklog');
      if ((ids?.length ?? 0) >= 20) {
        // 40+ cards is a legacy overflow. Clear the SDK's restoration cache as
        // well as its tray cards; the in-app inbox is independent and retained.
        await OneSignal.Notifications.clearAll();
        return;
      }
      for (final id in ids ?? <int>[]) {
        await OneSignal.Notifications.removeNotification(id);
      }
    } catch (error) {
      debugPrint('[ForegroundPush] Backlog cleanup failed: $error');
    }
  }

  void showOneSignal(OSNotificationWillDisplayEvent event) {
    // Pause automatic display synchronously while making room, then explicitly
    // display exactly once. Never combine display() with automatic display.
    event.preventDefault();
    _showOneSignalAfterCleanup(event);
  }

  Future<void> _showOneSignalAfterCleanup(OSNotificationWillDisplayEvent event) async {
    await trimBacklog();
    event.notification.display();
  }

  Future<void> show(RemoteMessage message) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    // OneSignal messages also traverse Firebase. Never render those twice.
    if (message.data.containsKey('custom') || message.data.containsKey('os_data')) return;
    final notification = message.notification;
    if (notification == null) return;
    final id = message.data['notification_id']?.toString();
    final key = (id != null && id.isNotEmpty) ? id : message.messageId;
    if (key == null || !_shown.add(key)) return;
    if (_shown.length > 100) _shown.remove(_shown.first);
    try {
      await trimBacklog();
      await _channel.invokeMethod<void>('showForeground', {
        'id': key,
        'title': notification.title,
        'body': notification.body,
        'data': message.data,
        'channel_id': notification.android?.channelId ?? 'ks_updates_v1',
      });
    } catch (error) {
      _shown.remove(key);
      debugPrint('[ForegroundPush] Display failed: $error');
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _shown.clear();
  }
}
