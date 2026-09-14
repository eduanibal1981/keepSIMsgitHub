import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/offline_recharge/model/recovery_state_model.dart';

void main() {
  group('RecoveryStateModel Tests', () {
    test('Initial default values are properly initialized', () {
      const model = RecoveryStateModel();
      expect(model.interfaceType, equals(NetworkInterfaceType.none));
      expect(model.reachability, equals(KeepSimsReachability.unknown));
      expect(model.entitlement, equals(RecoveryEntitlement.unknown));
      expect(model.provisioningState, equals(RecoveryProvisioningState.notPrepared));
      expect(model.remainingMb, equals(0));
      expect(model.totalMb, equals(0));
      expect(model.hasBackupEsim, isFalse);
      expect(model.isMock, isTrue);
    });

    test('hasBackupEsim returns true when activationCode is present', () {
      const model = RecoveryStateModel(
        activationCode: r'LPA:1$sandbox.firsty.app$test1234567890',
      );
      expect(model.hasBackupEsim, isTrue);
    });

    test('copyWith properly updates specified fields while preserving others', () {
      const initial = RecoveryStateModel(
        profileReference: 'prof_001',
        esimReference: 'esim_001',
        remainingMb: 500,
        totalMb: 1024,
      );

      final updated = initial.copyWith(
        reachability: KeepSimsReachability.reachable,
        remainingMb: 450,
      );

      expect(updated.profileReference, equals('prof_001'));
      expect(updated.esimReference, equals('esim_001'));
      expect(updated.totalMb, equals(1024));
      expect(updated.remainingMb, equals(450));
      expect(updated.reachability, equals(KeepSimsReachability.reachable));
    });

    test('toJson and fromJson round-trip perfectly', () {
      final now = DateTime.utc(2026, 9, 11, 2, 30, 0);
      final model = RecoveryStateModel(
        interfaceType: NetworkInterfaceType.cellular,
        reachability: KeepSimsReachability.reachable,
        entitlement: RecoveryEntitlement.generalDataAllowance,
        provisioningState: RecoveryProvisioningState.verified,
        profileReference: '9007600000000002',
        esimReference: '900760000000000002',
        iccid: '8999967846891707543',
        activationCode: r'LPA:1$sandbox.firsty.app$740f6700ae378305ecc5522b000c760f',
        smdpAddress: 'sandbox.firsty.app',
        matchingId: '740f6700ae378305ecc5522b000c760f',
        remainingMb: 1024,
        totalMb: 1024,
        expiresAt: now.add(const Duration(days: 30)),
        lastCheckedAt: now,
        isMock: true,
      );

      final json = model.toJson();
      final decoded = RecoveryStateModel.fromJson(json);

      expect(decoded.interfaceType, equals(NetworkInterfaceType.cellular));
      expect(decoded.reachability, equals(KeepSimsReachability.reachable));
      expect(decoded.entitlement, equals(RecoveryEntitlement.generalDataAllowance));
      expect(decoded.provisioningState, equals(RecoveryProvisioningState.verified));
      expect(decoded.profileReference, equals('9007600000000002'));
      expect(decoded.esimReference, equals('900760000000000002'));
      expect(decoded.iccid, equals('8999967846891707543'));
      expect(decoded.activationCode, equals(r'LPA:1$sandbox.firsty.app$740f6700ae378305ecc5522b000c760f'));
      expect(decoded.smdpAddress, equals('sandbox.firsty.app'));
      expect(decoded.matchingId, equals('740f6700ae378305ecc5522b000c760f'));
      expect(decoded.remainingMb, equals(1024));
      expect(decoded.totalMb, equals(1024));
      expect(decoded.expiresAt, equals(now.add(const Duration(days: 30))));
      expect(decoded.lastCheckedAt, equals(now));
      expect(decoded.isMock, isTrue);
    });

    test('encode and decode helper handle null and invalid strings gracefully', () {
      expect(RecoveryStateModel.decode(null), isNull);
      expect(RecoveryStateModel.decode(''), isNull);
      expect(RecoveryStateModel.decode('{invalid-json'), isNull);

      const valid = RecoveryStateModel(iccid: '8999912345');
      final encoded = valid.encode();
      final decoded = RecoveryStateModel.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.iccid, equals('8999912345'));
    });
  });
}
