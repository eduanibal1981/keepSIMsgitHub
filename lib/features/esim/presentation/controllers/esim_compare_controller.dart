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

  // ── Validity ─────────────────────────────────────────────────────────────
  // Switching mode clears the other mode's values. Leaving them behind would
  // make Reset look like it half-worked when the user switched back, and the
  // `wire*` getters would then be hiding state the sheet still displays.
  void setValidityMode(RangeFilterMode mode) => state = state.copyWith(
        validityMode: mode,
        minDays: null,
        maxDays: null,
        daysExact: const [],
      );

  void setDaysRange(int? min, int? max) =>
      state = state.copyWith(minDays: min, maxDays: max);

  void toggleDayExact(int days) {
    final next = [...state.daysExact];
    if (!next.remove(days)) next.add(days);
    next.sort();
    state = state.copyWith(daysExact: next);
  }

  // ── Data ─────────────────────────────────────────────────────────────────
  void setDataMode(DataFilterMode mode) => state = state.copyWith(
        dataMode: mode,
        minDataMb: null,
        maxDataMb: null,
        dataExactMb: const [],
        speedTiers: mode == DataFilterMode.unlimited ? state.speedTiers : null,
      );

  void setDataRange(int? minMb, int? maxMb) => state = state.copyWith(
        minDataMb:
            minMb != null ? CompareOffer.canonicalizeDataMb(minMb) : null,
        maxDataMb:
            maxMb != null ? CompareOffer.canonicalizeDataMb(maxMb) : null,
      );

  void toggleDataExact(int mb) {
    final canonical = CompareOffer.canonicalizeDataMb(mb);
    final next = [...state.dataExactMb];
    if (!next.remove(canonical)) next.add(canonical);
    next.sort();
    state = state.copyWith(dataExactMb: next);
  }

  // ── Price ────────────────────────────────────────────────────────────────
  void setPriceRangeOn(bool on) => state = state.copyWith(
        priceRangeOn: on,
        minPriceUsd: null,
        maxPriceUsd: null,
      );

  /// An empty box is `null`, never 0. On the maximum side those mean opposite
  /// things — no ceiling versus "free only" — so the caller must not coerce.
  void setPriceRange({double? min, double? max}) =>
      state = state.copyWith(minPriceUsd: min, maxPriceUsd: max);

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

/// The durations, data sizes and price floor/ceiling this destination sells.
///
/// Deliberately keyed by country and NOT watched by [EsimCompare]: the filter
/// sheet needs it to draw its choices, but the result list must not re-fetch
/// when it arrives. Keeping them separate is also why a slow bounds call can
/// never delay the offers.
@riverpod
Future<CompareBounds> esimCompareBounds(Ref ref, String countryIsoCode) async {
  final repo = ref.read(esimRepositoryProvider);
  return repo.compareFilterBounds(countryIsoCode);
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
