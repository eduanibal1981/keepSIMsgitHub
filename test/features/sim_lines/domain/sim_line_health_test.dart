import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/domain/sim_line_health.dart';

void main() {
  SimLine createSimLine({
    String status = 'active',
    DateTime? lastTopupAt,
    bool protectionPaused = false,
  }) {
    return SimLine(
      id: 'test-id',
      userId: 'test-user',
      phoneNumber: '1234567890',
      status: status,
      lastTopupAt: lastTopupAt,
      protectionPaused: protectionPaused,
    );
  }

  group('SimLineHealth.displayHealthScore', () {
    test('returns 100 if protectionPaused is true, ignoring other conditions', () {
      final simLine = createSimLine(protectionPaused: true, status: 'inactive');
      final score = simLine.displayHealthScore(isPremium: false, hasProtectionActive: false);
      expect(score, 100);

      final score2 = simLine.displayHealthScore(isPremium: true, hasProtectionActive: true);
      expect(score2, 100);
    });

    group('when isPremium is false', () {
      test('returns 100 if hasProtectionActive is true', () {
        final simLine = createSimLine(protectionPaused: false);
        final score = simLine.displayHealthScore(isPremium: false, hasProtectionActive: true);
        expect(score, 100);
      });

      test('returns 0 if hasProtectionActive is false', () {
        final simLine = createSimLine(protectionPaused: false);
        final score = simLine.displayHealthScore(isPremium: false, hasProtectionActive: false);
        expect(score, 0);
      });
    });

    group('when isPremium is true', () {
      test('returns 100 if hasProtectionActive, status is active, and recent topup', () {
        final simLine = createSimLine(
          status: 'active',
          lastTopupAt: DateTime.now().subtract(const Duration(days: 10)),
        );
        final score = simLine.displayHealthScore(isPremium: true, hasProtectionActive: true);
        expect(score, 100); // 50 (protection) + 25 (status active) + 25 (recent topup)
      });

      test('returns 75 if hasProtectionActive, status is active, but no recent topup', () {
        final simLine = createSimLine(
          status: 'active',
          lastTopupAt: DateTime.now().subtract(const Duration(days: 81)), // > 80 days
        );
        final score = simLine.displayHealthScore(isPremium: true, hasProtectionActive: true);
        expect(score, 75); // 50 + 25 + 0
      });

      test('returns 75 if hasProtectionActive, status is inactive, but recent topup', () {
        final simLine = createSimLine(
          status: 'inactive',
          lastTopupAt: DateTime.now().subtract(const Duration(days: 79)), // <= 80 days
        );
        final score = simLine.displayHealthScore(isPremium: true, hasProtectionActive: true);
        expect(score, 75); // 50 + 0 + 25
      });

      test('returns 50 if hasProtectionActive, status is inactive, and no recent topup', () {
        final simLine = createSimLine(
          status: 'inactive',
          lastTopupAt: null,
        );
        final score = simLine.displayHealthScore(isPremium: true, hasProtectionActive: true);
        expect(score, 50); // 50 + 0 + 0
      });

      test('returns 50 if no protection active, status is active, and recent topup', () {
        final simLine = createSimLine(
          status: 'active',
          lastTopupAt: DateTime.now().subtract(const Duration(days: 50)),
        );
        final score = simLine.displayHealthScore(isPremium: true, hasProtectionActive: false);
        expect(score, 50); // 0 + 25 + 25
      });

      test('returns 25 if no protection active, status is active, and no recent topup', () {
        final simLine = createSimLine(
          status: 'active',
          lastTopupAt: DateTime.now().subtract(const Duration(days: 90)),
        );
        final score = simLine.displayHealthScore(isPremium: true, hasProtectionActive: false);
        expect(score, 25); // 0 + 25 + 0
      });
      
      test('returns 25 if no protection active, status is inactive, and recent topup', () {
        final simLine = createSimLine(
          status: 'expired',
          lastTopupAt: DateTime.now().subtract(const Duration(days: 80)),
        );
        final score = simLine.displayHealthScore(isPremium: true, hasProtectionActive: false);
        expect(score, 25); // 0 + 0 + 25
      });

      test('returns 0 if no protection active, status is inactive, and no recent topup', () {
        final simLine = createSimLine(
          status: 'expired',
          lastTopupAt: null,
        );
        final score = simLine.displayHealthScore(isPremium: true, hasProtectionActive: false);
        expect(score, 0); // 0 + 0 + 0
      });
    });
  });
}
