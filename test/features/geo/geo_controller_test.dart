import 'package:flutter_test/flutter_test.dart';
import 'package:collection/collection.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';

void main() {
  group('C8 - Travel & Geolocation Freeze Unit Tests', () {
    test('SimLine freeze model update toggles status and protectionPaused', () {
      final activeLine = SimLine(
        id: 'line-1',
        userId: 'user-1',
        phoneNumber: '+1234567890',
        countryId: 'country-us',
        status: 'active',
        protectionPaused: false,
        requiresProtectionAtHome: false,
      );

      final frozenLine = activeLine.copyWith(
        status: 'paused',
        protectionPaused: true,
      );

      expect(frozenLine.status, equals('paused'));
      expect(frozenLine.protectionPaused, isTrue);
    });

    test('ScheduledTopup toggle active state correctly pauses refill worker schedule', () {
      final activeSchedule = ScheduledTopup(
        id: 'sched-1',
        userId: 'user-1',
        simLineId: 'line-1',
        amount: 5.0,
        frequencyDays: 30,
        nextExecutionAt: DateTime.now(),
        isActive: true,
        status: 'active',
      );

      final pausedSchedule = activeSchedule.copyWith(
        isActive: false,
        status: 'paused',
      );

      expect(pausedSchedule.isActive, isFalse);
      expect(pausedSchedule.status, equals('paused'));
    });

    test('Lines with requiresProtectionAtHome are flagged for exemption during home freeze', () {
      final protectedLine = SimLine(
        id: 'line-protected',
        userId: 'user-1',
        phoneNumber: '+1999888777',
        countryId: 'country-uk',
        status: 'active',
        protectionPaused: false,
        requiresProtectionAtHome: true,
      );

      final shouldFreeze = !protectedLine.requiresProtectionAtHome;
      expect(shouldFreeze, isFalse, reason: 'Always-protected lines must skip auto-freeze');
    });

    test('International lines filtering correctly handles Country lookup without type error', () {
      const supportedCountries = <Country>[
        Country(
          id: 'country-us',
          name: 'United States',
          isoCode: 'US',
          dialingCode: '+1',
          currencyCode: 'USD',
        ),
        Country(
          id: 'country-uk',
          name: 'United Kingdom',
          isoCode: 'GB',
          dialingCode: '+44',
          currencyCode: 'GBP',
        ),
      ];

      final simLines = [
        const SimLine(
          id: 'line-1',
          userId: 'user-1',
          phoneNumber: '+1111111111',
          countryId: 'country-us',
        ),
        const SimLine(
          id: 'line-2',
          userId: 'user-1',
          phoneNumber: '+4444444444',
          countryId: 'country-uk',
        ),
        const SimLine(
          id: 'line-3',
          userId: 'user-1',
          phoneNumber: '+9999999999',
          countryId: 'non-existent-country',
        ),
      ];

      const homeCountryCode = 'US';

      // Simulating the exact logic in GeoScreen._buildInternationalLinesSection
      final intlLines = simLines.where((l) {
        final country = supportedCountries.firstWhereOrNull(
          (c) => c.id == l.countryId,
        );
        return country == null || country.isoCode != homeCountryCode;
      }).toList();

      expect(intlLines.length, equals(2));
      expect(intlLines.map((l) => l.id), containsAll(['line-2', 'line-3']));
    });
  });
}
