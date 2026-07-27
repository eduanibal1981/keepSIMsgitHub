import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';

void main() {
  group('SimLine update payload tests (Session D5d)', () {
    test('toClientWritableJson includes only client-writable columns', () {
      final line = SimLine(
        id: 'test-sim-id-123',
        userId: 'test-user-id-456',
        phoneNumber: '+15551234567',
        nickname: 'My Test Line',
        avatarIcon: 'sim_card',
        countryId: 'US',
        carrierId: 'tmobile',
        status: 'active',
        verificationStatus: 'verified',
        healthScore: 95,
        protectionTier: 'premium',
        planType: 'premium',
        planExpiresAt: DateTime.parse('2027-01-01T00:00:00Z'),
        isAutoDetected: true,
        isHomeMode: true,
        protectionPaused: false,
        requiresProtectionAtHome: true,
      );

      final payload = line.toClientWritableJson();

      // Client-writable fields MUST be present
      expect(payload['phone_number'], equals('+15551234567'));
      expect(payload['nickname'], equals('My Test Line'));
      expect(payload['avatar_icon'], equals('sim_card'));
      expect(payload['country_id'], equals('US'));
      expect(payload['carrier_id'], equals('tmobile'));
      expect(payload['status'], equals('active'));
      expect(payload['is_home_mode'], isTrue);
      expect(payload['protection_paused'], isFalse);
      expect(payload['requires_protection_at_home'], isTrue);
      expect(payload.containsKey('updated_at'), isTrue);

      // Server-owned fields MUST NOT be present in client update payload
      expect(payload.containsKey('plan_type'), isFalse);
      expect(payload.containsKey('plan_expires_at'), isFalse);
      expect(payload.containsKey('health_score'), isFalse);
      expect(payload.containsKey('verification_status'), isFalse);
      expect(payload.containsKey('protection_tier'), isFalse);
      expect(payload.containsKey('is_auto_detected'), isFalse);
      expect(payload.containsKey('created_at'), isFalse);
      expect(payload.containsKey('user_id'), isFalse);
    });

    test('offline sync queue update payload strips id before PostgREST .update()', () {
      final line = SimLine(
        id: 'b2222222-2222-2222-2222-222222222222',
        userId: 'a1111111-1111-1111-1111-111111111111',
        phoneNumber: '+15550001111',
        nickname: 'Offline Queued Update',
      );

      final queuedPayload = Map<String, dynamic>.from(line.toClientWritableJson())..['id'] = line.id;
      final lineId = queuedPayload['id'] as String;
      final updateBody = Map<String, dynamic>.from(queuedPayload)..remove('id');

      expect(lineId, equals('b2222222-2222-2222-2222-222222222222'));
      expect(updateBody.containsKey('id'), isFalse);
      expect(updateBody.containsKey('nickname'), isTrue);
      expect(updateBody.containsKey('plan_type'), isFalse);
    });
  });
}
