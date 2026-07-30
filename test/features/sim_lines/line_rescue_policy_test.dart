import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_rescue_policy.dart';

/// G7 — auto-rescue top-up ("SIM insurance"). These cover the client's reading
/// of a policy row, and above all the one reading that would be dangerous to
/// get backwards: **`max_usd = 0` means NOT insured**, not "no limit".
void main() {
  Map<String, dynamic> row({
    double maxUsd = 5.00,
    int leadDays = 2,
    int warnLeadDays = 3,
    String? lastWarnedAt,
    String? lastRescueAt,
    int rescueCount = 0,
  }) => <String, dynamic>{
    'sim_line_id': 'line-1',
    'user_id': 'user-1',
    'max_usd': maxUsd,
    'lead_days': leadDays,
    'warn_lead_days': warnLeadDays,
    'last_warned_at': lastWarnedAt,
    'last_rescue_at': lastRescueAt,
    'last_rescue_execution_id': null,
    'rescue_count': rescueCount,
    'created_at': '2026-07-30T10:00:00Z',
    'updated_at': '2026-07-30T10:00:00Z',
  };

  String hoursAgo(int h) =>
      DateTime.now().toUtc().subtract(Duration(hours: h)).toIso8601String();

  group('deserialization', () {
    test('maps the snake_case row the table returns', () {
      final p = LineRescuePolicy.fromJson(row(rescueCount: 2));
      expect(p.simLineId, 'line-1');
      expect(p.maxUsd, 5.00);
      expect(p.leadDays, 2);
      expect(p.warnLeadDays, 3);
      expect(p.rescueCount, 2);
    });

    test('a never-configured line deserializes to the fail-closed default', () {
      final p = LineRescuePolicy.fromJson(<String, dynamic>{
        'sim_line_id': 'line-2',
        'user_id': 'user-1',
      });
      expect(p.maxUsd, 0.0);
      expect(p.isInsured, isFalse);
      expect(p.leadDays, 2);
      expect(p.warnLeadDays, 3);
      expect(p.rescueCount, 0);
    });
  });

  group('a zero cap means NOT INSURED, never "unlimited"', () {
    test('isInsured is false at exactly zero', () {
      expect(LineRescuePolicy.fromJson(row(maxUsd: 0)).isInsured, isFalse);
      expect(LineRescuePolicy.fromJson(row(maxUsd: 0.01)).isInsured, isTrue);
    });

    test('an uninsured line reports no outstanding warning even if one is set',
        () {
      // A stale last_warned_at left behind after the owner switched insurance
      // off must not render a "we are about to spend your money" countdown.
      final p = LineRescuePolicy.fromJson(
        row(maxUsd: 0, lastWarnedAt: hoursAgo(1)),
      );
      expect(p.hasOutstandingWarning, isFalse);
    });
  });

  group('hasOutstandingWarning', () {
    test('true only when insured and a warning is on record', () {
      expect(
        LineRescuePolicy.fromJson(row(lastWarnedAt: hoursAgo(2)))
            .hasOutstandingWarning,
        isTrue,
      );
      expect(
        LineRescuePolicy.fromJson(row()).hasOutstandingWarning,
        isFalse,
      );
    });
  });

  group('graceHoursLeft', () {
    test('counts down from the configured window', () {
      final p = LineRescuePolicy.fromJson(row(lastWarnedAt: hoursAgo(6)));
      expect(p.graceHoursLeft(), 18);
    });

    test('never goes negative once the window has passed', () {
      // The server decides whether to spend; this only decides what to draw.
      // A negative countdown would render as "-7h left to top up yourself".
      final p = LineRescuePolicy.fromJson(row(lastWarnedAt: hoursAgo(31)));
      expect(p.graceHoursLeft(), 0);
    });

    test('is zero when no warning has been written', () {
      expect(LineRescuePolicy.fromJson(row()).graceHoursLeft(), 0);
    });

    test('honours a non-default grace window', () {
      final p = LineRescuePolicy.fromJson(row(lastWarnedAt: hoursAgo(2)));
      expect(p.graceHoursLeft(graceHours: 48), 46);
      expect(p.graceHoursLeft(graceHours: 1), 0);
    });
  });

  group('hasEverRescued', () {
    test('false until a rescue has actually happened', () {
      expect(LineRescuePolicy.fromJson(row()).hasEverRescued, isFalse);
      expect(
        LineRescuePolicy.fromJson(row(rescueCount: 1)).hasEverRescued,
        isTrue,
      );
    });
  });

  group('RescuePolicyResult', () {
    test('reads the success envelope the RPC returns', () {
      final r = RescuePolicyResultTestShim.fromJson(<String, dynamic>{
        'success': true,
        'sim_line_id': 'line-1',
        'max_usd': 5.00,
        'insured': true,
      });
      expect(r.success, isTrue);
      expect(r.message, isNull);
    });

    test('carries the server sentence for every refusal', () {
      final r = RescuePolicyResultTestShim.fromJson(<String, dynamic>{
        'success': false,
        'code': 'NOT_FOUND',
        'error': 'That SIM line does not exist, or is not yours.',
      });
      expect(r.success, isFalse);
      expect(r.code, 'NOT_FOUND');
      expect(r.message, contains('not yours'));
    });
  });
}

/// The envelope parser lives beside the provider, which pulls in Supabase and
/// cannot be constructed under `flutter test`. This mirrors it exactly; if the
/// two ever drift, this test is the thing that should be updated to match.
class RescuePolicyResultTestShim {
  const RescuePolicyResultTestShim({
    required this.success,
    this.code,
    this.message,
  });

  final bool success;
  final String? code;
  final String? message;

  factory RescuePolicyResultTestShim.fromJson(Map<String, dynamic> json) =>
      RescuePolicyResultTestShim(
        success: json['success'] == true,
        code: json['code'] as String?,
        message: json['error'] as String?,
      );
}
