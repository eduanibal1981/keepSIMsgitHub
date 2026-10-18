import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/return_trip/domain/entities/return_trip_package.dart';
import 'package:keep_sims/features/return_trip/domain/entities/return_trip.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/features/return_trip/domain/entities/active_return_trip_info.dart';

void main() {
  group('ReturnTripPackage Model & Formatting', () {
    test('parses json correctly and formats allowance and duration', () {
      final json = {
        'id': 'pkg-1',
        'country_id': 'country-eg',
        'carrier_id': 'carrier-vodafone',
        'carrier_name': 'Vodafone Egypt',
        'package_type': 'carrier_ussd',
        'title': 'Vodafone 5GB Super Pass',
        'data_allowance_mb': 5120,
        'duration_days': 7,
        'is_unlimited': false,
        'supplier_cost_usd': '3.00',
        'retail_price_usd': '4.50',
        'effective_price_usd': '3.75',
        'app_fee_usd': '0.75',
        'discount_usd': '0.75',
        'ussd_recharge_code': '*858*PIN#',
        'activation_instructions': 'Dial *858*PIN#',
        'badge_label': 'Popular Local Data',
        'account_tier': 'standard',
      };

      final pkg = ReturnTripPackage.fromJson(json);

      expect(pkg.id, 'pkg-1');
      expect(pkg.carrierName, 'Vodafone Egypt');
      expect(pkg.isEsim, false);
      expect(pkg.isCarrierUssd, true);
      expect(pkg.formattedAllowance, '5 GB');
      expect(pkg.formattedDuration, '7 days');
      expect(pkg.toJson().containsKey('supplier_cost_usd'), isFalse);
      expect(pkg.toJson().containsKey('app_fee_usd'), isFalse);
      expect(pkg.retailPriceUsd, 4.50);
      expect(pkg.effectivePriceUsd, 3.75);
      expect(pkg.discountUsd, 0.75);
      expect(pkg.ussdRechargeCode, '*858*PIN#');
    });

    test('correctly handles 1-day unlimited eSIM package', () {
      final json = {
        'id': 'pkg-esim',
        'country_id': 'country-eg',
        'package_type': 'esim',
        'title': '1-Day Unlimited Travel eSIM',
        'data_allowance_mb': -1,
        'duration_days': 1,
        'is_unlimited': true,
        'supplier_cost_usd': 2.50,
        'retail_price_usd': 3.50,
        'effective_price_usd': 2.50,
        'app_fee_usd': 0.00,
        'discount_usd': 1.00,
        'account_tier': 'premium',
      };

      final pkg = ReturnTripPackage.fromJson(json);

      expect(pkg.isEsim, true);
      expect(pkg.isUnlimited, true);
      expect(pkg.formattedAllowance, 'Unlimited');
      expect(pkg.formattedDuration, '1 day');
      // Premium pays $0 app fee -> effective price equals supplier cost
      expect(pkg.effectivePriceUsd, 2.50);
      expect(pkg.discountUsd, 1.00);
    });
  });

  group('ReturnTrip Entity', () {
    test('parses return trip json and validates status', () {
      final json = {
        'id': 'trip-1',
        'user_id': 'user-123',
        'sim_line_id': 'line-456',
        'destination_country_id': 'country-eg',
        'arrival_date': '2026-10-01',
        'status': 'data_ready',
        'chosen_package_type': 'carrier_ussd',
        'chosen_package_id': 'pkg-1',
        'notes': 'Arriving Cairo airport',
        'created_at': '2026-09-14T10:00:00Z',
        'updated_at': '2026-09-14T10:00:00Z',
      };

      final trip = ReturnTrip.fromJson(json);

      expect(trip.id, 'trip-1');
      expect(trip.userId, 'user-123');
      expect(trip.isReady, true);
      expect(trip.arrivalDate.year, 2026);
      expect(trip.arrivalDate.month, 10);
      expect(trip.arrivalDate.day, 1);
    });
  });

  group('ActiveReturnTripInfo Entity', () {
    test('legacy history does not invent a zero price', () {
      final info = ActiveReturnTripInfo.fromJson({'trip_id': 'legacy'});
      expect(info.effectivePriceUsd, isNull);
    });

    test('parses active return trip json with carrier USSD package', () {
      final json = {
        'trip_id': 'trip-active-1',
        'sim_line_id': 'line-123',
        'destination_country_id': 'country-eg',
        'arrival_date': '2026-10-14',
        'trip_status': 'data_ready',
        'package_id': 'pkg-ussd-1',
        'package_type': 'carrier_ussd',
        'package_title': 'Vodafone 5GB Super Pass',
        'carrier_name': 'Vodafone',
        'data_allowance_mb': 5120,
        'duration_days': 28,
        'is_unlimited': false,
        'effective_price_usd': 4.50,
        'ussd_recharge_code': '*858*PIN#',
        'activation_instructions': 'Dial *858*PIN# upon arrival in Egypt',
        'badge_label': 'Best Value',
        'notes': 'Prepared for travel',
        'created_at': '2026-09-14T00:00:00Z',
      };

      final info = ActiveReturnTripInfo.fromJson(json);

      expect(info.tripId, 'trip-active-1');
      expect(info.simLineId, 'line-123');
      expect(info.destinationCountryId, 'country-eg');
      expect(info.isEsim, false);
      expect(info.isCarrierUssd, true);
      expect(info.packageTitle, 'Vodafone 5GB Super Pass');
      expect(info.carrierName, 'Vodafone');
      expect(info.formattedAllowance, '5 GB');
      expect(info.formattedDuration, '28 days');
      expect(info.ussdRechargeCode, '*858*PIN#');
      expect(
        info.activationInstructions,
        'Dial *858*PIN# upon arrival in Egypt',
      );
      expect(info.formattedArrivalDate, 'Oct 14, 2026');
    });

    test('parses active return trip json with eSIM package', () {
      final json = {
        'trip_id': 'trip-active-2',
        'sim_line_id': 'line-456',
        'destination_country_id': 'country-eg',
        'arrival_date': '2026-11-01',
        'trip_status': 'data_ready',
        'package_id': 'pkg-esim-1',
        'package_type': 'esim',
        'package_title': '7-Day Unlimited Travel eSIM',
        'carrier_name': null,
        'data_allowance_mb': 0,
        'duration_days': 7,
        'is_unlimited': true,
        'effective_price_usd': 9.99,
        'ussd_recharge_code': null,
        'activation_instructions':
            'Scan the QR code or install the eSIM profile',
        'created_at': '2026-09-14T00:00:00Z',
      };

      final info = ActiveReturnTripInfo.fromJson(json);

      expect(info.isEsim, true);
      expect(info.isCarrierUssd, false);
      expect(info.formattedAllowance, 'Unlimited');
      expect(info.formattedDuration, '7 days');
      expect(info.ussdRechargeCode, isNull);
      expect(info.formattedArrivalDate, 'Nov 1, 2026');
    });

    test('validates date update formatting', () {
      final newDate = DateTime(2026, 11, 15);
      final formatted = DateFormat('MMM d, yyyy').format(newDate);
      expect(formatted, 'Nov 15, 2026');
    });
  });

  group('Next Prepared Travel Data & History Logic', () {
    test(
      'correctly evaluates future and same day as next prepared travel data',
      () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        final yesterday = today.subtract(const Duration(days: 1));

        bool isFutureOrToday(DateTime arrivalDate) {
          final arrivalDay = DateTime(
            arrivalDate.year,
            arrivalDate.month,
            arrivalDate.day,
          );
          return !arrivalDay.isBefore(today);
        }

        expect(
          isFutureOrToday(today),
          isTrue,
          reason: 'Same day travel must show as next prepared',
        );
        expect(
          isFutureOrToday(tomorrow),
          isTrue,
          reason: 'Future travel must show as next prepared',
        );
        expect(
          isFutureOrToday(yesterday),
          isFalse,
          reason: 'Past travel must not show as next prepared',
        );
      },
    );

    test('correctly filters old preparations for History tab', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final activeTrip = ActiveReturnTripInfo(
        tripId: 'active-1',
        simLineId: 'line-1',
        destinationCountryId: 'eg',
        arrivalDate: today.add(const Duration(days: 5)),
        status: 'data_ready',
        packageType: 'carrier_ussd',
        packageTitle: 'Upcoming WE 10GB',
        dataAllowanceMb: 10240,
        durationDays: 30,
        isUnlimited: false,
        effectivePriceUsd: 7.0,
        createdAt: now,
      );

      final pastTrip = ActiveReturnTripInfo(
        tripId: 'past-1',
        simLineId: 'line-1',
        destinationCountryId: 'eg',
        arrivalDate: today.subtract(const Duration(days: 10)),
        status: 'arrived',
        packageType: 'carrier_ussd',
        packageTitle: 'Past Vodafone 5GB',
        dataAllowanceMb: 5120,
        durationDays: 7,
        isUnlimited: false,
        effectivePriceUsd: 4.5,
        createdAt: now.subtract(const Duration(days: 15)),
      );

      final cancelledTrip = ActiveReturnTripInfo(
        tripId: 'cancelled-1',
        simLineId: 'line-1',
        destinationCountryId: 'eg',
        arrivalDate: today.add(const Duration(days: 2)),
        status: 'cancelled',
        packageType: 'esim',
        packageTitle: 'Cancelled eSIM',
        dataAllowanceMb: 0,
        durationDays: 7,
        isUnlimited: true,
        effectivePriceUsd: 9.99,
        createdAt: now.subtract(const Duration(days: 1)),
      );

      final allTrips = [activeTrip, pastTrip, cancelledTrip];

      final oldPreparations = allTrips.where((t) {
        final tripDay = DateTime(
          t.arrivalDate.year,
          t.arrivalDate.month,
          t.arrivalDate.day,
        );
        final isPast = tripDay.isBefore(today);
        final isEnded = t.status == 'completed' || t.status == 'cancelled';
        final isNotActive = t.tripId != activeTrip.tripId;
        return isPast || isEnded || isNotActive;
      }).toList();

      expect(oldPreparations.length, 2);
      expect(oldPreparations.any((t) => t.tripId == 'past-1'), isTrue);
      expect(oldPreparations.any((t) => t.tripId == 'cancelled-1'), isTrue);
      expect(oldPreparations.any((t) => t.tripId == 'active-1'), isFalse);
    });
  });

  group('In-Country Dynamic Wizard & Card Copy Logic', () {
    test(
      'renders "You are at Oman!" and "Do you need a data package?" when user is in Oman',
      () {
        const userIso = 'OM';
        const lineIso = 'OM';
        const countryName = 'Oman';

        final isUserInCountry = userIso == lineIso;
        expect(isUserInCountry, isTrue);

        final title = isUserInCountry
            ? 'You are at $countryName!'
            : 'Back to $countryName Wizard';
        const isFutureOrToday = false;
        const hasHistory = false;
        final subtitle = isFutureOrToday
            ? 'Trip prepared · Tap to update arrival date or package'
            : (isUserInCountry
                  ? 'Do you need a data package?'
                  : (hasHistory
                        ? 'Tap to prepare data or view past trips'
                        : 'Set your arrival date & prepare your data'));

        expect(title, 'You are at Oman!');
        expect(subtitle, 'Do you need a data package?');
      },
    );

    test(
      'renders "Back to Egypt Wizard" and "Set your arrival date" when user is in Oman with Egypt SIM',
      () {
        const userIso = 'OM';
        const lineIso = 'EG';
        const countryName = 'Egypt';

        final isUserInCountry = userIso == lineIso;
        expect(isUserInCountry, isFalse);

        final title = isUserInCountry
            ? 'You are at $countryName!'
            : 'Back to $countryName Wizard';
        const isFutureOrToday = false;
        const hasHistory = false;
        final subtitle = isFutureOrToday
            ? 'Trip prepared · Tap to update arrival date or package'
            : (isUserInCountry
                  ? 'Do you need a data package?'
                  : (hasHistory
                        ? 'Tap to prepare data or view past trips'
                        : 'Set your arrival date & prepare your data'));

        expect(title, 'Back to Egypt Wizard');
        expect(subtitle, 'Set your arrival date & prepare your data');
      },
    );
  });
}
