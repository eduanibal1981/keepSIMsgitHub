import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/esim/domain/entities/affiliate_click_result.dart';
import 'package:keep_sims/features/esim/domain/entities/compare_offer.dart';

void main() {
  group('CompareOffer — unlimited plans', () {
    // 3,894 of the 5,412 live bundles are unlimited. The server sends a NULL
    // price_per_gb for every one of them so they cannot be ranked as free;
    // this asserts the client preserves that rather than coercing to 0.
    test('an unlimited plan carries a null price-per-GB, never zero', () {
      final offer = CompareOffer.fromRpc({
        'offer_kind': 'resale',
        'offer_id': 'esim_UL_1D_EG_V2',
        'is_unlimited': true,
        'data_amount_mb': 0,
        'price_usd': 4.24,
        'price_per_gb_usd': null,
      });

      expect(offer.pricePerGbUsd, isNull);
      expect(offer.pricePerGbUsd, isNot(0.0));
      expect(offer.formattedData, 'Unlimited');
    });

    test('a metered plan keeps its real price-per-GB', () {
      final offer = CompareOffer.fromRpc({
        'offer_id': 'esim_10GB_30D_EG_V2',
        'data_amount_mb': 10000,
        'is_unlimited': false,
        'price_usd': 19.76,
        'price_per_gb_usd': 2.02,
      });

      expect(offer.pricePerGbUsd, 2.02);
      // The supplier stores this bundle as 10000 MB and names it 10GB. A 1024
      // divisor printed "9.8 GB" on it, which then disagreed with every filter
      // chip offering "10 GB".
      expect(offer.formattedData, '10 GB');
    });

    test('sizes are formatted the way the catalogue stores them', () {
      expect(CompareOffer.formatDataMb(1000), '1 GB');
      expect(CompareOffer.formatDataMb(3000), '3 GB');
      expect(CompareOffer.formatDataMb(100000), '100 GB');
      expect(CompareOffer.formatDataMb(500), '500 MB');
      expect(CompareOffer.formatDataMb(1500), '1.5 GB');
    });
  });

  group('CompareOffer — which rail', () {
    test('open_partner is an affiliate offer that must be disclosed', () {
      final offer = CompareOffer.fromRpc({
        'offer_id': 'abc',
        'action': 'open_partner',
        'disclosure_required': true,
        'price_usd': 8.10,
      });

      expect(offer.isAffiliate, isTrue);
      expect(offer.action, OfferAction.openPartner);
      expect(offer.disclosureRequired, isTrue);
    });

    // An unknown or missing action must not become a partner hand-off. The
    // safe default is our own rail, where nothing leaves the app.
    test('an unrecognised action falls back to buy-in-app', () {
      expect(CompareOffer.fromRpc({'action': 'something_new'}).isAffiliate,
          isFalse);
      expect(CompareOffer.fromRpc({}).action, OfferAction.buyInApp);
    });
  });

  group('CompareOffer — stale partner prices', () {
    test('a stale price may not be quoted', () {
      final stale = CompareOffer.fromRpc({
        'offer_id': 'x',
        'action': 'open_partner',
        'price_usd': 7.50,
        'price_is_stale': true,
      });

      expect(stale.priceIsStale, isTrue);
      expect(stale.canQuotePrice, isFalse);
    });

    test('a freshly checked price may be quoted', () {
      final fresh = CompareOffer.fromRpc({
        'offer_id': 'y',
        'action': 'open_partner',
        'price_usd': 8.10,
        'price_is_stale': false,
      });

      expect(fresh.canQuotePrice, isTrue);
    });
  });

  group('CompareFilters', () {
    test('copyWith can clear a filter, not just replace it', () {
      const f = CompareFilters(
        validityMode: RangeFilterMode.range,
        minDays: 30,
        coverage: 'local',
      );
      expect(f.copyWith(minDays: null).minDays, isNull);
      // Unspecified fields survive — the sentinel is what makes both possible.
      expect(f.copyWith(minDays: null).coverage, 'local');
    });

    test('reset clears filters but deliberately keeps the sort', () {
      const f = CompareFilters(
        validityMode: RangeFilterMode.range,
        minDays: 30,
        dataMode: DataFilterMode.unlimited,
        sort: CompareSort.pricePerGb,
      );
      final cleared = CompareFilters(sort: f.sort);

      expect(cleared.activeCount, 0);
      expect(cleared.sort, CompareSort.pricePerGb);
    });

    test('activeCount counts only the filters actually set', () {
      expect(const CompareFilters().activeCount, 0);
      expect(
        const CompareFilters(
                validityMode: RangeFilterMode.range, minDays: 7)
            .activeCount,
        1,
      );
      expect(
        const CompareFilters(
          validityMode: RangeFilterMode.range,
          minDays: 7,
          dataMode: DataFilterMode.unlimited,
          coverage: 'local',
        ).activeCount,
        3,
      );
      // An empty tier list is not an active filter.
      expect(const CompareFilters(speedTiers: []).activeCount, 0);
    });

    // A mode that is selected but not yet filled in narrows nothing. If it
    // counted, the Filters pill would claim a filter that excludes no plan and
    // the "Reset" button would light up with nothing to reset.
    test('a chosen mode with no values set is not an active filter', () {
      expect(
        const CompareFilters(validityMode: RangeFilterMode.range).activeCount,
        0,
      );
      expect(
        const CompareFilters(validityMode: RangeFilterMode.exact).activeCount,
        0,
      );
      expect(const CompareFilters(dataMode: DataFilterMode.range).activeCount, 0);
      expect(const CompareFilters(priceRangeOn: true).activeCount, 0);
      // Unlimited is the exception: choosing it IS the whole filter, there is
      // nothing further to fill in.
      expect(
        const CompareFilters(dataMode: DataFilterMode.unlimited).activeCount,
        1,
      );
    });
  });

  // The `wire*` getters are the only thing the repository sends. They exist so
  // "an exact list only counts in exact mode" is decided once; a value left
  // behind by a mode switch must never reach the query.
  group('CompareFilters — what reaches the server', () {
    test('range bounds are sent only in range mode', () {
      const range = CompareFilters(
        validityMode: RangeFilterMode.range,
        minDays: 1,
        maxDays: 7,
      );
      expect(range.wireMinDays, 1);
      expect(range.wireMaxDays, 7);
      expect(range.wireDaysExact, isNull);

      // Same values, different mode: nothing about them is a question any more.
      expect(range.copyWith(validityMode: RangeFilterMode.all).wireMinDays,
          isNull);
      expect(range.copyWith(validityMode: RangeFilterMode.exact).wireMaxDays,
          isNull);
    });

    test('an exact list is sent only in exact mode, and never empty', () {
      const picked = CompareFilters(
        validityMode: RangeFilterMode.exact,
        daysExact: [3, 7, 9],
      );
      expect(picked.wireDaysExact, [3, 7, 9]);
      expect(picked.wireMinDays, isNull);

      // An empty list means "exact mode, nothing ticked". Sent as NULL, which
      // the server reads as no filter — not as a set that matches nothing.
      expect(
        const CompareFilters(validityMode: RangeFilterMode.exact)
            .wireDaysExact,
        isNull,
      );
    });

    test('unlimited is a data mode, not a flag that rides along', () {
      const unlimited = CompareFilters(dataMode: DataFilterMode.unlimited);
      expect(unlimited.wireUnlimitedOnly, isTrue);
      expect(unlimited.wireMinDataMb, isNull);
      expect(unlimited.wireDataExactMb, isNull);

      // Every other data mode leaves it off, so the old "unlimited only is on,
      // so your data filter is ignored" conflict can no longer be expressed.
      const sized = CompareFilters(
        dataMode: DataFilterMode.range,
        minDataMb: 3000,
        maxDataMb: 20000,
      );
      expect(sized.wireUnlimitedOnly, isFalse);
      expect(sized.wireMinDataMb, 3000);
      expect(sized.wireMaxDataMb, 20000);
    });

    test('an empty price box is null, never zero', () {
      // On the maximum side those are opposite instructions: NULL is "no
      // ceiling", 0 would be "free plans only".
      const onlyMin = CompareFilters(priceRangeOn: true, minPriceUsd: 5);
      expect(onlyMin.wireMinPriceUsd, 5);
      expect(onlyMin.wireMaxPriceUsd, isNull);

      const onlyMax = CompareFilters(priceRangeOn: true, maxPriceUsd: 25);
      expect(onlyMax.wireMinPriceUsd, isNull);
      expect(onlyMax.wireMaxPriceUsd, 25);

      // Switched back to All, a price typed earlier stops being asked.
      expect(onlyMax.copyWith(priceRangeOn: false).wireMaxPriceUsd, isNull);
    });
  });

  group('AffiliateClickResult', () {
    // The envelope discipline from PlanFeeResult: the RPC refuses at HTTP 200,
    // so "did not throw" is not "go ahead".
    test('an unreadable body is a refusal', () {
      expect(AffiliateClickResult.fromRpc(null).success, isFalse);
      expect(AffiliateClickResult.fromRpc('ok').success, isFalse);
      expect(AffiliateClickResult.fromRpc(42).success, isFalse);
    });

    test('the string "true" is not a success', () {
      expect(
        AffiliateClickResult.fromRpc({'success': 'true', 'url': 'https://x'})
            .success,
        isFalse,
      );
    });

    // The whole point of the rail: an untracked link earns nothing, so a
    // success without a URL must not open anything.
    test('success without a url is not a success', () {
      expect(AffiliateClickResult.fromRpc({'success': true}).success, isFalse);
      expect(
        AffiliateClickResult.fromRpc({'success': true, 'url': ''}).success,
        isFalse,
      );
    });

    test('a real success carries the tracked url and click id', () {
      final r = AffiliateClickResult.fromRpc({
        'success': true,
        'url': 'https://weitaigetechnologycolimited.pxf.io/c/1/2/3?subId1=abc',
        'click_id': 'abc',
      });

      expect(r.success, isTrue);
      expect(r.url, contains('subId1=abc'));
      expect(r.clickId, 'abc');
    });

    test('a refusal code is preserved for the caller', () {
      final r = AffiliateClickResult.fromRpc(
          {'success': false, 'code': AffiliateClickErrorCode.noTrackingUrl});
      expect(r.success, isFalse);
      expect(r.code, 'NO_TRACKING_URL');
      expect(r.url, isNull);
    });
  });
}
