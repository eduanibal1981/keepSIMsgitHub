import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/domain/sim_line_health.dart';

SimLine _line({
  String status = 'active',
  DateTime? lastTopupAt,
  bool isHomeMode = false,
  bool protectionPaused = false,
  bool requiresProtectionAtHome = false,
  bool isCarrierVerified = false,
  DateTime? carrierVerifiedAt,
  String verificationStatus = 'unverified',
}) {
  return SimLine(
    id: 'line-1',
    userId: 'user-1',
    phoneNumber: '+96891234567',
    status: status,
    lastTopupAt: lastTopupAt,
    isHomeMode: isHomeMode,
    protectionPaused: protectionPaused,
    requiresProtectionAtHome: requiresProtectionAtHome,
    isCarrierVerified: isCarrierVerified,
    carrierVerifiedAt: carrierVerifiedAt,
    verificationStatus: verificationStatus,
  );
}

void main() {
  group('displayHealthScore — 3-pillar scoring (max 100)', () {
    test('all 3 pillars active scores 100', () {
      final line = _line(
        lastTopupAt: DateTime.now().subtract(const Duration(days: 10)),
        isCarrierVerified: true,
      );
      expect(
        line.displayHealthScore(
          isRealLiveVerified: true,
          hasNotificationSchedule: true,
          carrierExpirationDays: 90,
        ),
        100, // 25 + 25 + 50
      );
    });

    test('user scenario: notification + recent refill without live verify scores 75', () {
      final line = _line(
        lastTopupAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(
        line.displayHealthScore(
          isRealLiveVerified: false,
          hasNotificationSchedule: true,
          carrierExpirationDays: 90,
        ),
        75, // 0 + 25 + 50
      );
    });

    test('refill older than carrier expiration days (default 90) does not get refill points', () {
      final line = _line(
        lastTopupAt: DateTime.now().subtract(const Duration(days: 91)),
        isCarrierVerified: true,
      );
      expect(
        line.displayHealthScore(
          isRealLiveVerified: true,
          hasNotificationSchedule: true,
          carrierExpirationDays: 90,
        ),
        50, // 25 + 25 + 0
      );
    });

    test('custom carrier expiration days is respected', () {
      final line = _line(
        lastTopupAt: DateTime.now().subtract(const Duration(days: 45)),
      );
      // If carrier rule is 30 days, 45 days is expired (0 pts)
      expect(
        line.displayHealthScore(
          isRealLiveVerified: false,
          hasNotificationSchedule: false,
          carrierExpirationDays: 30,
        ),
        0,
      );
      // If carrier rule is 60 days, 45 days is valid (50 pts)
      expect(
        line.displayHealthScore(
          isRealLiveVerified: false,
          hasNotificationSchedule: false,
          carrierExpirationDays: 60,
        ),
        50,
      );
    });

    test('no pillars met scores 0', () {
      final line = _line(status: 'inactive', lastTopupAt: null);
      expect(
        line.displayHealthScore(
          isRealLiveVerified: false,
          hasNotificationSchedule: false,
        ),
        0,
      );
    });

    test('paused line evaluates strictly according to 3 pillars without override', () {
      final line = _line(
        status: 'expired',
        isHomeMode: false,
        protectionPaused: true,
      );
      expect(
        line.displayHealthScore(
          isRealLiveVerified: false,
          hasNotificationSchedule: false,
        ),
        0,
      );
    });
  });
}
