import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:keep_sims/core/services/device_identity_service.dart';

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
  DeviceTokenRepository({
    required SupabaseClient supabase,
    DeviceIdentityService? deviceIdentity,
  }) : _supabase = supabase,
       _identity = deviceIdentity ?? DeviceIdentityService(supabase: supabase);

  final SupabaseClient _supabase;

  /// G10 extracted the device id into a shared service. Same SharedPreferences
  /// key, same 32-hex format — the id an install already has is unchanged.
  final DeviceIdentityService _identity;

  bool _observerAttached = false;
  StreamSubscription<String>? _fcmRefreshSub;

  /// Upserts this device's identifiers for [userId]. Safe to call repeatedly.
  /// Also attaches one-time listeners so identifiers that only become available
  /// later — a OneSignal subscription id after the user grants push permission,
  /// or a rotated FCM token — are captured.
  Future<void> registerCurrentDevice(String userId) async {
    await _upsert(userId);

    // G10: the same install, recorded in the money-facing registry. Separate
    // from the push row because that one gets nulled on sign-out and an
    // anti-fraud registry must not forget a device the moment it signs out.
    await _identity.touch();

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
      final deviceId = await _identity.deviceId();
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
      final deviceId = await _identity.deviceId();
      final payload = <String, dynamic>{
        'user_id': userId,
        'device_id': deviceId,
        'platform': _identity.platform,
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
}

@riverpod
DeviceTokenRepository deviceTokenRepository(Ref ref) {
  final repo = DeviceTokenRepository(
    supabase: Supabase.instance.client,
    deviceIdentity: ref.watch(deviceIdentityServiceProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
}
