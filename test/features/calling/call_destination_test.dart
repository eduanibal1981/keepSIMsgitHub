import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/calling/domain/call_destination.dart';

void main() {
  test('local numbers need an explicitly confirmed country', () {
    expect(CallDestination.resolve('01012345678').needsCountry, isTrue);
    expect(CallDestination.resolve('92312854').e164, isNull);
  });
  test('Egyptian trunk prefix is removed after choosing Egypt', () {
    expect(
      CallDestination.resolve('010 1234 5678', countryIso: 'EG').e164,
      '+201012345678',
    );
    expect(
      CallDestination.resolve('01112345678', countryIso: 'EG').e164,
      '+201112345678',
    );
  });
  test('Omani national numbers keep all eight digits', () {
    expect(
      CallDestination.resolve('9231 2854', countryIso: 'OM').e164,
      '+96892312854',
    );
  });
  test('Italian landlines preserve their significant leading zero', () {
    expect(
      CallDestination.resolve('02 3661 8300', countryIso: 'IT').e164,
      '+390236618300',
    );
  });
  test('international number wins over an unrelated country suggestion', () {
    expect(
      CallDestination.resolve('+966 56 266 8575', countryIso: 'OM').e164,
      '+966562668575',
    );
  });
  test('normalization is idempotent', () {
    final number = CallDestination.resolve(
      '01012345678',
      countryIso: 'EG',
    ).e164!;
    expect(CallDestination.resolve(number).e164, number);
  });
  test('Arabic and Eastern Arabic digits normalize to E164', () {
    expect(
      CallDestination.resolve('٠١٠١٢٣٤٥٦٧٨', countryIso: 'EG').e164,
      '+201012345678',
    );
    expect(
      CallDestination.resolve('۰۱۰۱۲۳۴۵۶۷۸', countryIso: 'EG').e164,
      '+201012345678',
    );
  });
  test('malformed input, extensions and service codes cannot become calls', () {
    for (final value in [
      '++201012345678',
      '+20+1012345678',
      '01012345678 ext 99',
      '01012345678,99',
      '*123#',
      '112',
      '+99912345678',
      '001201012345678',
    ]) {
      expect(
        CallDestination.resolve(value, countryIso: 'EG').isValid,
        isFalse,
        reason: value,
      );
    }
  });
  test('invalid destination country does not default to another country', () {
    expect(
      CallDestination.resolve('01012345678', countryIso: 'XX').e164,
      isNull,
    );
    expect(
      CallDestination.resolve('01012345678', countryIso: 'OM').isValid,
      isFalse,
    );
  });
  test(
    'international exit code from US must be rewritten explicitly with +',
    () {
      expect(
        CallDestination.resolve('01133655570576', countryIso: 'US').isValid,
        isFalse,
      );
    },
  );
}
