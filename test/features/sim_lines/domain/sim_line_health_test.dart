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

  group('SimLineHealth.displayHealthScore — 3-pillar formula', () {
    test('protectionPaused does not override score — calculates true 3 pillars', () {
      final simLine = createSimLine(protectionPaused: true, status: 'inactive');
      final score = simLine.displayHealthScore(
        isRealLiveVerified: false,
        hasNotificationSchedule: false,
      );
      expect(score, 0);
    });

    test('all 3 pillars active scores 100 (25 live verify + 25 auto-notify + 50 recent recharge)', () {
      final simLine = createSimLine(
        status: 'active',
        lastTopupAt: DateTime.now().subtract(const Duration(days: 10)),
        isCarrierVerified: true,
      );
      final score = simLine.displayHealthScore(
        isRealLiveVerified: true,
        hasNotificationSchedule: true,
        carrierExpirationDays: 90,
      );
      expect(score, 100);
    });

    test('2 pillars active (25 live verify + 25 auto-notify, but no recharge recorded) scores 50', () {
      final simLine = createSimLine(
        status: 'active',
        lastTopupAt: null,
      );
      final score = simLine.displayHealthScore(
        isRealLiveVerified: true,
        hasNotificationSchedule: true,
      );
      expect(score, 50);
    });

    test('2 pillars active (25 auto-notify + 50 recent recharge, but unverified) scores 75', () {
      final simLine = createSimLine(
        status: 'active',
        lastTopupAt: DateTime.now().subtract(const Duration(days: 5)),
      );
      final score = simLine.displayHealthScore(
        isRealLiveVerified: false,
        hasNotificationSchedule: true,
        carrierExpirationDays: 90,
      );
      expect(score, 75);
    });

    test('recharge older than carrier rule days (e.g. 153 days) scores 0 for recharge pillar', () {
      final simLine = createSimLine(
        status: 'active',
        lastTopupAt: DateTime.now().subtract(const Duration(days: 160)),
      );
      final score = simLine.displayHealthScore(
        isRealLiveVerified: true,
        hasNotificationSchedule: true,
        carrierExpirationDays: 153,
      );
      // 25 (live verify) + 25 (auto-notify) + 0 (recharge > 153 days) = 50
      expect(score, 50);
    });

    test('no recharge recorded (null) scores 0 for recharge pillar', () {
      final simLine = createSimLine(
        status: 'active',
        lastTopupAt: null,
      );
      final score = simLine.displayHealthScore(
        isRealLiveVerified: false,
        hasNotificationSchedule: false,
      );
      expect(score, 0);
    });

    test('carrier expiration window of 90 days: 89 days is active (50), 91 days is expired (0)', () {
      final validLine = createSimLine(
        status: 'inactive',
        lastTopupAt: DateTime.now().subtract(const Duration(days: 89)),
      );
      expect(
        validLine.displayHealthScore(
          isRealLiveVerified: false,
          hasNotificationSchedule: false,
          carrierExpirationDays: 90,
        ),
        50,
      );

      final expiredLine = createSimLine(
        status: 'inactive',
        lastTopupAt: DateTime.now().subtract(const Duration(days: 91)),
      );
      expect(
        expiredLine.displayHealthScore(
          isRealLiveVerified: false,
          hasNotificationSchedule: false,
          carrierExpirationDays: 90,
        ),
        0,
      );
    });
  });

  group('SimLineHealth.healthScoreBreakdown — detailed 3-pillar status', () {
    test('breakdown returns 3 pillars with correct earned vs non-achieved points', () {
      // Setup line matching user scenario: 50/100 (live verified + auto-notify active, no recharge)
      final simLine = createSimLine(
        status: 'active',
        lastTopupAt: null,
        isCarrierVerified: true,
      );

      final pillars = simLine.healthScoreBreakdown(
        isRealLiveVerified: true,
        hasNotificationSchedule: true,
      );

      expect(pillars.length, 3);

      // Real Live Verification (Achieved: 25 pts)
      final verifyPillar = pillars.firstWhere(
        (p) => p.type == HealthScorePillarType.realLiveVerification,
      );
      expect(verifyPillar.isAchieved, isTrue);
      expect(verifyPillar.earnedPoints, 25);
      expect(verifyPillar.maxPoints, 25);

      // Auto-Notify (Achieved: 25 pts)
      final notifyPillar = pillars.firstWhere(
        (p) => p.type == HealthScorePillarType.autoNotify,
      );
      expect(notifyPillar.isAchieved, isTrue);
      expect(notifyPillar.earnedPoints, 25);
      expect(notifyPillar.maxPoints, 25);

      // Recent Recharge (Not Achieved: 0/50 pts)
      final rechargePillar = pillars.firstWhere(
        (p) => p.type == HealthScorePillarType.recentRecharge,
      );
      expect(rechargePillar.isAchieved, isFalse);
      expect(rechargePillar.earnedPoints, 0);
      expect(rechargePillar.maxPoints, 50);
      expect(rechargePillar.actionLabel, 'Update Recharge');

      // Total sum matches displayHealthScore
      final totalPillarsScore = pillars.fold<int>(0, (sum, p) => sum + p.earnedPoints);
      final displayScore = simLine.displayHealthScore(
        isRealLiveVerified: true,
        hasNotificationSchedule: true,
      );
      expect(totalPillarsScore, 50);
      expect(displayScore, 50);
    });

    test('all 3 pillars achieved returns 100 points (25 + 25 + 50)', () {
      final simLine = createSimLine(
        status: 'active',
        lastTopupAt: DateTime.now().subtract(const Duration(days: 5)),
        isCarrierVerified: true,
      );

      final pillars = simLine.healthScoreBreakdown(
        isRealLiveVerified: true,
        hasNotificationSchedule: true,
        carrierExpirationDays: 90,
      );

      expect(pillars.length, 3);
      expect(pillars.every((p) => p.isAchieved), isTrue);
      expect(pillars.fold<int>(0, (sum, p) => sum + p.earnedPoints), 100);
      expect(simLine.displayHealthScore(
        isRealLiveVerified: true,
        hasNotificationSchedule: true,
        carrierExpirationDays: 90,
      ), 100);
    });
  });
}
