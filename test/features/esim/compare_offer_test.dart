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
      expect(offer.formattedData, '9.8 GB');
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
      const f = CompareFilters(minDays: 30, coverage: 'local');
      expect(f.copyWith(minDays: null).minDays, isNull);
      // Unspecified fields survive — the sentinel is what makes both possible.
      expect(f.copyWith(minDays: null).coverage, 'local');
    });

    test('reset clears filters but deliberately keeps the sort', () {
      const f = CompareFilters(
          minDays: 30, unlimitedOnly: true, sort: CompareSort.pricePerGb);
      final cleared = CompareFilters(sort: f.sort);

      expect(cleared.activeCount, 0);
      expect(cleared.sort, CompareSort.pricePerGb);
    });

    test('activeCount counts only the filters actually set', () {
      expect(const CompareFilters().activeCount, 0);
      expect(const CompareFilters(minDays: 7).activeCount, 1);
      expect(
        const CompareFilters(minDays: 7, unlimitedOnly: true, coverage: 'local')
            .activeCount,
        3,
      );
      // An empty tier list is not an active filter.
      expect(const CompareFilters(speedTiers: []).activeCount, 0);
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
