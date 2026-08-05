import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_provider_factory.dart';
import 'package:keep_sims/features/esim/domain/entities/affiliate_click_result.dart';
import 'package:keep_sims/features/esim/domain/entities/compare_offer.dart';

part 'esim_compare_controller.g.dart';

/// The filter set currently applied on the compare screen.
///
/// Held separately from the results so changing a filter re-runs the *query*
/// rather than rebuilding a list in memory. With 5,412 bundles the filtering
/// has to happen in SQL, so the filters are an input to the fetch, not a
/// post-processing step.
@riverpod
class EsimCompareFilters extends _$EsimCompareFilters {
  @override
  CompareFilters build() => const CompareFilters();

  void setSort(CompareSort sort) => state = state.copyWith(sort: sort);

  void setCoverage(String? coverage) =>
      state = state.copyWith(coverage: coverage);

  void setMinData(int? mb) => state = state.copyWith(minDataMb: mb);

  void setMinDays(int? days) => state = state.copyWith(minDays: days);

  void setMaxPrice(double? usd) => state = state.copyWith(maxPriceUsd: usd);

  void setUnlimitedOnly(bool value) =>
      state = state.copyWith(unlimitedOnly: value);

  void setSpeedTiers(List<String>? tiers) => state = state.copyWith(
      speedTiers: (tiers == null || tiers.isEmpty) ? null : tiers);

  /// Clears every filter but deliberately keeps the sort. Someone who chose
  /// "cheapest per GB" and then taps Reset wants their filters gone, not their
  /// ranking silently swapped back to price.
  void reset() => state = CompareFilters(sort: state.sort);
}

/// The comparison results for one destination.
@riverpod
class EsimCompare extends _$EsimCompare {
  @override
  FutureOr<List<CompareOffer>> build(String countryIsoCode) async {
    // Watching the filters makes this re-fetch whenever they change, which is
    // what keeps the query server-side.
    final filters = ref.watch(esimCompareFiltersProvider);
    final repo = ref.read(esimRepositoryProvider);
    return repo.compareOffers(countryIsoCode, filters: filters, limit: 100);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final filters = ref.read(esimCompareFiltersProvider);
      final repo = ref.read(esimRepositoryProvider);
      return repo.compareOffers(countryIsoCode, filters: filters, limit: 100);
    });
  }
}

/// Records an outbound partner click and hands back the tracked URL.
///
/// Returns the envelope rather than a bare String so the caller has to deal
/// with refusal. There is no fallback to an untracked partner link: sending
/// someone to a partner without attribution earns nothing and is worse than
/// not showing the offer.
@riverpod
Future<AffiliateClickResult> affiliateClick(
  Ref ref,
  String offerId,
  String countryCode,
) async {
  final repo = ref.read(esimRepositoryProvider);
  return repo.recordAffiliateClick(offerId, countryCode: countryCode);
}
