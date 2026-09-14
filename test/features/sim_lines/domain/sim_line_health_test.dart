import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/domain/sim_line_health.dart';

void main() {
  SimLine createSimLine({
    String status = 'active',
    DateTime? lastTopupAt,
    bool protectionPaused = false,
    bool isCarrierVerified = false,
  }) {
    return SimLine(
      id: 'test-id',
      userId: 'test-user',
      phoneNumber: '1234567890',
      status: status,
      lastTopupAt: lastTopupAt,
      protectionPaused: protectionPaused,
      isCarrierVerified: isCarrierVerified,
    );
  }

  group('SimLineHealth.displayHealthScore — 4-pillar formula', () {
    test('protectionPaused does not override score — calculates true 4 pillars', () {
      final simLine = createSimLine(protectionPaused: true, status: 'inactive');
      final score = simLine.displayHealthScore(
        hasRefillSchedule: false,
        hasNotificationSchedule: false,
        isVerified: false,
      );
      expect(score, 0);
    });

    test('all 4 pillars active scores 100 (25 each)', () {
      final simLine = createSimLine(
        status: 'active',
        lastTopupAt: DateTime.now().subtract(const Duration(days: 10)),
        isCarrierVerified: true,
      );
      final score = simLine.displayHealthScore(
        hasRefillSchedule: true,
        hasNotificationSchedule: true,
        isVerified: true,
      );
      expect(score, 100);
    });

    test('3 pillars active (no refill schedule) scores 75', () {
      final simLine = createSimLine(
        status: 'active',
        lastTopupAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final score = simLine.displayHealthScore(
        hasRefillSchedule: false,
        hasNotificationSchedule: true,
        isVerified: true,
      );
      expect(score, 75);
    });

    test('2 pillars active (verified + notification, but no refill schedule and old topup) scores 50', () {
      final simLine = createSimLine(
        status: 'active',
        lastTopupAt: DateTime.now().subtract(const Duration(days: 120)),
      );
      final score = simLine.displayHealthScore(
        hasRefillSchedule: false,
        hasNotificationSchedule: true,
        isVerified: true,
      );
      expect(score, 50);
    });

    test('1 pillar active (verified only) scores 25', () {
      final simLine = createSimLine(
        status: 'active',
        lastTopupAt: null,
      );
      final score = simLine.displayHealthScore(
        hasRefillSchedule: false,
        hasNotificationSchedule: false,
        isVerified: true,
      );
      expect(score, 25);
    });

    test('0 pillars active scores 0', () {
      final simLine = createSimLine(
        status: 'inactive',
        lastTopupAt: null,
      );
      final score = simLine.displayHealthScore(
        hasRefillSchedule: false,
        hasNotificationSchedule: false,
        isVerified: false,
      );
      expect(score, 0);
    });

    test('carrier expiration window of 90 days: 89 days is active (25), 91 days is expired (0)', () {
      final validLine = createSimLine(
        status: 'inactive',
        lastTopupAt: DateTime.now().subtract(const Duration(days: 89)),
      );
      expect(
        validLine.displayHealthScore(
          hasRefillSchedule: false,
          hasNotificationSchedule: false,
          isVerified: false,
          carrierExpirationDays: 90,
        ),
        25,
      );

      final expiredLine = createSimLine(
        status: 'inactive',
        lastTopupAt: DateTime.now().subtract(const Duration(days: 91)),
      );
      expect(
        expiredLine.displayHealthScore(
          hasRefillSchedule: false,
          hasNotificationSchedule: false,
          isVerified: false,
          carrierExpirationDays: 90,
        ),
        0,
      );
    });
  });
}
