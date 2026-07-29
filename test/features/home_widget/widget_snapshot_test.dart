import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
import 'package:keep_sims/features/home_widget/domain/widget_snapshot.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/usage_forecast_model.dart';

/// G4 — home-screen widget. These cover the three ways this feature can lie to
/// a traveller who is looking at a home screen instead of the app: it can pick
/// the wrong SIM to headline, it can print a number the data does not support,
/// or it can leak something onto a screen the user never opened.
void main() {
  final DateTime now = DateTime.utc(2026, 7, 29, 12);

  SimLine line({
    String id = 'l-1',
    String phoneNumber = '+96891234567',
    String? nickname,
    String status = 'active',
    bool protectionPaused = false,
    DateTime? validityExpiresAt,
    DateTime? nextTopupDue,
  }) => SimLine(
    id: id,
    userId: 'u-1',
    phoneNumber: phoneNumber,
    nickname: nickname,
    status: status,
    protectionPaused: protectionPaused,
    validityExpiresAt: validityExpiresAt,
    nextTopupDue: nextTopupDue,
  );

  UserEsim esim({
    String id = 'e-1',
    String bundleName = '1 GB Test Plan (7 Days)',
    String status = 'active',
    int remainingMb = 1024,
    int totalMb = 1024,
    DateTime? expiresAt,
  }) => UserEsim(
    id: id,
    userId: 'u-1',
    esimOrderId: 'o-1',
    iccid: '8944',
    lpaActivationCode: '',
    qrCodeUrl: '',
    bundleName: bundleName,
    provider: 'esim_go',
    status: status,
    dataRemainingMb: remainingMb,
    dataTotalMb: totalMb,
    purchasedAt: now,
    expiresAt: expiresAt,
    createdAt: now,
    updatedAt: now,
  );

  UsageForecast forecast({
    String id = 'f-1',
    String? simLineId = 'l-1',
    String? esimId,
    String method = 'carrier_rule',
    DateTime? predictedDepletionAt,
    int? daysRemaining,
    int alertLeadDays = 7,
  }) => UsageForecast(
    id: id,
    userId: 'u-1',
    simLineId: simLineId,
    esimId: esimId,
    subjectKind: esimId == null ? 'sim_line' : 'esim',
    method: method,
    confidence: 'medium',
    predictedDepletionAt: predictedDepletionAt,
    daysRemaining: daysRemaining,
    alertLeadDays: alertLeadDays,
  );

  group('formatting', () {
    test('megabytes read as GB above 1024 and drop a trailing .0', () {
      expect(formatDataRemaining(0), equals('0 MB'));
      expect(formatDataRemaining(512), equals('512 MB'));
      expect(formatDataRemaining(1024), equals('1 GB'));
      expect(formatDataRemaining(1536), equals('1.5 GB'));
      expect(formatDataRemaining(20480), equals('20 GB'));
    });

    test('a phone number is reduced to its last four digits', () {
      expect(maskPhoneNumber('+968 9123 4567'), equals('•••• 4567'));
      expect(maskPhoneNumber('+92 300 1234567'), equals('•••• 4567'));
      expect(maskPhoneNumber('12'), equals('••••'));
    });

    test('a part-day remaining still counts as a day, not zero', () {
      expect(daysBetween(now, now.add(const Duration(hours: 6))), equals(1));
      expect(daysBetween(now, now.add(const Duration(days: 17))), equals(17));
      expect(daysBetween(now, now), equals(0));
      expect(daysBetween(now, now.subtract(const Duration(days: 2))), equals(-2));
    });

    test('the day words match what the native renderers re-derive', () {
      expect(countdownLabel(0), equals('expired'));
      expect(countdownLabel(1), equals('day left'));
      expect(countdownLabel(17), equals('days left'));
      expect(countdownPhrase(-3), equals('expired'));
      expect(countdownPhrase(1), equals('1 day left'));
      expect(countdownPhrase(17), equals('17 days left'));
    });
  });

  group('subject selection', () {
    test('the most urgent subject headlines the widget', () {
      final snapshot = buildWidgetSnapshot(
        signedIn: true,
        now: now,
        lines: [
          line(id: 'far', nickname: 'Home PK'),
          line(id: 'near', nickname: 'Oman work'),
        ],
        forecasts: [
          forecast(id: 'f-far', simLineId: 'far', predictedDepletionAt: now.add(const Duration(days: 73))),
          forecast(id: 'f-near', simLineId: 'near', predictedDepletionAt: now.add(const Duration(days: 4))),
        ],
      );

      expect(snapshot.subjects.first.title, equals('Oman work'));
      expect(snapshot.subjects.first.metric, equals('4'));
      expect(snapshot.subjects.first.severity, equals(WidgetSeverity.critical));
      expect(snapshot.subjects.last.title, equals('Home PK'));
    });

    test('a paused line sorts last however soon it expires', () {
      final snapshot = buildWidgetSnapshot(
        signedIn: true,
        now: now,
        lines: [
          line(id: 'paused', nickname: 'Dormant', protectionPaused: true),
          line(id: 'live', nickname: 'Live'),
        ],
        forecasts: [
          forecast(id: 'f-p', simLineId: 'paused', predictedDepletionAt: now.add(const Duration(days: 1))),
          forecast(id: 'f-l', simLineId: 'live', predictedDepletionAt: now.add(const Duration(days: 40))),
        ],
      );

      expect(snapshot.subjects.first.title, equals('Live'));
      expect(snapshot.subjects.last.title, equals('Dormant'));
      expect(snapshot.subjects.last.severity, equals(WidgetSeverity.paused));
      expect(snapshot.subjects.last.subtitle, equals('Protection paused'));
    });

    test('the alert lead day, not a fixed number, is what turns a line red', () {
      // G1 stores the lead per forecast. A line 10 days out is critical when
      // its own lead is 14 and merely a warning when the lead is the default 7.
      WidgetSeverity severityWithLead(int lead) => buildWidgetSnapshot(
        signedIn: true,
        now: now,
        lines: [line()],
        forecasts: [
          forecast(
            predictedDepletionAt: now.add(const Duration(days: 10)),
            alertLeadDays: lead,
          ),
        ],
      ).subjects.first.severity;

      expect(severityWithLead(14), equals(WidgetSeverity.critical));
      expect(severityWithLead(7), equals(WidgetSeverity.warning));
    });

    test('no session publishes an empty payload, not the last user\'s lines', () {
      final snapshot = buildWidgetSnapshot(
        signedIn: false,
        now: now,
        lines: [line(nickname: 'Should not appear')],
        esims: [esim()],
      );

      expect(snapshot.signedIn, isFalse);
      expect(snapshot.subjects, isEmpty);
      expect(snapshot.encode(), isNot(contains('Should not appear')));
    });

    test('an account with nothing in it says so instead of rendering blank', () {
      final snapshot = buildWidgetSnapshot(signedIn: true, now: now);

      expect(snapshot.subjects, isEmpty);
      expect(snapshot.emptyMessage, isNotEmpty);
    });

    test('at most five subjects are published', () {
      final snapshot = buildWidgetSnapshot(
        signedIn: true,
        now: now,
        lines: [for (int i = 0; i < 10; i++) line(id: 'l-$i', nickname: 'Line $i')],
      );

      expect(snapshot.subjects.length, equals(kWidgetMaxSubjects));
    });
  });

  group('SIM lines', () {
    test('the countdown falls back through forecast, validity, next refill', () {
      String metricOf({
        DateTime? forecastAt,
        DateTime? validity,
        DateTime? nextDue,
      }) => buildWidgetSnapshot(
        signedIn: true,
        now: now,
        lines: [line(validityExpiresAt: validity, nextTopupDue: nextDue)],
        forecasts: [
          if (forecastAt != null) forecast(predictedDepletionAt: forecastAt),
        ],
      ).subjects.first.metric;

      expect(
        metricOf(
          forecastAt: now.add(const Duration(days: 5)),
          validity: now.add(const Duration(days: 30)),
          nextDue: now.add(const Duration(days: 60)),
        ),
        equals('5'),
      );
      expect(
        metricOf(
          validity: now.add(const Duration(days: 30)),
          nextDue: now.add(const Duration(days: 60)),
        ),
        equals('30'),
      );
      expect(metricOf(nextDue: now.add(const Duration(days: 60))), equals('60'));
    });

    test('a line with nothing to count down admits it rather than showing 0', () {
      final subject = buildWidgetSnapshot(
        signedIn: true,
        now: now,
        lines: [line()],
      ).subjects.first;

      expect(subject.metric, equals('—'));
      expect(subject.metricLabel, equals('no expiry known'));
      expect(subject.daysRemaining, isNull);
      expect(subject.metricIsCountdown, isFalse);
    });

    test('a measured forecast is labelled differently from an estimate', () {
      String subtitleFor(String method) => buildWidgetSnapshot(
        signedIn: true,
        now: now,
        lines: [line()],
        forecasts: [
          forecast(
            method: method,
            predictedDepletionAt: now.add(const Duration(days: 30)),
          ),
        ],
      ).subjects.first.subtitle;

      expect(subtitleFor('topup_history'), equals('Measured from your refills'));
      expect(subtitleFor('carrier_rule'), equals('Estimated'));
    });

    test('an expired line reads as expired, never as a negative day count', () {
      final subject = buildWidgetSnapshot(
        signedIn: true,
        now: now,
        lines: [line()],
        forecasts: [
          forecast(predictedDepletionAt: now.subtract(const Duration(days: 3))),
        ],
      ).subjects.first;

      expect(subject.metric, equals('0'));
      expect(subject.metricLabel, equals('expired'));
      expect(subject.severity, equals(WidgetSeverity.critical));
    });
  });

  group('eSIMs', () {
    test('data remaining drives the metric and the bar', () {
      final subject = buildWidgetSnapshot(
        signedIn: true,
        now: now,
        esims: [esim(remainingMb: 512, totalMb: 2048)],
      ).subjects.first;

      expect(subject.metric, equals('512 MB'));
      expect(subject.metricLabel, equals('data left'));
      expect(subject.percent, equals(25));
      expect(subject.severity, equals(WidgetSeverity.warning));
      // Megabytes must never be recomputed from a clock by the native side.
      expect(subject.metricIsCountdown, isFalse);
    });

    test('an almost-empty eSIM is critical even with weeks of validity left', () {
      final subject = buildWidgetSnapshot(
        signedIn: true,
        now: now,
        esims: [
          esim(
            remainingMb: 80,
            totalMb: 1024,
            expiresAt: now.add(const Duration(days: 25)),
          ),
        ],
      ).subjects.first;

      expect(subject.percent, equals(8));
      expect(subject.severity, equals(WidgetSeverity.critical));
    });

    test('undelivered orders are not rendered as 0 MB tiles', () {
      final snapshot = buildWidgetSnapshot(
        signedIn: true,
        now: now,
        esims: [
          esim(id: 'p', status: 'pending', remainingMb: 0, totalMb: 0),
          esim(id: 'f', status: 'failed', remainingMb: 0, totalMb: 0),
          esim(id: 'a', status: 'active'),
        ],
      );

      expect(snapshot.subjects.map((s) => s.id), equals(['a']));
    });

    test('a bundle with no supplier expiry borrows G1\'s fitted prediction', () {
      final subject = buildWidgetSnapshot(
        signedIn: true,
        now: now,
        esims: [esim(remainingMb: 900, totalMb: 1024)],
        forecasts: [
          forecast(
            id: 'f-e',
            simLineId: null,
            esimId: 'e-1',
            method: 'esim_usage',
            predictedDepletionAt: now.add(const Duration(days: 11)),
          ),
        ],
      ).subjects.first;

      expect(subject.daysRemaining, equals(11));
      expect(subject.subtitle, equals('eSIM · 11 days left'));
      expect(subject.depletesAt, isNotNull);
    });
  });

  group('payload', () {
    test('carries no phone number, ICCID or balance', () {
      final encoded = buildWidgetSnapshot(
        signedIn: true,
        now: now,
        lines: [line(phoneNumber: '+96891234567')],
        esims: [esim()],
      ).encode();

      expect(encoded, isNot(contains('96891234567')));
      expect(encoded, isNot(contains('8944')));
      expect(encoded, contains('•••• 4567'));
    });

    test('is stamped with the schema the native renderers check', () {
      final decoded =
          jsonDecode(
                buildWidgetSnapshot(
                  signedIn: true,
                  now: now,
                  lines: [line()],
                ).encode(),
              )
              as Map<String, dynamic>;

      expect(decoded['schema'], equals(kWidgetSnapshotSchema));
      expect(decoded['generated_at_ms'], equals(now.millisecondsSinceEpoch));
      expect((decoded['subjects'] as List).first['deep_link'], startsWith('keepsims://widget/'));
    });

    test('identical inputs encode identically, so nothing is republished', () {
      String encode() => buildWidgetSnapshot(
        signedIn: true,
        now: now,
        lines: [line(nickname: 'A'), line(id: 'l-2', nickname: 'B')],
      ).encode();

      expect(encode(), equals(encode()));
    });
  });

  group('deep links', () {
    test('our own links resolve to routes', () {
      expect(
        widgetDeepLinkToRoute(Uri.parse('keepsims://widget/line/abc-123')),
        equals('/sim-lines/detail/abc-123'),
      );
      expect(widgetDeepLinkToRoute(Uri.parse('keepsims://widget/esim')), equals('/esim'));
      expect(widgetDeepLinkToRoute(Uri.parse('keepsims://widget/home')), equals('/home'));
      expect(widgetDeepLinkToRoute(Uri.parse('keepsims://widget/line')), equals('/sim-lines'));
    });

    test('anything else is refused rather than followed', () {
      expect(widgetDeepLinkToRoute(null), isNull);
      expect(widgetDeepLinkToRoute(Uri.parse('https://evil.example/x')), isNull);
      expect(widgetDeepLinkToRoute(Uri.parse('keepsims://elsewhere/line/1')), isNull);
      expect(widgetDeepLinkToRoute(Uri.parse('keepsims://widget/settings')), isNull);
    });
  });
}
