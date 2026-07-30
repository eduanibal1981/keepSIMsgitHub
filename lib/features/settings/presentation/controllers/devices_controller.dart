/// SIM Shield — registered devices (G10)
///
/// Reads through `my_devices()`, a SECURITY DEFINER function scoped to
/// `auth.uid()` with no user-id argument. `user_devices` itself is deny-all to
/// clients on purpose: the sensitive half of this table is the *cross-user*
/// linkage (which accounts share a handset), and the way to make sure that is
/// never reachable is to give it no client surface at all rather than to write
/// a policy and hope.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:keep_sims/core/services/device_identity_service.dart';

part 'devices_controller.g.dart';

class RegisteredDevice {
  const RegisteredDevice({
    required this.deviceId,
    required this.isCurrent,
    this.label,
    this.platform,
    this.appVersion,
    required this.trustState,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.attestedAt,
    this.revokedAt,
  });

  final String deviceId;
  final bool isCurrent;
  final String? label;
  final String? platform;
  final String? appVersion;
  final String trustState;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final DateTime? attestedAt;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;
  bool get isBlocked => trustState == 'blocked';

  /// Last 6 characters. The full id never needs to be on screen — it is not a
  /// support identifier and showing it invites people to paste it somewhere.
  String get shortId =>
      deviceId.length <= 6 ? deviceId : deviceId.substring(deviceId.length - 6);

  static RegisteredDevice fromJson(Map<String, dynamic> j, String? currentId) {
    final id = (j['device_id'] ?? '') as String;
    return RegisteredDevice(
      deviceId: id,
      isCurrent: currentId != null && currentId == id,
      label: j['label'] as String?,
      platform: j['platform'] as String?,
      appVersion: j['app_version'] as String?,
      trustState: (j['trust_state'] ?? 'unknown') as String,
      firstSeenAt: DateTime.parse(j['first_seen_at'] as String).toLocal(),
      lastSeenAt: DateTime.parse(j['last_seen_at'] as String).toLocal(),
      attestedAt: j['attested_at'] == null
          ? null
          : DateTime.parse(j['attested_at'] as String).toLocal(),
      revokedAt: j['revoked_at'] == null
          ? null
          : DateTime.parse(j['revoked_at'] as String).toLocal(),
    );
  }
}

@riverpod
class DevicesController extends _$DevicesController {
  @override
  Future<List<RegisteredDevice>> build() async {
    return _load();
  }

  Future<List<RegisteredDevice>> _load() async {
    final client = Supabase.instance.client;
    // `is_current` cannot be computed server-side: only this handset knows
    // which of these ids is itself.
    final currentId = await ref.read(deviceIdentityServiceProvider).deviceId();
    final rows = await client.rpc('my_devices');
    if (rows is! List) return const [];
    return rows
        .map(
          (r) => RegisteredDevice.fromJson(
            Map<String, dynamic>.from(r as Map),
            currentId,
          ),
        )
        .toList();
  }

  /// "Sign out this device": marks it revoked and clears its push address, so
  /// notifications stop reaching it. The row is kept — an anti-fraud registry
  /// that forgets on sign-out is worthless.
  Future<bool> revoke(String deviceId) async {
    final client = Supabase.instance.client;
    final ok = await client.rpc(
      'revoke_my_device',
      params: {'p_device_id': deviceId},
    );
    state = await AsyncValue.guard(_load);
    return ok == true;
  }

  Future<bool> rename(String deviceId, String label) async {
    final client = Supabase.instance.client;
    final ok = await client.rpc(
      'label_my_device',
      params: {'p_device_id': deviceId, 'p_label': label},
    );
    state = await AsyncValue.guard(_load);
    return ok == true;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }
}
