import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/roam_calculator/data/models/roam_quote_model.dart';

/// G5 — "Roam or eSIM?" calculator. These cover the client's half of the
/// contract with `roam_or_esim_quote()`: the six verdicts it has to render
/// differently, and the two places where a plausible-looking shortcut would
/// show the user a number that is not true.
void main() {
  /// A full row in the shape the RPC actually returns, defaulted to the live
  /// AE case proved against the database: Zong's 2 GB / 7 day UAE bundle at
  /// $7.19 versus the 1 GB / 7 day eSIM at $2.94.
  Map<String, dynamic> row({
    String verdict = 'esim_cheaper',
    String destinationCountryCode = 'AE',
    String destinationCountryName = 'United Arab Emirates',
    int tripDays = 7,
    int tripDataMb = 1000,
    String? roamingCarrierName = 'Zong',
    String? roamingProductName = 'UAE IR Bundle (2 GB / 7 days)',
    String? roamingProductKind = 'bundle',
    String? roamingScope = 'country',
    int? roamingUnits = 1,
    double? roamingTotalUsd = 7.19,
    bool roamingIsEstimate = true,
    String? roamingSourceUrl = 'https://www.zong.com.pk/international-roaming',
    String? roamingPricedAsOf = '2026-07-29',
    String? esimOfferId = 'esim_go_esim_1GB_7D_AE_V2',
    String? esimBundleName = 'esim_1GB_7D_AE_V2',
    int? esimDataMb = 1000,
    int? esimDurationDays = 7,
    int? esimQuantity = 1,
    double? esimUnitPriceUsd = 2.94,
    double? esimTotalUsd = 2.94,
    bool esimCoversTrip = true,
    double? savingsUsd = 4.25,
  }) => <String, dynamic>{
    'destination_country_code': destinationCountryCode,
    'destination_country_name': destinationCountryName,
    'trip_days': tripDays,
    'trip_data_mb': tripDataMb,
    'roaming_carrier_id': roamingCarrierName == null ? null : 'c-1',
    'roaming_carrier_name': roamingCarrierName,
    'roaming_home_country': roamingCarrierName == null ? null : 'PK',
    'roaming_product_name': roamingProductName,
    'roaming_product_kind': roamingProductKind,
    'roaming_scope': roamingScope,
    'roaming_units': roamingUnits,
    'roaming_total_usd': roamingTotalUsd,
    'roaming_is_estimate': roamingIsEstimate,
    'roaming_source_url': roamingSourceUrl,
    'roaming_priced_as_of': roamingPricedAsOf,
    'esim_offer_id': esimOfferId,
    'esim_bundle_name': esimBundleName,
    'esim_data_mb': esimDataMb,
    'esim_duration_days': esimDurationDays,
    'esim_quantity': esimQuantity,
    'esim_unit_price_usd': esimUnitPriceUsd,
    'esim_total_usd': esimTotalUsd,
    'esim_covers_trip': esimCoversTrip,
    'savings_usd': savingsUsd,
    'verdict': verdict,
  };

  group('deserialization', () {
    test('maps the snake_case row the RPC actually returns', () {
      final RoamQuote q = RoamQuote.fromJson(row());

      expect(q.destinationCountryName, 'United Arab Emirates');
      expect(q.roamingCarrierName, 'Zong');
      expect(q.roamingTotalUsd, 7.19);
      expect(q.esimTotalUsd, 2.94);
      expect(q.savingsUsd, 4.25);
      expect(q.verdict, 'esim_cheaper');
      expect(q.roamingPricedAsOf, DateTime.parse('2026-07-29'));
    });

    test('survives a row with both sides missing', () {
      final RoamQuote q = RoamQuote.fromJson(row(
        verdict: 'no_data',
        roamingCarrierName: null,
        roamingProductName: null,
        roamingProductKind: null,
        roamingScope: null,
        roamingUnits: null,
        roamingTotalUsd: null,
        roamingSourceUrl: null,
        roamingPricedAsOf: null,
        esimOfferId: null,
        esimBundleName: null,
        esimDataMb: null,
        esimDurationDays: null,
        esimQuantity: null,
        esimUnitPriceUsd: null,
        esimTotalUsd: null,
        esimCoversTrip: false,
        savingsUsd: null,
      ));

      expect(q.hasRoaming, isFalse);
      expect(q.hasEsim, isFalse);
      expect(q.isComparable, isFalse);
      expect(q.savingsPercent, isNull);
    });

    test('roaming is an estimate unless the row says otherwise', () {
      expect(RoamQuote.fromJson(row()).roamingIsEstimate, isTrue);
      expect(
        RoamQuote.fromJson(row(roamingIsEstimate: false)).roamingIsEstimate,
        isFalse,
      );
    });
  });

  group('verdicts', () {
    test('esim_cheaper and roaming_cheaper are both comparable outcomes', () {
      // Roaming winning is a real answer, not a failure. Jazz sells 1 GB in
      // the UAE for $3.59 and the screen has to be able to say so.
      expect(RoamQuote.fromJson(row()).isComparable, isTrue);
      expect(
        RoamQuote.fromJson(row(verdict: 'roaming_cheaper')).isComparable,
        isTrue,
      );
      expect(RoamQuote.fromJson(row(verdict: 'tie')).isComparable, isTrue);
    });

    test('esim_partial is NOT comparable even though both sides are priced',
        () {
      // The live catalogue is 1 GB bundles capped at quantity 3, so a 10 GB
      // trip gets 3 GB of eSIM. Calling that a saving would be a lie.
      final RoamQuote q = RoamQuote.fromJson(row(
        verdict: 'esim_partial',
        tripDataMb: 10000,
        tripDays: 30,
        roamingUnits: 5,
        roamingTotalUsd: 35.95,
        esimQuantity: 3,
        esimTotalUsd: 8.82,
        esimCoversTrip: false,
        savingsUsd: null,
      ));

      expect(q.hasRoaming, isTrue);
      expect(q.hasEsim, isTrue);
      expect(q.isComparable, isFalse);
      expect(q.savingsUsd, isNull);
      expect(q.savingsPercent, isNull);
    });

    test('no_esim keeps the roaming side renderable', () {
      final RoamQuote q = RoamQuote.fromJson(row(
        verdict: 'no_esim',
        destinationCountryCode: 'SA',
        destinationCountryName: 'Saudi Arabia',
        esimOfferId: null,
        esimBundleName: null,
        esimDataMb: null,
        esimDurationDays: null,
        esimQuantity: null,
        esimUnitPriceUsd: null,
        esimTotalUsd: null,
        esimCoversTrip: false,
        savingsUsd: null,
      ));

      expect(q.hasRoaming, isTrue);
      expect(q.hasEsim, isFalse);
      expect(q.isComparable, isFalse);
    });

    test('no_roaming_rate keeps the eSIM side renderable', () {
      final RoamQuote q = RoamQuote.fromJson(row(
        verdict: 'no_roaming_rate',
        roamingCarrierName: null,
        roamingProductName: null,
        roamingProductKind: null,
        roamingScope: null,
        roamingUnits: null,
        roamingTotalUsd: null,
        roamingSourceUrl: null,
        roamingPricedAsOf: null,
        savingsUsd: null,
      ));

      expect(q.hasRoaming, isFalse);
      expect(q.hasEsim, isTrue);
      expect(q.isComparable, isFalse);
    });
  });

  group('savingsPercent', () {
    test('is the saving as a share of the roaming price', () {
      final RoamQuote q = RoamQuote.fromJson(row());
      expect(q.savingsPercent, closeTo(4.25 / 7.19 * 100, 0.001));
    });

    test('is null when roaming is free or absent, never a division by zero',
        () {
      expect(
        RoamQuote.fromJson(row(roamingTotalUsd: 0)).savingsPercent,
        isNull,
      );
      expect(
        RoamQuote.fromJson(row(roamingTotalUsd: null)).savingsPercent,
        isNull,
      );
    });

    test('is null when the eSIM costs more, so no chip is drawn', () {
      expect(
        RoamQuote.fromJson(row(verdict: 'roaming_cheaper', savingsUsd: -3.10))
            .savingsPercent,
        isNull,
      );
    });
  });

  group('formatMb', () {
    test('renders sub-gigabyte sizes in megabytes', () {
      expect(RoamQuote.formatMb(500), '500 MB');
      expect(RoamQuote.formatMb(999), '999 MB');
    });

    test('renders whole gigabytes without a decimal point', () {
      expect(RoamQuote.formatMb(1000), '1 GB');
      expect(RoamQuote.formatMb(5000), '5 GB');
      expect(RoamQuote.formatMb(20000), '20 GB');
    });

    test('keeps one decimal for part gigabytes', () {
      // du's weekly bundle is 2.5 GB; rounding it to 2 or 3 misprices the row.
      expect(RoamQuote.formatMb(2500), '2.5 GB');
    });

    test('renders missing or zero as a dash rather than 0 MB', () {
      expect(RoamQuote.formatMb(null), '—');
      expect(RoamQuote.formatMb(0), '—');
    });
  });

  group('detail lines', () {
    test('a single pack is named without a multiplier', () {
      expect(
        RoamQuote.fromJson(row()).roamingDetailLine,
        'UAE IR Bundle (2 GB / 7 days)',
      );
    });

    test('multiple packs lead with the count — the part people miss', () {
      // One $9.53 day pass is not what a 3-day trip costs.
      final RoamQuote q = RoamQuote.fromJson(row(
        tripDays: 3,
        roamingCarrierName: 'du',
        roamingProductName: 'Roaming Data Daily Bundle (500 MB)',
        roamingProductKind: 'day_pass',
        roamingScope: 'worldwide',
        roamingUnits: 3,
        roamingTotalUsd: 28.59,
      ));

      expect(q.roamingDetailLine,
          '3 × Roaming Data Daily Bundle (500 MB)');
    });

    test('pay-as-you-go is described by the data, not by a pack count', () {
      final RoamQuote q = RoamQuote.fromJson(row(
        roamingProductKind: 'payg',
        roamingProductName: 'Standard data roaming',
        roamingUnits: 3000,
        tripDataMb: 3000,
      ));

      expect(q.roamingDetailLine,
          'Standard data roaming · 3 GB at pay-as-you-go');
    });

    test('the eSIM line shows the quantity the quote actually priced', () {
      expect(RoamQuote.fromJson(row()).esimDetailLine, '1 GB / 7 days');
      expect(
        RoamQuote.fromJson(row(esimQuantity: 3)).esimDetailLine,
        '3 × 1 GB / 7 days',
      );
    });

    test('a one-day bundle is singular', () {
      expect(
        RoamQuote.fromJson(row(esimDurationDays: 1)).esimDetailLine,
        '1 GB / 1 day',
      );
    });
  });

  group('RoamCarrierOption', () {
    test('maps my_roaming_carriers rows, home carrier flagged', () {
      final RoamCarrierOption o = RoamCarrierOption.fromJson(<String, dynamic>{
        'carrier_id': 'c-1',
        'carrier_name': 'Orange Egypt',
        'home_iso': 'EG',
        'home_country': 'Egypt',
        'is_home': true,
        'has_rate': true,
        'product_count': 1,
      });

      expect(o.carrierName, 'Orange Egypt');
      expect(o.isHome, isTrue);
      expect(o.hasRate, isTrue);
      expect(o.productCount, 1);
    });

    test('a carrier with no tariff is still a row, so the UI can say so', () {
      final RoamCarrierOption o = RoamCarrierOption.fromJson(<String, dynamic>{
        'carrier_id': 'c-2',
        'carrier_name': 'Omantel',
        'home_iso': 'OM',
        'home_country': 'Oman',
        'is_home': false,
        'has_rate': false,
        'product_count': 0,
      });

      expect(o.hasRate, isFalse);
      expect(o.productCount, 0);
    });
  });
}
