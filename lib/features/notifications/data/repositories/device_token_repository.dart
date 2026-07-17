import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'device_token_repository.g.dart';

/// Registers this device's push identifiers in `device_push_tokens` so the
/// server-side dispatcher (dispatch-alert) can target it.
///
/// OneSignal delivery uses the `external_id` alias (= user id), but we also
/// persist the OneSignal subscription id per device for debugging and future
/// direct targeting. The raw FCM token is what the dispatcher's FCM fallback
/// sends to when OneSignal is unreachable.
///
/// This deliberately registers no FirebaseMessaging message handlers: OneSignal
/// owns notification display, and we only need Firebase for the token. FCM
/// fallback messages carry a `notification` payload, so Android renders them
/// from the system tray without routing through a Dart handler.
class DeviceTokenRepository {
  DeviceTokenRepository({required SupabaseClient supabase})
    : _supabase = supabase;

  final SupabaseClient _supabase;

  static const _deviceIdKey = 'keepsims_device_id';
  bool _observerAttached = false;
  StreamSubscription<String>? _fcmRefreshSub;

  /// Upserts this device's identifiers for [userId]. Safe to call repeatedly.
  /// Also attaches one-time listeners so identifiers that only become available
  /// later — a OneSignal subscription id after the user grants push permission,
  /// or a rotated FCM token — are captured.
  Future<void> registerCurrentDevice(String userId) async {
    await _upsert(userId);

    if (!_observerAttached) {
      _observerAttached = true;

      OneSignal.User.pushSubscription.addObserver((_) {
        // The id can change after opt-in; re-upsert. Fire-and-forget.
        _upsert(userId);
      });

      if (_firebaseReady) {
        _fcmRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
          (_) => _upsert(userId),
          onError: (_) {},
        );
      }
    }
  }

  /// True once Firebase has initialised on this platform. iOS has no
  /// GoogleService-Info.plist yet, so the FCM half stays inert there.
  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  Future<String?> _fcmToken() async {
    if (!_firebaseReady) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      // No Play Services, no permission, or FCM unreachable — the OneSignal
      // path still works; the fallback just has no address for this device.
      return null;
    }
  }

  /// Clears this device's push ids on sign-out so a signed-out user is no
  /// longer targeted. Best-effort; keeps the row for history.
  Future<void> unregisterCurrentDevice(String userId) async {
    try {
      final deviceId = await _deviceId();
      await _supabase
          .from('device_push_tokens')
          .update({
            'onesignal_player_id': null,
            'fcm_token': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('device_id', deviceId);
    } catch (_) {
      // Non-fatal: must never block sign-out.
    }
  }

  Future<void> _upsert(String userId) async {
    try {
      final deviceId = await _deviceId();
      final payload = <String, dynamic>{
        'user_id': userId,
        'device_id': deviceId,
        'platform': _platform,
        'onesignal_player_id': OneSignal.User.pushSubscription.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Only write fcm_token when we actually have one, so a platform without
      // Firebase configured cannot wipe a previously registered token.
      final fcm = await _fcmToken();
      if (fcm != null) payload['fcm_token'] = fcm;

      await _supabase
          .from('device_push_tokens')
          .upsert(payload, onConflict: 'user_id, device_id');
    } catch (_) {
      // Non-fatal: token registration must never block auth.
    }
  }

  void dispose() {
    _fcmRefreshSub?.cancel();
  }

  /// A stable per-install id, persisted locally, used as the upsert key so a
  /// changing OneSignal id updates one row instead of creating duplicates.
  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      final rnd = Random.secure();
      id = List<int>.generate(
        16,
        (_) => rnd.nextInt(256),
      ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return defaultTargetPlatform.name;
    }
  }
}

@riverpod
DeviceTokenRepository deviceTokenRepository(Ref ref) {
  final repo = DeviceTokenRepository(supabase: Supabase.instance.client);
  ref.onDispose(repo.dispose);
  return repo;
}
