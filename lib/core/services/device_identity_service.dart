/// SIM Shield — device identity (G10)
///
/// Feature suggestion #10 in doc/PRODUCTION_PLAN_REVIEW.md § 6.
///
/// ## This does not invent a device id
///
/// `DeviceTokenRepository` has been generating a 32-char hex id from
/// `Random.secure()` and persisting it in `SharedPreferences` under
/// `keepsims_device_id` since the push work. That id is the identity the server
/// already knows (`device_push_tokens.device_id`), so this service is an
/// extraction of it, not a competitor: same key, same format, same value on an
/// existing install. If you change the key or the format you split every
/// device in the database in two.
///
/// ## What it deliberately does not collect
///
/// A random UUID-ish id, the platform name, and the app version. No IMEI, no
/// advertising id, no location, no `device_info_plus` model string — every one
/// of those would drag `doc/PLAY_DATA_SAFETY.md` and
/// `doc/APPLE_PRIVACY_NUTRITION_LABEL.md` into the change for signal the
/// anti-fraud model does not need. The whole point of the id is that it says
/// "this install" and nothing else about the human holding it.
///
/// ## It is a claim, not proof
///
/// Anything a client sends is attacker-controlled. The server treats a missing
/// or rotated id as *more* suspicious, not less, and Firebase App Check (also
/// G10) is the separate mechanism that says "this really is our app".
library;

import 'dart:math';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:keep_sims/core/constants/app_constants.dart';

part 'device_identity_service.g.dart';

class DeviceIdentityService {
  DeviceIdentityService({SupabaseClient? supabase}) : _supabase = supabase;

  /// Must match `DeviceTokenRepository._deviceIdKey`. Changing it orphans every
  /// already-registered device.
  static const deviceIdKey = 'keepsims_device_id';

  final SupabaseClient? _supabase;
  String? _cached;

  /// The stable per-install id, generated on first call and persisted.
  ///
  /// 32 lowercase hex characters, which is what the server's
  /// `normalize_device_id()` accepts (`^[a-z0-9][a-z0-9._:-]{7,127}$`).
  Future<String> deviceId() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(deviceIdKey);
    if (id == null || id.isEmpty) {
      final rnd = Random.secure();
      id = List<int>.generate(
        16,
        (_) => rnd.nextInt(256),
      ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString(deviceIdKey, id);
    }
    _cached = id;
    return id;
  }

  /// Cached id if one has already been read this session, else null.
  ///
  /// For synchronous call sites that must not await — they send null, which the
  /// server scores as `missing_device_id` rather than treating as clean.
  String? get cachedDeviceId => _cached;

  String get platform {
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

  String get appVersion => AppConstants.appVersion;

  /// Headers to attach to an Edge Function call on a money path.
  ///
  /// Returns `{}` on every platform and in every state where App Check cannot
  /// produce a token — iOS (no GoogleService-Info.plist), web, an unregistered
  /// Firebase project, no Play Services. That is the *expected* case today, and
  /// the server records it as `missing` and continues, because
  /// `APP_CHECK_ENFORCE` ships false. An absent header is never an error here:
  /// failing a deposit because attestation was unavailable would be a far worse
  /// outcome than accepting one that was not attested.
  Future<Map<String, String>> appCheckHeaders() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        Firebase.apps.isEmpty) {
      return const {};
    }
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      if (token == null || token.isEmpty) return const {};
      return {'X-Firebase-AppCheck': token};
    } catch (_) {
      return const {};
    }
  }

  /// Registers this install against the signed-in account.
  ///
  /// Best-effort by design: this runs on the sign-in path, and a failure here
  /// must never stop somebody logging in. The server-side `touch_user_device`
  /// likewise never raises.
  Future<void> touch() async {
    final client = _supabase ?? Supabase.instance.client;
    if (client.auth.currentUser == null) return;
    try {
      await client.rpc(
        'touch_user_device',
        params: {
          'p_device_id': await deviceId(),
          'p_platform': platform,
          'p_app_version': appVersion,
        },
      );
    } catch (_) {
      // Non-fatal: observability, not authorisation.
    }
  }

  /// Records a refusal that the server had to raise rather than return.
  ///
  /// `request_instant_refill` refuses by raising `KS451`, which aborts its
  /// transaction and takes its own audit row with it — see the header of
  /// `20260809030000_g10d_durable_block_audit.sql`. This puts the record back,
  /// in a fresh transaction. It does not and cannot change the outcome; the
  /// refusal already happened server-side.
  Future<void> reportBlock({required String action, double? amountUsd}) async {
    final client = _supabase ?? Supabase.instance.client;
    if (client.auth.currentUser == null) return;
    try {
      await client.rpc(
        'report_device_block',
        params: {
          'p_action': action,
          'p_amount_usd': amountUsd,
          'p_device_id': await deviceId(),
        },
      );
    } catch (_) {
      // Best-effort telemetry on an error path. Never mask the original error.
    }
  }
}

@Riverpod(keepAlive: true)
DeviceIdentityService deviceIdentityService(Ref ref) => DeviceIdentityService();
