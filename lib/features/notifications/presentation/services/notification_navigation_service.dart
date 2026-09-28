import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'foreground_push_service.dart';

class NotificationTapPayload {
  final String? notificationId;
  final String? simLineId;
  final String? actionUrl;
  final String? eventType;
  final Map<String, dynamic>? target;

  NotificationTapPayload({
    this.notificationId,
    this.simLineId,
    this.actionUrl,
    this.eventType,
    this.target,
  });

  factory NotificationTapPayload.fromMap(Map<dynamic, dynamic>? raw) {
    if (raw == null) return NotificationTapPayload();
    final map = Map<String, dynamic>.from(raw);
    dynamic target = map['target'];
    if (target is String && target.isNotEmpty) {
      try {
        target = jsonDecode(target);
      } catch (_) {
        target = null;
      }
    }
    return NotificationTapPayload(
      notificationId: map['notification_id']?.toString(),
      simLineId: map['sim_line_id']?.toString(),
      actionUrl: map['action_url']?.toString(),
      eventType: map['event_type']?.toString(),
      target: target is Map
          ? Map<String, dynamic>.from(target)
          : null,
    );
  }
}

/// App-scoped service that handles notification taps from OneSignal and FCM.
class NotificationNavigationService {
  final Ref _ref;
  NotificationTapPayload? _pendingTap;
  bool _isListening = false;
  StreamSubscription<RemoteMessage>? _fcmSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  final _foregroundPush = ForegroundPushService();
  void _clickListener(OSNotificationClickEvent event) {
    _handleTap(NotificationTapPayload.fromMap(event.notification.additionalData));
  }

  NotificationNavigationService(this._ref);

  void initialize() {
    if (_isListening) return;
    _isListening = true;

    // 1. OneSignal notification click listener
    OneSignal.Notifications.addClickListener(_clickListener);

    // Make room before OneSignal displays once. Quiet channels control sound
    // and heads-up behavior without discarding confirmations.
    OneSignal.Notifications.addForegroundWillDisplayListener(_foregroundPush.showOneSignal);
    unawaited(_foregroundPush.initialize((data) {
      _handleTap(NotificationTapPayload.fromMap(data));
    }));

    // 3. FCM background tap listener
    try {
      _foregroundSub = FirebaseMessaging.onMessage.listen(_foregroundPush.show);
      _fcmSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleTap(NotificationTapPayload.fromMap(message.data));
      });

      // 4. FCM cold-start tap check
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          _handleTap(NotificationTapPayload.fromMap(message.data));
        }
      });
    } catch (e) {
      debugPrint('[NotificationNavigationService] FCM listeners skipped: $e');
    }

    // 5. Watch auth state to drain pending taps when user is authenticated
    _ref.listen(authControllerProvider, (previous, next) {
      final profile = next.value;
      if (profile != null && _pendingTap != null) {
        flushPendingTap();
      } else if (profile == null) {
        _pendingTap = null; // Clear on logout
      }
    });
  }

  void _handleTap(NotificationTapPayload payload) {
    // Mark as read idempotently
    if (payload.notificationId != null &&
        payload.notificationId!.trim().isNotEmpty) {
      try {
        _ref
            .read(notificationsRepositoryProvider)
            .markAsRead(payload.notificationId!);
      } catch (e) {
        debugPrint('[NotificationNavigationService] markAsRead error: $e');
      }
    }

    final auth = _ref.read(authControllerProvider);
    if (auth.value == null) {
      // Queue tap until authenticated
      _pendingTap = payload;
      return;
    }

    final destination = resolveDestination(payload);
    _navigate(destination);
  }

  /// Flushes any queued cold-start tap once the user is signed in.
  void flushPendingTap() {
    final pending = _pendingTap;
    _pendingTap = null;
    if (pending != null) {
      final destination = resolveDestination(pending);
      _navigate(destination);
    }
  }

  void _navigate(String destination) {
    try {
      final router = _ref.read(appRouterProvider);
      if (router is GoRouter) {
        router.push(destination);
      }
    } catch (e) {
      debugPrint('[NotificationNavigationService] Navigation failed: $e');
    }
  }

  /// Resolves any notification payload into an allowlisted, safe app destination.
  static String resolveDestination(NotificationTapPayload payload) {
    // 1. Line ID direct route
    if (payload.simLineId != null && payload.simLineId!.trim().isNotEmpty) {
      return '/sim-lines/detail/${payload.simLineId!.trim()}';
    }

    // 2. Structured target route
    if (payload.target != null) {
      final route = payload.target!['route']?.toString().trim();
      final id = payload.target!['id']?.toString().trim();
      if (route != null && route.isNotEmpty) {
        if (route.contains(':id') && id != null) {
          return route.replaceAll(':id', id);
        }
        if (_isAllowlistedRoute(route)) {
          return route;
        }
      }
    }

    // 3. Action URL canonicalization
    final rawUrl = payload.actionUrl?.trim();
    if (rawUrl != null && rawUrl.isNotEmpty) {
      // Legacy /sim_lines/:id mapping
      final legacyMatch =
          RegExp(r'^/sim_lines/([a-zA-Z0-9_-]+)').firstMatch(rawUrl);
      if (legacyMatch != null) {
        return '/sim-lines/detail/${legacyMatch.group(1)}';
      }

      // Canonical /sim-lines/detail/:id
      if (rawUrl.startsWith('/sim-lines/detail/')) {
        return rawUrl;
      }

      if (_isAllowlistedRoute(rawUrl)) {
        return rawUrl;
      }
    }

    // 4. Safe fallback: open Notifications screen
    return '/notifications';
  }

  static bool _isAllowlistedRoute(String route) {
    const allowlist = {
      '/sim-lines',
      '/wallet',
      '/notifications',
      '/settings',
      '/settings/preferences',
    };
    return allowlist.contains(route);
  }

  void dispose() {
    OneSignal.Notifications.removeClickListener(_clickListener);
    OneSignal.Notifications.removeForegroundWillDisplayListener(_foregroundPush.showOneSignal);
    _foregroundSub?.cancel();
    _foregroundSub = null;
    _foregroundPush.dispose();
    _fcmSub?.cancel();
    _fcmSub = null;
    _isListening = false;
  }
}

final notificationNavigationServiceProvider =
    Provider<NotificationNavigationService>((ref) {
  final service = NotificationNavigationService(ref);
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});
