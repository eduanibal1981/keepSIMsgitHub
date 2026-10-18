import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_liveness_result.dart';

void main() {
  group('Carrier BSS Liveness & Activity Verification Tests', () {
    test('SimLivenessResult parses active Zendit/DTOne response', () {
      final json = {
        'is_active': true,
        'carrier_status': 'active',
        'detected_operator_name': 'Omantel',
        'country_code': 'OM',
        'provider': 'zendit',
        'message': 'Active on Omantel (Prepaid)',
      };

      final result = SimLivenessResult.fromJson(json);

      expect(result.isActive, isTrue);
      expect(result.carrierStatus, equals('active'));
      expect(result.detectedOperatorName, equals('Omantel'));
      expect(result.countryCode, equals('OM'));
      expect(result.provider, equals('zendit'));
      expect(result.message, equals('Active on Omantel (Prepaid)'));
    });

    test('SimLivenessResult parses inactive/dead SIM response', () {
      final json = {
        'is_active': false,
        'carrier_status': 'inactive',
        'provider': 'dtone',
        'reason': 'SUBSCRIBER_NOT_FOUND',
        'message': 'Number is inactive or recycled by carrier.',
      };

      final result = SimLivenessResult.fromJson(json);

      expect(result.isActive, isFalse);
      expect(result.carrierStatus, equals('inactive'));
      expect(result.reason, equals('SUBSCRIBER_NOT_FOUND'));
      expect(result.message, contains('Number is inactive'));
    });

    test('Client payload excludes provider verification fields', () {
      final now = DateTime.parse('2026-08-31T07:00:00Z');
      final line = SimLine(
        id: 'test-sim-id-999',
        userId: 'test-user-id-000',
        phoneNumber: '+96891234567',
        nickname: 'My Oman Line',
        isCarrierVerified: true,
        carrierStatus: 'active',
        detectedOperatorName: 'Omantel',
        carrierVerifiedAt: now,
      );

      final payload = line.toClientWritableJson();

      for (final field in [
        'is_carrier_verified',
        'carrier_status',
        'detected_operator_name',
        'carrier_verified_at',
        'verification_status',
        'health_score',
      ]) {
        expect(payload.containsKey(field), isFalse, reason: field);
      }
    });
  });
}
