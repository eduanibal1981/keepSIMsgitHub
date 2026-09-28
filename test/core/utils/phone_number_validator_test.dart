import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/utils/phone_number_validator.dart';

void main() {
  group('PhoneNumberValidator Oman (+968) Tests', () {
    test('Validates Friendi Mobile Oman starting with 79', () {
      final result = PhoneNumberValidator.validateAndDetect(
        phoneNumber: '79761061',
        countryIsoCode: 'OM',
        dialingCode: '+968',
      );

      expect(result.isValidFormat, isTrue);
      expect(result.carrierStatus, equals('active'));
      expect(result.detectedCarrierName, equals('FRiENDi Mobile Oman'));
    });

    test('Validates Friendi Mobile Oman starting with 98', () {
      final result = PhoneNumberValidator.validateAndDetect(
        phoneNumber: '98400000',
        countryIsoCode: 'OM',
        dialingCode: '+968',
      );

      expect(result.isValidFormat, isTrue);
      expect(result.carrierStatus, equals('active'));
      expect(result.detectedCarrierName, equals('FRiENDi Mobile Oman'));
    });

    test('Validates Omantel starting with 90 (e.g. 90634453)', () {
      final result = PhoneNumberValidator.validateAndDetect(
        phoneNumber: '90634453',
        countryIsoCode: 'OM',
        dialingCode: '+968',
      );

      expect(result.isValidFormat, isTrue);
      expect(result.carrierStatus, equals('active'));
      expect(result.detectedCarrierName, equals('Omantel'));
    });

    test('Validates other Omantel prefixes (91, 92, 93, 99)', () {
      final result = PhoneNumberValidator.validateAndDetect(
        phoneNumber: '91234567',
        countryIsoCode: 'OM',
        dialingCode: '+968',
      );

      expect(result.isValidFormat, isTrue);
      expect(result.carrierStatus, equals('active'));
      expect(result.detectedCarrierName, equals('Omantel'));
    });

    test('Validates Ooredoo Oman (e.g. 94xxxxxx, 72xxxxxx)', () {
      final result = PhoneNumberValidator.validateAndDetect(
        phoneNumber: '94567890',
        countryIsoCode: 'OM',
        dialingCode: '+968',
      );

      expect(result.isValidFormat, isTrue);
      expect(result.carrierStatus, equals('active'));
      expect(result.detectedCarrierName, equals('Ooredoo Oman'));
    });

    test('Validates Vodafone Oman (71xxxxxx, 77xxxxxx)', () {
      final result = PhoneNumberValidator.validateAndDetect(
        phoneNumber: '77123456',
        countryIsoCode: 'OM',
        dialingCode: '+968',
      );

      expect(result.isValidFormat, isTrue);
      expect(result.carrierStatus, equals('active'));
      expect(result.detectedCarrierName, equals('Vodafone Oman'));
    });

    test('Validates Red Bull Mobile Oman (78xxxxxx)', () {
      final result = PhoneNumberValidator.validateAndDetect(
        phoneNumber: '78123456',
        countryIsoCode: 'OM',
        dialingCode: '+968',
      );

      expect(result.isValidFormat, isTrue);
      expect(result.carrierStatus, equals('active'));
      expect(result.detectedCarrierName, equals('Red Bull Mobile Oman'));
    });

    test('Rejects invalid digit length for Oman', () {
      final result = PhoneNumberValidator.validateAndDetect(
        phoneNumber: '7976106', // 7 digits
        countryIsoCode: 'OM',
        dialingCode: '+968',
      );

      expect(result.isValidFormat, isFalse);
      expect(result.carrierStatus, equals('inactive'));
    });

    test('Validates full E.164 +96879761061 when dialingCode is omitted', () {
      final result = PhoneNumberValidator.validateAndDetect(
        phoneNumber: '+96879761061',
        countryIsoCode: 'OM',
      );

      expect(result.isValidFormat, isTrue);
      expect(result.carrierStatus, equals('active'));
      expect(result.detectedCarrierName, equals('FRiENDi Mobile Oman'));
    });

    test('Validates full E.164 +96890634453 when dialingCode is omitted', () {
      final result = PhoneNumberValidator.validateAndDetect(
        phoneNumber: '+96890634453',
        countryIsoCode: 'OM',
      );

      expect(result.isValidFormat, isTrue);
      expect(result.carrierStatus, equals('active'));
      expect(result.detectedCarrierName, equals('Omantel'));
    });
  });
}
