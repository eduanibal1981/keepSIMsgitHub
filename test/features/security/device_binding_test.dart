/// G10 — device binding + velocity anti-fraud, client-side units.
///
/// The scoring model itself lives in Postgres and is proven there, in rolled-
/// back transactions against the real database (see the G10 block in
/// doc/PRODUCTION_PLAN_REVIEW.md § 6). What is testable here is the part that
/// ships inside the APK: the id format the server will accept, the refusal the
/// user is shown, and the parsing of the device list.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/services/device_identity_service.dart';
import 'package:keep_sims/features/settings/presentation/controllers/devices_controller.dart';
import 'package:keep_sims/features/wallet/model/gift_transfer_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The server's `normalize_device_id()` regex, verbatim. If these two ever
/// disagree, every id this app generates silently becomes `missing_device_id`
/// and the whole feature scores every honest user as suspicious.
final _serverAccepts = RegExp(r'^[a-z0-9][a-z0-9._:-]{7,127}$');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceIdentityService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('generates an id the server regex accepts', () async {
      final id = await DeviceIdentityService().deviceId();
      expect(id, matches(_serverAccepts));
      expect(id.length, 32, reason: '16 random bytes as lowercase hex');
    });

    test('is stable across calls and across instances', () async {
      final first = await DeviceIdentityService().deviceId();
      final again = await DeviceIdentityService().deviceId();
      expect(again, first, reason: 'a rotating id would look like a new device');
    });

    test('adopts the id DeviceTokenRepository already stored', () async {
      // The push repository has been writing this exact key since before G10.
      // Reading a different key would split every existing install in two.
      const legacy = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
      SharedPreferences.setMockInitialValues({
        DeviceIdentityService.deviceIdKey: legacy,
      });
      expect(await DeviceIdentityService().deviceId(), legacy);
    });

    test('the storage key is the one the push repository uses', () {
      expect(DeviceIdentityService.deviceIdKey, 'keepsims_device_id');
    });

    test('an empty stored value is replaced, not returned', () async {
      SharedPreferences.setMockInitialValues({
        DeviceIdentityService.deviceIdKey: '',
      });
      final id = await DeviceIdentityService().deviceId();
      expect(id, isNotEmpty);
      expect(id, matches(_serverAccepts));
    });

    test('two installs do not collide', () async {
      final ids = <String>{};
      for (var i = 0; i < 50; i++) {
        SharedPreferences.setMockInitialValues({});
        ids.add(await DeviceIdentityService().deviceId());
      }
      expect(ids.length, 50);
    });

    test('cachedDeviceId is null until the id has been read', () async {
      final svc = DeviceIdentityService();
      expect(svc.cachedDeviceId, isNull);
      final id = await svc.deviceId();
      expect(svc.cachedDeviceId, id);
    });
  });

  group('RegisteredDevice', () {
    Map<String, dynamic> row({
      String deviceId = 'a1b2c3d4e5f60718293a4b5c6d7e8f90',
      String? label,
      String? platform = 'android',
      String trust = 'unknown',
      String? revokedAt,
      String? attestedAt,
    }) => {
      'device_id': deviceId,
      'label': label,
      'platform': platform,
      'app_version': '0.1.0',
      'trust_state': trust,
      'first_seen_at': '2026-07-01T10:00:00Z',
      'last_seen_at': '2026-07-30T10:00:00Z',
      'attested_at': attestedAt,
      'revoked_at': revokedAt,
    };

    test('marks the caller\'s own handset, and only that one', () {
      const mine = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
      expect(RegisteredDevice.fromJson(row(), mine).isCurrent, isTrue);
      expect(
        RegisteredDevice.fromJson(row(deviceId: 'ffff0000ffff0000'), mine)
            .isCurrent,
        isFalse,
      );
    });

    test('is not current when this handset has no id yet', () {
      expect(RegisteredDevice.fromJson(row(), null).isCurrent, isFalse);
    });

    test('shows only the last six characters of the id', () {
      final d = RegisteredDevice.fromJson(row(), null);
      expect(d.shortId, '7e8f90');
      expect(d.shortId.length, 6);
    });

    test('a short id is not padded or truncated into nonsense', () {
      final d = RegisteredDevice.fromJson(row(deviceId: 'abc'), null);
      expect(d.shortId, 'abc');
    });

    test('reads revoked and blocked states', () {
      final revoked = RegisteredDevice.fromJson(
        row(revokedAt: '2026-07-29T09:00:00Z'),
        null,
      );
      expect(revoked.isRevoked, isTrue);
      expect(RegisteredDevice.fromJson(row(), null).isRevoked, isFalse);
      expect(
        RegisteredDevice.fromJson(row(trust: 'blocked'), null).isBlocked,
        isTrue,
      );
      expect(RegisteredDevice.fromJson(row(), null).isBlocked, isFalse);
    });

    test('attested_at survives the round trip', () {
      final d = RegisteredDevice.fromJson(
        row(attestedAt: '2026-07-30T08:00:00Z'),
        null,
      );
      expect(d.attestedAt, isNotNull);
      expect(RegisteredDevice.fromJson(row(), null).attestedAt, isNull);
    });

    test('a null platform does not throw', () {
      final d = RegisteredDevice.fromJson(row(platform: null), null);
      expect(d.platform, isNull);
    });
  });

  group('the refusal a user actually sees', () {
    test('GiftTransferResult carries the DEVICE_BLOCKED envelope', () {
      final r = GiftTransferResult.fromJson({
        'success': false,
        'code': 'DEVICE_BLOCKED',
        'reason': 'accounts_on_device',
        'error':
            'This transfer was stopped by a security check on this device. '
            'Contact support if this is a mistake.',
      });
      expect(r.success, isFalse);
      expect(r.code, GiftErrorCode.deviceBlocked);
      expect(r.error, contains('security check'));
    });

    test('the user-facing sentence never names the threshold', () {
      // The server puts the reason in `reason` and in security_logs. Anything
      // shown to the person who triggered it is also shown to an attacker, so
      // "accounts_on_device" must not reach the screen.
      final r = GiftTransferResult.fromJson({
        'success': false,
        'code': 'DEVICE_BLOCKED',
        'reason': 'accounts_on_device',
        'error':
            'This transfer was stopped by a security check on this device. '
            'Contact support if this is a mistake.',
      });
      expect(r.error, isNot(contains('accounts_on_device')));
      expect(r.error, isNot(contains('score')));
    });
  });
}
