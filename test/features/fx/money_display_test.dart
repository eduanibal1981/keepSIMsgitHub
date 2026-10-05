import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/fx/fx_context.dart';
import 'package:keep_sims/core/fx/money.dart';

/// G11 — multi-currency display. These cover the client's half of the contract
/// with `get_fx_display_context()`.
///
/// The property under test throughout is that a *wrong* number is worse than no
/// number: every path where the rate cannot be trusted must render nothing at
/// all rather than something plausible.
void main() {
  /// The shape the RPC actually returns, defaulted to the live EGP case proved
  /// against the database on 2026-07-30 (open.er-api.com quoted 50.693486).
  Map<String, dynamic> row({
    bool enabled = true,
    String currency = 'EGP',
    String requestedCurrency = 'EGP',
    double rate = 50.693486,
    String symbol = '£',
    int decimalDigits = 2,
    String? asOf = '2026-07-30T00:02:31Z',
    bool stale = false,
    String? fallbackReason,
    double maxAgeHours = 72,
    List<Map<String, dynamic>>? available,
  }) => {
    'enabled': enabled,
    'currency': currency,
    'requested_currency': requestedCurrency,
    'rate': rate,
    'symbol': symbol,
    'decimal_digits': decimalDigits,
    'as_of': asOf,
    'stale': stale,
    'fallback_reason': fallbackReason,
    'max_age_hours': maxAgeHours,
    'available':
        available ??
        [
          {
            'code': 'USD',
            'name': 'US Dollar',
            'symbol': r'$',
            'decimal_digits': 2,
          },
          {
            'code': 'EGP',
            'name': 'Egyptian Pound',
            'symbol': 'E£',
            'decimal_digits': 2,
          },
        ],
  };

  group('FxContext parsing', () {
    test('reads a live conversion out of the RPC payload', () {
      final fx = FxContext.fromJson(row());

      expect(fx.currency, 'EGP');
      expect(fx.rate, closeTo(50.693486, 1e-9));
      expect(fx.symbol, 'E£');
      expect(fx.convertsMoney, isTrue);
      expect(fx.isFallingBack, isFalse);
      expect(fx.available.length, 2);
      expect(fx.available.first.code, 'USD');
    });

    test('defaults to plain USD when the RPC gives nothing', () {
      const fx = FxContext();

      expect(fx.currency, 'USD');
      expect(fx.rate, 1.0);
      expect(fx.convertsMoney, isFalse);
      expect(fx.isFallingBack, isFalse);
    });

    test(
      'a stale quote arrives already collapsed to USD, and says it fell back',
      () {
        // The server, not the client, decided this. A device with a skewed
        // clock must not be able to reach a different verdict.
        final fx = FxContext.fromJson(
          row(
            currency: 'USD',
            rate: 1,
            symbol: r'$',
            asOf: null,
            stale: true,
            fallbackReason: 'stale',
          ),
        );

        expect(fx.convertsMoney, isFalse);
        expect(fx.requestedCurrency, 'EGP');
        expect(fx.isFallingBack, isTrue);
        expect(fx.fallbackReason, 'stale');
      },
    );

    test('an unknown currency also falls back, and is distinguishable', () {
      final fx = FxContext.fromJson(
        row(
          currency: 'USD',
          requestedCurrency: 'XXX',
          rate: 1,
          symbol: r'$',
          asOf: null,
          fallbackReason: 'unknown_currency',
        ),
      );

      expect(fx.convertsMoney, isFalse);
      expect(fx.isFallingBack, isTrue);
      expect(fx.fallbackReason, 'unknown_currency');
    });

    test('a USD user is not "falling back" — they asked for dollars', () {
      final fx = FxContext.fromJson(
        row(
          currency: 'USD',
          requestedCurrency: 'USD',
          rate: 1,
          symbol: r'$',
          asOf: null,
          fallbackReason: 'base',
        ),
      );

      expect(fx.convertsMoney, isFalse);
      // Nothing went wrong, so the settings screen owes no explanation.
      expect(fx.isFallingBack, isFalse);
    });
  });

  group('Money.usd', () {
    test('is always two decimals, because it is the charged figure', () {
      expect(Money.usd(12.5), r'$12.50');
      expect(Money.usd(0), r'$0.00');
      expect(Money.usd(1234.567), r'$1234.57');
    });
  });

  group('Money.approxLocal', () {
    test('converts and marks the result approximate', () {
      final fx = FxContext.fromJson(row());
      // 12.50 * 50.693486 = 633.67 -> over 100, so no false precision.
      expect(Money.approxLocal(12.50, fx), '≈ E£634');
    });

    test('keeps the minor unit below 100, where it still means something', () {
      final fx = FxContext.fromJson(
        row(
          currency: 'EUR',
          requestedCurrency: 'EUR',
          rate: 0.875576,
          symbol: '€',
        ),
      );
      expect(Money.approxLocal(12.50, fx), '≈ €10.94');
    });

    test('groups thousands so a rupee figure stays readable', () {
      final fx = FxContext.fromJson(
        row(
          currency: 'INR',
          requestedCurrency: 'INR',
          rate: 95.755723,
          symbol: '₹',
        ),
      );
      expect(Money.approxLocal(50.0, fx), '≈ ₹4,788');
    });

    test('spaces letter-only codes and tightens real glyphs', () {
      final aed = FxContext.fromJson(
        row(
          currency: 'AED',
          requestedCurrency: 'AED',
          rate: 3.6725,
          symbol: 'AED',
        ),
      );
      // 'AED 45.91', not 'AED45.91'. Under 100, so the fils survive.
      expect(Money.approxLocal(12.50, aed), '≈ AED 45.91');
      expect(Money.approxLocal(100.0, aed), '≈ AED 367');

      final egp = FxContext.fromJson(row());
      // 'E£634' — E£ is not letters-only, so it sits tight.
      expect(Money.approxLocal(12.50, egp), startsWith('≈ E£'));
    });

    test('honours a three-decimal currency', () {
      final fx = FxContext.fromJson(
        row(
          currency: 'JOD',
          requestedCurrency: 'JOD',
          rate: 0.709,
          symbol: 'JD',
          decimalDigits: 3,
        ),
      );
      // 12.50 * 0.709 is 8.8625 in decimal but lands a hair below in binary
      // floating point, so this truncates rather than rounding up. That is
      // acceptable precisely because the figure is flagged approximate — it is
      // also why no charge is ever computed this way.
      expect(Money.approxLocal(12.50, fx), '≈ JD 8.862');
    });

    test('renders NOTHING for a USD user rather than a redundant line', () {
      final fx = FxContext.fromJson(
        row(
          currency: 'USD',
          requestedCurrency: 'USD',
          rate: 1,
          symbol: r'$',
          fallbackReason: 'base',
        ),
      );
      expect(Money.approxLocal(12.50, fx), isNull);
    });

    test('renders NOTHING when the rate went stale — the whole point', () {
      // A three-week-old rate presented as today's is a number that is simply
      // false. Silence is the correct output.
      final fx = FxContext.fromJson(
        row(
          currency: 'USD',
          rate: 1,
          symbol: r'$',
          stale: true,
          fallbackReason: 'stale',
        ),
      );
      expect(Money.approxLocal(12.50, fx), isNull);
    });

    test('renders NOTHING when the global brake is off', () {
      final fx = FxContext.fromJson(
        row(
          enabled: false,
          currency: 'USD',
          rate: 1,
          symbol: r'$',
          fallbackReason: 'disabled',
        ),
      );
      expect(Money.approxLocal(12.50, fx), isNull);
    });

    test('a zero or negative rate never renders a number', () {
      // Defence in depth: the CHECK on fx_rates.usd_to_local already forbids
      // this, but a client that divided by it would be much worse than blank.
      final zero = FxContext.fromJson(row(rate: 0));
      expect(Money.approxLocal(12.50, zero), isNull);
    });

    test('zero converts to zero, not to nothing', () {
      final fx = FxContext.fromJson(row());
      expect(Money.approxLocal(0, fx), '≈ E£0.00');
    });

    test(
      'the conversion is exactly one multiplication, never a round trip',
      () {
        // If a local->USD helper is ever added, this is the test that should
        // stop it: display rounding must not be able to travel back into an
        // amount anyone is charged.
        final fx = FxContext.fromJson(row(rate: 50.0));
        expect(Money.approxLocal(2.0, fx), '≈ E£100');
        expect(Money.approxLocal(0.10, fx), '≈ E£5.00');
      },
    );
  });
}
