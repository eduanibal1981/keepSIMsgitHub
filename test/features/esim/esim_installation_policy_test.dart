import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_activation_payload.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_installation_policy.dart';
import 'esim_installation_fixtures.dart';

void main() {
  test(
    'Apple link uses a fixed HTTPS host and round-trips the entire encoded LPA exactly once',
    () {
      const lpa = r'LPA:1$rsp.fixture.invalid$code+&?=%23#é$extra';
      final payload = EsimActivationPayload.tryParse(lpa)!;
      final uri = payload.appleInstallUri;
      expect(uri.scheme, 'https');
      expect(uri.host, 'esimsetup.apple.com');
      expect(uri.path, '/esim_qrcode_provisioning');
      expect(uri.queryParameters, {'carddata': lpa});
      expect(uri.fragment, isEmpty);
      expect(uri.userInfo, isEmpty);
      expect(payload.toString(), isNot(contains('code+')));
    },
  );
  test(
    'invalid hosts, URL injection, whitespace, malformed versions and oversized payloads are refused',
    () {
      for (final host in [
        'https://evil.invalid',
        'evil.invalid/path',
        'user@evil.invalid',
        'evil.invalid:443',
        'evil.invalid?x=1',
        'evil.invalid#x',
        'evil..invalid',
        '-evil.invalid',
        '127.0.0.1',
        'évil.invalid',
        'evil.invalid.',
      ]) {
        expect(
          EsimActivationPayload.tryParse('LPA:1\$$host\$code'),
          isNull,
          reason: host,
        );
      }
      for (final value in [
        '',
        r'LPA:2$fixture.invalid$code',
        r'LPA:1$fixture.invalid$',
        r'LPA:1$fixture.invalid$code$',
        r'LPA:1$fixture.invalid$code$a$b',
        'LPA:1\$fixture.invalid\$private\ncode',
        'LPA:1\$fixture.invalid\$${'x' * 1025}',
      ]) {
        expect(EsimActivationPayload.tryParse(value), isNull);
      }
    },
  );
  test(
    'UserEsim uses the same strict parser and redacts its diagnostic string',
    () {
      final p = installationFixture();
      expect(p.activationPayload, isNotNull);
      expect(p.toString(), isNot(contains('private-code')));
      expect(p.toString(), isNot(contains('8900000')));
      expect(
        installationFixture({
          'lpa_string': r'LPA:1$evil.invalid/path$code',
        }).hasActivationPayload,
        false,
      );
      expect(
        installationFixture({'issuance_verified': false}).hasActivationPayload,
        false,
      );
      expect(p.lastObservationAt, isNotNull);
    },
  );
  test('Apple link requires a physical iPhone on iOS 17.4 or later', () {
    for (final version in [
      (16, 9, false),
      (17, 3, false),
      (17, 4, true),
      (17, 10, true),
      (18, 0, true),
    ]) {
      expect(
        EsimInstallationEnvironment(
          platform: EsimInstallPlatform.ios,
          major: version.$1,
          minor: version.$2,
          physicalDevice: true,
        ).supportsAppleLink,
        version.$3,
      );
    }
    expect(
      const EsimInstallationEnvironment(
        platform: EsimInstallPlatform.ios,
        major: 18,
        physicalDevice: false,
      ).supportsAppleLink,
      false,
    );
    expect(
      const EsimInstallationEnvironment(
        platform: EsimInstallPlatform.android,
        major: 30,
        physicalDevice: true,
      ).supportsAppleLink,
      false,
    );
  });
  test(
    'genuine released issuance permits QR/manual install without inventing an expiry',
    () {
      final p = installationFixture();
      expect(p.expiresAt, isNull);
      expect(EsimInstallationPolicy.forProfile(p).mayReveal(), true);
    },
  );
  test(
    'old downloads, enabled and disabled installations never prompt another installation',
    () {
      for (final state in ['downloaded', 'installed', 'enabled', 'disabled']) {
        expect(
          installationFixture({'installation_state': state}).statusLabel,
          isNot('Ready to install'),
        );
        final policy = EsimInstallationPolicy.forProfile(
          installationFixture({'installation_state': state}),
        );
        expect(policy.state, EsimInstallationState.installed);
        expect(policy.mayReveal(sameDeviceConfirmed: true), false);
      }
    },
  );
  test(
    'expired, cancelled, revoked and unsupported profiles cannot install',
    () {
      for (final changes in [
        {'profile_state': 'expired'},
        {'profile_state': 'cancelled'},
        {'profile_state': 'revoked'},
        {'bundle_state': 'expired'},
        {'bundle_state': 'cancelled'},
        {'provider': 'other'},
        {
          'expires_at': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        },
        {
          'activation_deadline_at': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        },
        {'lpa_string': ''},
        {'installation_state': 'unknown'},
        {'profile_state': 'suspended'},
      ]) {
        expect(
          EsimInstallationPolicy.forProfile(
            installationFixture(changes),
          ).mayReveal(sameDeviceConfirmed: true),
          false,
          reason: '$changes',
        );
      }
    },
  );
  final recovery = {
    'installation_state': 'deleted',
    'profile_state': 'active',
    'bundle_state': 'active',
    'expires_at': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
  };
  test(
    'deleted valid profiles require same-device confirmation before revealing the original code',
    () {
      final policy = EsimInstallationPolicy.forProfile(
        installationFixture(recovery),
      );
      expect(policy.state, EsimInstallationState.sameDeviceRecovery);
      expect(policy.mayReveal(), false);
      expect(policy.mayReveal(sameDeviceConfirmed: true), true);
    },
  );
  test(
    'unknown expiry, stale/future observations, depletion, suspension and errors require support recovery',
    () {
      for (final changes in [
        {'expires_at': null},
        {'last_observation_at': null},
        {
          'last_observation_at': DateTime.now()
              .subtract(const Duration(hours: 7))
              .toIso8601String(),
        },
        {
          'last_observation_at': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        },
        {'bundle_state': 'depleted'},
        {'profile_state': 'suspended'},
        {'usage_error_code': 'REFRESH_FAILED'},
      ]) {
        expect(
          EsimInstallationPolicy.forProfile(
            installationFixture({...recovery, ...changes}),
          ).mayReveal(sameDeviceConfirmed: true),
          false,
        );
      }
    },
  );
}
