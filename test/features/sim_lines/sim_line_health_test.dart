import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/domain/sim_line_health.dart';

SimLine _line({
  String status = 'active',
  DateTime? lastTopupAt,
  bool isHomeMode = false,
  bool protectionPaused = false,
  bool requiresProtectionAtHome = false,
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
  );
}

void main() {
  group('displayHealthScore — premium tier', () {
    test('protection + active + recent refill scores 100', () {
      final line = _line(
        lastTopupAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(
        line.displayHealthScore(isPremium: true, hasProtectionActive: true),
        100,
      );
    });

    test('protection alone scores 50 + 25 for active status', () {
      final line = _line(lastTopupAt: null);
      expect(
        line.displayHealthScore(isPremium: true, hasProtectionActive: true),
        75,
      );
    });

    test('refill older than 80 days does not count as recent', () {
      final line = _line(
        lastTopupAt: DateTime.now().subtract(const Duration(days: 81)),
      );
      expect(
        line.displayHealthScore(isPremium: true, hasProtectionActive: true),
        75,
      );
    });

    test('no protection, inactive, no refill scores 0', () {
      final line = _line(status: 'expired', lastTopupAt: null);
      expect(
        line.displayHealthScore(isPremium: true, hasProtectionActive: false),
        0,
      );
    });
  });

  group('displayHealthScore — free tier', () {
    test('is binary on protection', () {
      final line = _line(lastTopupAt: null);
      expect(
        line.displayHealthScore(isPremium: false, hasProtectionActive: true),
        100,
      );
      expect(
        line.displayHealthScore(isPremium: false, hasProtectionActive: false),
        0,
      );
    });
  });

  group('displayHealthScore — home mode vs protection (B5)', () {
    test('a deliberately paused line shows 100 (nothing to worry about)', () {
      final line = _line(
        status: 'expired',
        isHomeMode: true,
        protectionPaused: true,
      );
      expect(
        line.displayHealthScore(isPremium: true, hasProtectionActive: false),
        100,
      );
    });

    test(
      "resident's dormant line at home reports true risk, not a masked 100",
      () {
        // Home mode is only a location fact: with protection NOT paused
        // (requiresProtectionAtHome), the score reflects the real state.
        final line = _line(
          status: 'expired',
          lastTopupAt: null,
          isHomeMode: true,
          requiresProtectionAtHome: true,
        );
        expect(
          line.displayHealthScore(isPremium: true, hasProtectionActive: false),
          0,
        );
      },
    );

    test('protected line at home scores on its real protection state', () {
      final line = _line(
        lastTopupAt: DateTime.now().subtract(const Duration(days: 5)),
        isHomeMode: true,
        requiresProtectionAtHome: true,
      );
      expect(
        line.displayHealthScore(isPremium: true, hasProtectionActive: true),
        100,
      );
    });

    test('home mode alone no longer masks health', () {
      // isHomeMode true but protectionPaused false (e.g. flag flipped while
      // requiresProtectionAtHome was set): the real score wins.
      final line = _line(status: 'expired', isHomeMode: true);
      expect(
        line.displayHealthScore(isPremium: true, hasProtectionActive: false),
        0,
      );
    });
  });
}
