import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/fx/fx_context.dart';
import 'package:keep_sims/core/fx/money.dart';

const omrDisplay = FxContext(
  currency: 'OMR',
  requestedCurrency: 'OMR',
  rate: 0.385,
  symbol: 'OMR',
  decimalDigits: 3,
  ageHours: 0,
);

void main() {
  test(
    'minute, second and running-cost precision preserve positive values',
    () {
      expect(
        Money.approxLocalRate(0.012, omrDisplay, unit: '/min'),
        '≈ OMR 0.0046/min',
      );
      expect(
        Money.approxLocalRate(0.0002, omrDisplay, unit: '/s'),
        '≈ OMR 0.00008/s',
      );
      expect(
        Money.approxLocalRate(0.0001, omrDisplay, unit: '/s'),
        '≈ OMR 0.00004/s',
      );
      expect(
        Money.approxLocalRate(0.0001, omrDisplay, minDigits: 3),
        '≈ OMR 0.00004',
      );
    },
  );

  test('sub-threshold rates are never displayed as zero or free', () {
    expect(
      Money.approxLocalRate(0.00001, omrDisplay, unit: '/s'),
      '≈ < OMR 0.00001/s',
    );
    expect(
      Money.approxLocalRate(1e-10, omrDisplay, maxDigits: 6),
      '≈ < OMR 0.000001',
    );
    expect(Money.approxLocalRate(0, omrDisplay, unit: '/min'), '≈ OMR 0/min');
  });

  test('caller precision is bounded and never reduced for large rates', () {
    expect(
      Money.approxLocalRate(1, omrDisplay, minDigits: 5, maxDigits: 5),
      '≈ OMR 0.38500',
    );
    expect(
      Money.approxLocalRate(1000, omrDisplay, minDigits: 3),
      '≈ OMR 385.000',
    );
    expect(
      () => Money.approxLocalRate(1, omrDisplay, minDigits: 6, maxDigits: 4),
      throwsArgumentError,
    );
    expect(
      () => Money.approxLocalRate(1, omrDisplay, maxDigits: 20),
      throwsArgumentError,
    );
  });

  test('no local rate for fallback, disabled, stale or invalid data', () {
    for (final context in [
      const FxContext(),
      omrDisplay.copyWith(enabled: false),
      omrDisplay.copyWith(stale: true),
      omrDisplay.copyWith(rate: 0),
      omrDisplay.copyWith(rate: double.infinity),
    ]) {
      expect(Money.approxLocalRate(0.012, context), isNull);
    }
    for (final amount in [-1.0, double.nan, double.infinity]) {
      expect(Money.approxLocalRate(amount, omrDisplay), isNull);
    }
    expect(
      Money.approxLocalRate(double.maxFinite, omrDisplay.copyWith(rate: 10)),
      isNull,
    );
  });

  test('threshold boundaries and symbol spacing remain readable', () {
    const fx = FxContext(currency: 'EUR', rate: 1, symbol: '€');
    expect(Money.approxLocalRate(0.00001, fx), '≈ €0.00001');
    expect(Money.approxLocalRate(0.000009, fx), '≈ < €0.00001');
    expect(Money.approxLocalRate(0.1, fx, minDigits: 3), '≈ €0.100');
    expect(Money.approxLocal(12.5, omrDisplay), '≈ OMR 4.813');
  });
}
