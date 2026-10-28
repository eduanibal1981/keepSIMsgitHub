import 'package:keep_sims/features/esim/domain/entities/affiliate_click_result.dart';
import 'package:keep_sims/features/esim/domain/entities/compare_offer.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_order.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_recharge.dart';

abstract class EsimRepository {
  Future<EsimRechargeDiscovery> discoverTopups(String profileId);
  Future<EsimRechargeQuote> quoteTopup(
    String profileId,
    String packageId,
    String offerVersion,
    double expectedTotal,
  );

  /// Fetches a list of available eSIM plans for a given country ISO code.
  Future<List<EsimPlan>> getPlans(String countryIsoCode);

  /// The comparison list: our own resale bundles and every active partner deal
  /// in one server-ranked result.
  ///
  /// Filtering, sorting and paging all happen in SQL. This is not a style
  /// preference — the catalogue is 5,412 bundles across 220 countries, and the
  /// older `getPlans()` habit of pulling the whole table down to filter it in
  /// Dart was only viable while the supplier fetch was accidentally truncated
  /// to 50 rows.
  Future<List<CompareOffer>> compareOffers(
    String countryIsoCode, {
    CompareFilters filters,
    int limit,
    int offset,
  });

  /// The durations, data sizes and price range this destination actually
  /// sells, so the filter sheet can offer choices that return something.
  ///
  /// A hard-coded ladder cannot do this: France sells metered data at four
  /// durations while the global catalogue spans ten, so a fixed "60 days" chip
  /// is an empty result waiting to happen.
  Future<CompareBounds> compareFilterBounds(String countryIsoCode);

  /// Logs an outbound partner click and returns the tracked URL to open.
  ///
  /// The URL is built server-side so attribution cannot be forged from a
  /// device, and the token it carries is an opaque click id — the user's
  /// identity is never handed to the partner network.
  Future<AffiliateClickResult> recordAffiliateClick(
    String offerId, {
    String? countryCode,
  });

  /// Validates a plan purchase without charging the account (Sandbox testing)
  Future<bool> validatePlanPurchase(String planId, {int quantity = 1});

  /// Requests a real eSIM purchase from user wallet via RPC
  Future<String> requestPurchase(String offerId, {int quantity = 1});

  /// Fetches all active & archived eSIMs owned by the user
  Future<List<UserEsim>> getUserEsims({bool requestRefresh = false});

  /// Fetches user's eSIM order history
  Future<List<EsimOrder>> getOrderHistory();

  /// Streams realtime status updates for a specific order
  Stream<EsimOrder?> watchOrder(String orderId);
}
