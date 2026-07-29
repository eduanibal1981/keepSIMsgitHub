import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/price_watch/data/models/offer_price_watch_model.dart';

/// G2 — price-drop / best-offer watch. These cover the edges where the client
/// reinterprets what the nightly job wrote, and the two places where getting it
/// wrong shows the user a wrong number or a button that silently does nothing.
void main() {
  Map<String, dynamic> row({
    String source = 'topup',
    String countryCode = 'PK',
    String? carrierCode = 'Zong',
    String origin = 'auto',
    bool isActive = true,
    double? thresholdPercent,
    double? lastBestUsd,
    double? lastBaselineUsd,
    String? lastCheckedAt = '2026-07-29T02:40:00Z',
  }) => {
    'id': 'w-1',
    'user_id': 'u-1',
    'source': source,
    'country_code': countryCode,
    'carrier_code': carrierCode,
    'origin': origin,
    'is_active': isActive,
    'threshold_percent': thresholdPercent,
    'last_best_usd': lastBestUsd,
    'last_baseline_usd': lastBaselineUsd,
    'last_alerted_best_usd': null,
    'last_alert_at': null,
    'last_checked_at': lastCheckedAt,
    'created_at': '2026-07-29T12:42:00Z',
    'updated_at': '2026-07-29T12:42:00Z',
  };

  group('OfferPriceWatch deserialization', () {
    test('maps the snake_case row the table actually returns', () {
      final w = OfferPriceWatch.fromJson(
        row(lastBestUsd: 0.67, lastBaselineUsd: 1.11),
      );

      expect(w.id, equals('w-1'));
      expect(w.source, equals('topup'));
      expect(w.countryCode, equals('PK'));
      expect(w.carrierCode, equals('Zong'));
      expect(w.origin, equals('auto'));
      expect(w.isActive, isTrue);
      expect(w.lastBestUsd, equals(0.67));
      expect(w.lastCheckedAt, isNotNull);
    });

    test('an eSIM watch carries no carrier, matching the CHECK constraint', () {
      final w = OfferPriceWatch.fromJson(
        row(source: 'esim', countryCode: 'DE', carrierCode: null),
      );

      expect(w.isEsim, isTrue);
      expect(w.carrierCode, isNull);
      expect(w.subjectLabel, equals('DE'));
      expect(w.unitSuffix, equals('/GB'));
    });

    test('a top-up watch labels country and carrier, with no per-GB unit', () {
      final w = OfferPriceWatch.fromJson(row());

      expect(w.isEsim, isFalse);
      expect(w.subjectLabel, equals('PK · Zong'));
      expect(w.unitSuffix, isEmpty);
    });
  });

  group('changePercent', () {
    test('a fall from 1.11 to 0.67 is a ~39.6% drop', () {
      final w = OfferPriceWatch.fromJson(
        row(lastBestUsd: 0.67, lastBaselineUsd: 1.11),
      );

      expect(w.changePercent, closeTo(39.64, 0.01));
    });

    test('a rise reads as a negative change rather than being hidden', () {
      final w = OfferPriceWatch.fromJson(
        row(lastBestUsd: 1.50, lastBaselineUsd: 1.00),
      );

      expect(w.changePercent, closeTo(-50.0, 0.01));
    });

    test('is null before the job has priced the subject', () {
      final w = OfferPriceWatch.fromJson(row());

      expect(w.changePercent, isNull);
      expect(w.hasPrice, isFalse);
    });

    test('never divides by a zero baseline', () {
      final w = OfferPriceWatch.fromJson(
        row(lastBestUsd: 5.0, lastBaselineUsd: 0.0),
      );

      expect(w.changePercent, isNull);
    });
  });

  group('hasPrice', () {
    // KW/STC and OM/Omantel are live examples: real SIM lines whose
    // country/carrier pair has no cached offers, so the metric is never
    // produced. The tile must say so instead of rendering "$0.00".
    test('a watched pair the catalog does not cover has no price', () {
      final w = OfferPriceWatch.fromJson(
        row(countryCode: 'KW', carrierCode: 'STC', lastCheckedAt: null),
      );

      expect(w.hasPrice, isFalse);
      expect(w.lastCheckedAt, isNull);
    });

    test('zero is not a price', () {
      expect(
        OfferPriceWatch.fromJson(row(lastBestUsd: 0.0)).hasPrice,
        isFalse,
      );
    });
  });

  group('threshold', () {
    test('falls back to the server default when the user has not set one', () {
      final w = OfferPriceWatch.fromJson(row());

      expect(w.effectiveThreshold(10.0), equals(10.0));
    });

    test('a per-watch threshold overrides the default', () {
      final w = OfferPriceWatch.fromJson(row(thresholdPercent: 25.0));

      expect(w.effectiveThreshold(10.0), equals(25.0));
    });
  });

  group('origin drives the affordance', () {
    // Deleting an auto row would appear to work and then reappear on the next
    // nightly sync_auto_price_watches(), because the job recreates one for
    // every active SIM line. Auto rows get a switch; only user rows get a
    // delete button.
    test('an auto row is marked auto', () {
      expect(OfferPriceWatch.fromJson(row()).isAuto, isTrue);
    });

    test('a row created from the app is not', () {
      expect(
        OfferPriceWatch.fromJson(
          row(source: 'esim', carrierCode: null, origin: 'user'),
        ).isAuto,
        isFalse,
      );
    });
  });
}
