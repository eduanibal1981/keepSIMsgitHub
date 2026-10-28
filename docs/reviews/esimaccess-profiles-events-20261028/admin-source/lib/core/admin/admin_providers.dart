/// Riverpod wiring for the admin control plane.
///
/// Deliberately hand-written rather than generated: nothing here needs codegen,
/// and a `.g.dart` that has to be regenerated before the app will compile is a
/// poor trade for eight `FutureProvider`s.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_api.dart';

final adminApiProvider = Provider<AdminApi>(
  (ref) => AdminApi(Supabase.instance.client),
);

/// Whether the signed-in session is actually a power user.
///
/// Read from the JWT's `app_metadata`, not from `profiles`, because that is what
/// the server checks: `is_power_user()` is `auth.jwt() -> app_metadata ->>
/// 'is_power_user'`. A profile row saying true while the token says false means
/// every RPC on this screen answers KS460, and the honest thing is to say so at
/// the door rather than let each panel fail on its own.
final isPowerUserProvider = Provider<bool>((ref) {
  final meta = Supabase.instance.client.auth.currentUser?.appMetadata;
  return meta?['is_power_user'] == true;
});

final overviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(adminApiProvider).overview(),
);

final scheduledJobsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(adminApiProvider).scheduledJobs(),
    );

final configsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminApiProvider).configs(),
);

final appFeeRulesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(adminApiProvider).appFeeRules(),
    );

final carriersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminApiProvider).carriers(),
);

final offersSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(adminApiProvider).offersSummary(),
);

final carrierProviderMapProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(
      (ref, carrierId) =>
          ref.watch(adminApiProvider).carrierProviderMap(carrierId: carrierId),
    );

final providerOffersForCarrierProvider = FutureProvider.autoDispose
    .family<
      List<Map<String, dynamic>>,
      ({
        String carrierId,
        String provider,
        String carrierCode,
        String? countryCode,
        String? providerCountryCode,
      })
    >(
      (ref, arg) => ref
          .watch(adminApiProvider)
          .providerOffersForCarrier(
            carrierId: arg.carrierId,
            provider: arg.provider,
            carrierCode: arg.carrierCode,
            countryCode: arg.countryCode,
            providerCountryCode: arg.providerCountryCode,
          ),
    );

final serviceProvidersListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(adminApiProvider).serviceProviders(),
    );

final channelsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminApiProvider).channels(),
);

final notificationHealthProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(adminApiProvider).notificationHealth(),
    );

final notificationDispatchHealthProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
      (ref) => ref.watch(adminApiProvider).notificationDispatchHealth(),
    );

final notificationDispatchIncidentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(adminApiProvider).notificationDispatchIncidents(),
    );

final alertClockOverviewProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
      (ref) => ref.watch(adminApiProvider).alertClockOverview(),
    );

final alertClockSchedulerStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
      (ref) => ref.watch(adminApiProvider).alertClockSchedulerStatus(),
    );

final alertClocksListProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String?>(
      (ref, state) => ref.watch(adminApiProvider).listAlertClocks(state: state),
    );

final esimRuntimeStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
      (ref) => ref.watch(adminApiProvider).esimRuntimeStatus(),
    );

final esimCatalogueDiagnosticsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
      (ref) => ref.watch(adminApiProvider).esimCatalogueDiagnostics(),
    );

final esimSuppliersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(adminApiProvider).esimSuppliers(),
    );

final offlineEndpointsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(adminApiProvider).offlineEndpoints(),
    );

// ------------------------------------------------------------------------ mail

final emailsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminApiProvider).emails(limit: 50),
);

// -------------------------------------------------------------------- vouchers

final voucherOverviewProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(adminApiProvider).voucherOverview(),
    );

/// Open fulfilment requests: entitled subscribers with no PIN, and the deadline.
/// This is the queue an operator works from, so it is the one that loads first.
final voucherRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(adminApiProvider).voucherRequests(),
    );

/// Stock for one carrier, or every carrier when the id is null.
final voucherStockProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>(
      (ref, carrierId) =>
          ref.watch(adminApiProvider).voucherStock(carrierId: carrierId),
    );

/// Outstanding debt first — `admin_list_voucher_grants` orders revealed rows
/// to the top, so the default (null) filter is already the useful view.
final voucherGrantsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>(
      (ref, status) =>
          ref.watch(adminApiProvider).voucherGrants(status: status),
    );

final voucherRedemptionProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(adminApiProvider).voucherRedemptionCodes(),
    );

final voucherPurchaseJobsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(adminApiProvider).voucherPurchaseJobs(),
    );

// ------------------------------------------------------------------ affiliates

final affiliatePartnersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(adminApiProvider).affiliatePartners(),
    );

/// Offers for one partner, or every partner when the code is null.
final affiliateOffersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>(
      (ref, partnerCode) =>
          ref.watch(adminApiProvider).affiliateOffers(partnerCode: partnerCode),
    );

final affiliateOverviewProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
      (ref) => ref.watch(adminApiProvider).affiliateOverview(days: 30),
    );

/// Riverpod 3 removed `StateProvider`, so the two filter holders in this file
/// are one-line `Notifier`s instead.
class _NullableStringFilter extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

final ticketStatusFilterProvider =
    NotifierProvider<_NullableStringFilter, String?>(_NullableStringFilter.new);

final ticketsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref
      .watch(adminApiProvider)
      .tickets(status: ref.watch(ticketStatusFilterProvider)),
);

final ticketDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, id) => ref.watch(adminApiProvider).ticket(id),
    );

class _SearchFilter extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

final userSearchProvider = NotifierProvider<_SearchFilter, String>(
  _SearchFilter.new,
);

final adminUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final q = ref.watch(userSearchProvider).trim();
      return ref.watch(adminApiProvider).users(search: q.isEmpty ? null : q);
    });

final auditProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminApiProvider).audit(limit: 200),
);

class TelnyxDateRangeFilter extends Notifier<DateTimeRange> {
  @override
  DateTimeRange build() {
    final now = DateTime.now();
    return DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
  }

  void set(DateTimeRange range) => state = range;
}

final telnyxDateRangeProvider =
    NotifierProvider<TelnyxDateRangeFilter, DateTimeRange>(
      TelnyxDateRangeFilter.new,
    );

class TelnyxServiceFilter extends Notifier<String> {
  @override
  String build() => 'all';
  void set(String v) => state = v;
}

final telnyxServiceFilterProvider =
    NotifierProvider<TelnyxServiceFilter, String>(TelnyxServiceFilter.new);

final telnyxBillingProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) {
  final range = ref.watch(telnyxDateRangeProvider);
  final filter = ref.watch(telnyxServiceFilterProvider);
  return ref
      .watch(adminApiProvider)
      .fetchTelnyxBilling(
        startDate: range.start,
        endDate: range.end,
        serviceType: filter,
      );
});
