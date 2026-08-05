/// Destination-first eSIM comparison.
///
/// One ranked list containing both rails: bundles we resell (wallet debit,
/// instant QR) and partner deals (tracked hand-off, we may earn a commission).
/// They compete on price and $/GB with no thumb on the scale, and each card
/// says plainly which it is. A comparison that always concludes "buy ours" is
/// an advert, and users work that out quickly.
///
/// Filtering, sorting and paging happen in SQL via `compare_esim_offers()`.
/// The catalogue behind this screen is 5,412 bundles across 220 countries; the
/// old habit of pulling the table down and filtering in Dart was only ever
/// viable while the supplier fetch was accidentally truncated to 50 rows.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/core/services/esim_capability_service.dart';
import 'package:keep_sims/features/esim/domain/entities/compare_offer.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_compare_controller.dart';
import 'package:keep_sims/features/esim/presentation/widgets/compare_filter_sheet.dart';
import 'package:keep_sims/features/esim/presentation/widgets/compare_offer_card.dart';
import 'package:keep_sims/features/esim/presentation/widgets/esim_checkout_sheet.dart';
import 'package:keep_sims/features/price_watch/presentation/providers/price_watch_provider.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EsimPlansScreen extends ConsumerStatefulWidget {
  const EsimPlansScreen({super.key});

  @override
  ConsumerState<EsimPlansScreen> createState() => _EsimPlansScreenState();
}

class _EsimPlansScreenState extends ConsumerState<EsimPlansScreen> {
  String _countryCode = 'FR';
  String _countryName = 'France';

  /// Quick-access destinations. The live catalogue reaches 220 countries, so
  /// this list is a shortcut, not the limit — search matches any ISO code the
  /// user types.
  static const Map<String, String> _destinations = {
    'FR': 'France', 'US': 'United States', 'GB': 'United Kingdom',
    'DE': 'Germany', 'ES': 'Spain', 'IT': 'Italy', 'PT': 'Portugal',
    'GR': 'Greece', 'NL': 'Netherlands', 'CH': 'Switzerland',
    'AT': 'Austria', 'BE': 'Belgium', 'IE': 'Ireland', 'PL': 'Poland',
    'AE': 'United Arab Emirates', 'SA': 'Saudi Arabia', 'QA': 'Qatar',
    'KW': 'Kuwait', 'BH': 'Bahrain', 'OM': 'Oman', 'JO': 'Jordan',
    'EG': 'Egypt', 'MA': 'Morocco', 'TR': 'Turkey', 'IL': 'Israel',
    'IN': 'India', 'PK': 'Pakistan', 'BD': 'Bangladesh', 'LK': 'Sri Lanka',
    'NP': 'Nepal', 'PH': 'Philippines', 'ID': 'Indonesia', 'MY': 'Malaysia',
    'SG': 'Singapore', 'TH': 'Thailand', 'VN': 'Vietnam', 'JP': 'Japan',
    'KR': 'South Korea', 'CN': 'China', 'HK': 'Hong Kong',
    'AU': 'Australia', 'NZ': 'New Zealand', 'CA': 'Canada', 'MX': 'Mexico',
    'BR': 'Brazil', 'AR': 'Argentina', 'ZA': 'South Africa',
    'KE': 'Kenya', 'NG': 'Nigeria', 'RU': 'Russia',
  };

  @override
  void initState() {
    super.initState();
    _initPreselectedCountry();
  }

  Future<void> _initPreselectedCountry() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('last_country, home_country_code')
          .eq('id', userId)
          .maybeSingle();
      if (profile == null) return;

      final last = profile['last_country'] as String?;
      final home = profile['home_country_code'] as String?;
      final target = (last?.isNotEmpty == true) ? last : home;
      if (target == null || target.length != 2 || !mounted) return;

      final code = target.toUpperCase();
      setState(() {
        _countryCode = code;
        _countryName = _destinations[code] ?? code;
      });
    } catch (_) {
      // A missing profile is not worth an error state; the default
      // destination is still a usable screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final capability = ref.watch(esimCapabilityServiceProvider);
    final offersState = ref.watch(esimCompareProvider(_countryCode));
    final filters = ref.watch(esimCompareFiltersProvider);
    final deviceSupportsEsim = capability.value ?? false;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.esimPlansTitle,
          style: AppTextStyles.headlineMedium.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_rounded, color: context.onSurfaceColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: l10n.roamOrEsimTooltip,
            icon: Icon(Icons.calculate_outlined, color: context.onSurfaceColor),
            onPressed: () => context.push(
              '${AppRoutes.esimRoamCalculator}?country=$_countryCode',
            ),
          ),
          _priceWatchAction(context),
        ],
      ),
      body: Column(
        children: [
          _destinationHeader(context),
          _resultsBar(context, l10n, offersState.value?.length, filters),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(esimCompareProvider(_countryCode).notifier).refresh(),
              child: offersState.when(
                data: (offers) =>
                    _resultsList(context, l10n, offers, deviceSupportsEsim),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, _) => _errorState(context, l10n, err),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Results ─────────────────────────────────────────────────────────────
  Widget _resultsList(BuildContext context, AppLocalizations l10n,
      List<CompareOffer> offers, bool deviceSupportsEsim) {
    if (offers.isEmpty) return _emptyState(context, l10n);

    // "Best value" is the lowest real $/GB. Unlimited plans carry a NULL
    // price_per_gb precisely so they cannot win a per-GB award they have no
    // denominator for.
    String? bestValueId;
    double best = double.infinity;
    for (final o in offers) {
      final ppg = o.pricePerGbUsd;
      if (ppg != null && ppg > 0 && ppg < best) {
        best = ppg;
        bestValueId = o.offerId;
      }
    }

    final hasPartner = offers.any((o) => o.isAffiliate);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: offers.length + (hasPartner ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        // The disclosure sits at the top of the list, above the first result,
        // so it is read before any partner card rather than buried at the end.
        if (hasPartner && index == 0) return _disclosure(context, l10n);
        final offer = offers[index - (hasPartner ? 1 : 0)];
        return CompareOfferCard(
          offer: offer,
          isBestValue: offer.offerId == bestValueId,
          onPressed: () => _onOfferTapped(offer, deviceSupportsEsim),
        );
      },
    );
  }

  Future<void> _onOfferTapped(
      CompareOffer offer, bool deviceSupportsEsim) async {
    final l10n = AppLocalizations.of(context)!;
    await HapticHelper.mediumImpact();

    if (offer.isAffiliate) {
      await _openPartnerDeal(offer, l10n);
      return;
    }

    if (!deviceSupportsEsim) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deviceIncompatibleNotice)),
      );
      return;
    }

    // The checkout sheet still speaks EsimPlan. Only resale offers reach here,
    // and their offerId is the `bundle_name` that `request_esim_purchase`
    // resolves against, so this maps without inventing anything.
    if (!mounted) return;
    EsimCheckoutSheet.show(
      context,
      EsimPlan(
        id: offer.offerId,
        name: offer.title,
        dataAmountMB: offer.isUnlimited ? 0 : offer.dataAmountMb,
        durationDays: offer.durationDays,
        priceUsd: offer.priceUsd,
        providerName: offer.sourceName,
        supportedCountries: offer.countries,
        description: offer.description,
        imageUrl: offer.imageUrl,
      ),
    );
  }

  Future<void> _openPartnerDeal(
      CompareOffer offer, AppLocalizations l10n) async {
    final result = await ref.read(
      affiliateClickProvider(offer.offerId, _countryCode).future,
    );

    if (!mounted) return;

    // No fallback to an untracked link. Sending someone to a partner without
    // attribution earns nothing, which is strictly worse than not opening.
    if (!result.success || result.url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.compareOpenFailed)),
      );
      return;
    }

    final uri = Uri.tryParse(result.url!);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.compareOpenFailed)),
      );
    }
  }

  // ── Chrome ──────────────────────────────────────────────────────────────
  Widget _disclosure(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 17, color: Color(0xFF8B5CF6)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.compareAffiliateDisclosure,
              style: AppTextStyles.caption.copyWith(
                color: context.onSurfaceColor.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsBar(BuildContext context, AppLocalizations l10n, int? count,
      CompareFilters filters) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == null ? '' : l10n.comparePlansFound(count),
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.onSurfaceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _sortButton(context, l10n, filters),
          const SizedBox(width: 8),
          _filterButton(context, l10n, filters),
        ],
      ),
    );
  }

  Widget _sortButton(
      BuildContext context, AppLocalizations l10n, CompareFilters filters) {
    String label(CompareSort s) => switch (s) {
          CompareSort.price => l10n.sortPriceLowToHigh,
          CompareSort.pricePerGb => l10n.sortPricePerGb,
          CompareSort.data => l10n.sortDataHighToLow,
          CompareSort.duration => l10n.compareSortDuration,
        };

    return PopupMenuButton<CompareSort>(
      initialValue: filters.sort,
      onSelected: (s) =>
          ref.read(esimCompareFiltersProvider.notifier).setSort(s),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => CompareSort.values
          .map((s) => PopupMenuItem(value: s, child: Text(label(s))))
          .toList(),
      child: _pill(
        context,
        icon: Icons.swap_vert_rounded,
        label: label(filters.sort),
      ),
    );
  }

  Widget _filterButton(
      BuildContext context, AppLocalizations l10n, CompareFilters filters) {
    final active = filters.activeCount;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => CompareFilterSheet.show(context),
      child: _pill(
        context,
        icon: Icons.tune_rounded,
        label: active == 0
            ? l10n.compareFiltersTitle
            : '${l10n.compareFiltersTitle} ($active)',
        highlighted: active > 0,
      ),
    );
  }

  Widget _pill(BuildContext context,
      {required IconData icon, required String label, bool highlighted = false}) {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.12)
            : (isDark ? AppColors.darkCard : AppColors.lightCard),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? AppColors.primary
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 15,
              color: highlighted ? AppColors.primary : context.onSurfaceColor),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color:
                    highlighted ? AppColors.primary : context.onSurfaceColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _destinationHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    return InkWell(
      onTap: () => _showDestinationPicker(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF232530), const Color(0xFF181A24)]
                : [const Color(0xFFF0F4FF), const Color(0xFFE5ECFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(CompareOfferCard.countryFlag(_countryCode),
                style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.compareDestinationLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: context.onSurfaceColor.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    '$_countryName ($_countryCode)',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _priceWatchAction(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final watchAsync = ref.watch(esimWatchForCountryProvider(_countryCode));
    final watch = watchAsync.value;
    final isWatching = watch != null && watch.isActive;

    return GestureDetector(
      onLongPress: () => context.push(AppRoutes.esimPriceWatch),
      child: IconButton(
        tooltip: l10n.comparePriceWatchTooltip,
        icon: Icon(
          isWatching
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          color: isWatching ? AppColors.primary : context.onSurfaceColor,
        ),
        onPressed: watchAsync.isLoading
            ? null
            : () async {
                await HapticHelper.lightTick();
                final controller =
                    ref.read(priceWatchControllerProvider.notifier);
                if (watch == null) {
                  await controller.watchEsimCountry(_countryCode);
                } else {
                  await controller.setActive(watch.id, !watch.isActive);
                }
                if (!context.mounted) return;
                final nowWatching = watch == null || !watch.isActive;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 4),
                    content: Text(nowWatching
                        ? l10n.comparePriceWatchOn(_countryName)
                        : l10n.comparePriceWatchOff(_countryName)),
                    action: SnackBarAction(
                      label: l10n.compareViewAll,
                      onPressed: () => context.push(AppRoutes.esimPriceWatch),
                    ),
                  ),
                );
              },
      ),
    );
  }

  Widget _emptyState(BuildContext context, AppLocalizations l10n) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
          child: Column(
            children: [
              const Icon(Icons.search_off_rounded, size: 54, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                l10n.compareNoResults,
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineSmall
                    .copyWith(color: context.onSurfaceColor),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () =>
                    ref.read(esimCompareFiltersProvider.notifier).reset(),
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: Text(l10n.compareReset),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorState(
      BuildContext context, AppLocalizations l10n, Object err) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                l10n.compareLoadFailed,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge
                    .copyWith(color: context.onSurfaceColor),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => ref
                    .read(esimCompareProvider(_countryCode).notifier)
                    .refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.compareRetry),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDestinationPicker(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final q = query.trim().toLowerCase();
          final filtered = _destinations.entries
              .where((e) =>
                  e.key.toLowerCase().contains(q) ||
                  e.value.toLowerCase().contains(q))
              .toList();

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.selectDestinationTitle,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: l10n.searchDestinationHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor:
                        isDark ? AppColors.darkCard : AppColors.lightCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setSheetState(() => query = v),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      return ListTile(
                        leading: Text(CompareOfferCard.countryFlag(e.key),
                            style: const TextStyle(fontSize: 24)),
                        title: Text(
                          e.value,
                          style: TextStyle(
                            fontWeight: e.key == _countryCode
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: e.key == _countryCode
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.primary)
                            : null,
                        onTap: () {
                          setState(() {
                            _countryCode = e.key;
                            _countryName = e.value;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
