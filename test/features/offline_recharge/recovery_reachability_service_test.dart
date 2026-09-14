import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keep_sims/features/offline_recharge/model/recovery_state_model.dart';
import 'package:keep_sims/features/offline_recharge/service/recovery_reachability_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecoveryReachabilityService Tests', () {
    test('probeReachability sets reachable on HTTP 200', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"ok": true, "status": "reachable"}', 200, headers: {
          'content-type': 'application/json',
        });
      });

      final container = ProviderContainer(
        overrides: [
          recoveryReachabilityServiceProvider.overrideWith(
            () => RecoveryReachabilityNotifier(
              client: mockClient,
              autoListenConnectivity: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(recoveryReachabilityServiceProvider.notifier);
      final result = await notifier.probeReachability(
        customUri: Uri.parse('https://api.test.com/probe'),
      );

      expect(result, equals(KeepSimsReachability.reachable));
      final state = container.read(recoveryReachabilityServiceProvider);
      expect(state.reachability, equals(KeepSimsReachability.reachable));
      expect(state.lastCheckedAt, isNotNull);
      expect(state.errorMessage, isNull);
    });

    test('probeReachability sets serviceError on HTTP 500', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "Internal Server Error"}', 500);
      });

      final container = ProviderContainer(
        overrides: [
          recoveryReachabilityServiceProvider.overrideWith(
            () => RecoveryReachabilityNotifier(
              client: mockClient,
              autoListenConnectivity: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(recoveryReachabilityServiceProvider.notifier);
      final result = await notifier.probeReachability(
        customUri: Uri.parse('https://api.test.com/probe'),
      );

      expect(result, equals(KeepSimsReachability.serviceError));
      final state = container.read(recoveryReachabilityServiceProvider);
      expect(state.reachability, equals(KeepSimsReachability.serviceError));
      expect(state.errorMessage, contains('500'));
    });

    test('probeReachability sets unreachable on SocketException', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Failed host lookup: api.keepsims.com');
      });

      final container = ProviderContainer(
        overrides: [
          recoveryReachabilityServiceProvider.overrideWith(
            () => RecoveryReachabilityNotifier(
              client: mockClient,
              autoListenConnectivity: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(recoveryReachabilityServiceProvider.notifier);
      final result = await notifier.probeReachability(
        customUri: Uri.parse('https://api.test.com/probe'),
      );

      expect(result, equals(KeepSimsReachability.unreachable));
      final state = container.read(recoveryReachabilityServiceProvider);
      expect(state.reachability, equals(KeepSimsReachability.unreachable));
      expect(state.errorMessage, contains('Network unreachable'));
    });

    test('probeReachability sets unreachable on TimeoutException', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Request timed out');
      });

      final container = ProviderContainer(
        overrides: [
          recoveryReachabilityServiceProvider.overrideWith(
            () => RecoveryReachabilityNotifier(
              client: mockClient,
              autoListenConnectivity: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(recoveryReachabilityServiceProvider.notifier);
      final result = await notifier.probeReachability(
        customUri: Uri.parse('https://api.test.com/probe'),
      );

      expect(result, equals(KeepSimsReachability.unreachable));
      final state = container.read(recoveryReachabilityServiceProvider);
      expect(state.reachability, equals(KeepSimsReachability.unreachable));
      expect(state.errorMessage, contains('timed out'));
    });

    test('updateFromRemote correctly updates profile and allowance values', () {
      final container = ProviderContainer(
        overrides: [
          recoveryReachabilityServiceProvider.overrideWith(
            () => RecoveryReachabilityNotifier(autoListenConnectivity: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(recoveryReachabilityServiceProvider.notifier);
      notifier.updateFromRemote(
        profileReference: 'prof_123',
        esimReference: 'esim_456',
        iccid: '89999000111222',
        activationCode: r'LPA:1$sandbox.firsty.app$testcode',
        entitlement: RecoveryEntitlement.sponsoredAccess,
        remainingMb: 1024,
        totalMb: 1024,
      );

      final state = container.read(recoveryReachabilityServiceProvider);
      expect(state.profileReference, equals('prof_123'));
      expect(state.esimReference, equals('esim_456'));
      expect(state.iccid, equals('89999000111222'));
      expect(state.activationCode, equals(r'LPA:1$sandbox.firsty.app$testcode'));
      expect(state.entitlement, equals(RecoveryEntitlement.sponsoredAccess));
      expect(state.remainingMb, equals(1024));
    });

    test('reportInstallationCompleted updates provisioningState', () {
      final container = ProviderContainer(
        overrides: [
          recoveryReachabilityServiceProvider.overrideWith(
            () => RecoveryReachabilityNotifier(autoListenConnectivity: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(recoveryReachabilityServiceProvider.notifier);
      expect(
        container.read(recoveryReachabilityServiceProvider).provisioningState,
        equals(RecoveryProvisioningState.notPrepared),
      );

      notifier.reportInstallationCompleted();
      expect(
        container.read(recoveryReachabilityServiceProvider).provisioningState,
        equals(RecoveryProvisioningState.installationReported),
      );
    });
  });
}
