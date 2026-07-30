/// Destination-first eSIM Plans Browse & Compare Screen (Airalo/Holafly Class)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/core/services/esim_capability_service.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_plans_controller.dart';
import 'package:keep_sims/features/esim/presentation/widgets/esim_checkout_sheet.dart';
import 'package:keep_sims/features/price_watch/presentation/providers/price_watch_provider.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum EsimSortMode {
  priceLowToHigh,
  pricePerGbLowToHigh,
  dataHighToLow,
}

enum EsimFilterMode {
  all,
  min5Gb,
  min15Days,
  unlimited,
}

class EsimPlansScreen extends ConsumerStatefulWidget {
  const EsimPlansScreen({super.key});

  @override
  ConsumerState<EsimPlansScreen> createState() => _EsimPlansScreenState();
}

class _EsimPlansScreenState extends ConsumerState<EsimPlansScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCountryCode = 'FR';
  String _selectedCountryName = 'France';

  late TabController _tabController;
  EsimSortMode _sortMode = EsimSortMode.priceLowToHigh;
  EsimFilterMode _filterMode = EsimFilterMode.all;

  static const Map<String, String> _popularDestinations = {
    'FR': 'France',
    'US': 'United States',
    'GB': 'United Kingdom',
    'DE': 'Germany',
    'ES': 'Spain',
    'IT': 'Italy',
    'AE': 'United Arab Emirates',
    'SA': 'Saudi Arabia',
    'TR': 'Turkey',
    'JP': 'Japan',
    'IN': 'India',
    'EG': 'Egypt',
    'OM': 'Oman',
    'TH': 'Thailand',
    'CA': 'Canada',
    'AU': 'Australia',
    'CH': 'Switzerland',
    'NL': 'Netherlands',
    'GR': 'Greece',
    'PT': 'Portugal',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initPreselectedCountry();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initPreselectedCountry() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('last_country, home_country_code')
            .eq('id', userId)
            .maybeSingle();

        if (profile != null) {
          final last = profile['last_country'] as String?;
          final home = profile['home_country_code'] as String?;
          final target = (last?.isNotEmpty == true) ? last : home;

          if (target != null && target.length == 2) {
            final code = target.toUpperCase();
            setState(() {
              _selectedCountryCode = code;
              _selectedCountryName =
                  _popularDestinations[code] ?? _countryCodeToName(code);
            });
          }
        }
      }
    } catch (_) {}
  }

  static String _countryCodeToEmoji(String countryCode) {
    if (countryCode.length != 2) return '🌐';
    final int firstLetter =
        countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter =
        countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  static String _countryCodeToName(String code) {
    return _popularDestinations[code.toUpperCase()] ?? code.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    final esimCapability = ref.watch(esimCapabilityServiceProvider);
    final plansState =
        ref.watch(esimPlansControllerProvider(_selectedCountryCode));

    final isDeviceSupported = esimCapability.value ?? false;

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
          icon: Icon(Icons.arrow_back_ios_rounded, color: context.onSurfaceColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // G5. Carries the country the user is browsing, not their detected
          // one — someone planning a trip is comparing against *that* corridor.
          IconButton(
            tooltip: 'Roam or eSIM? — compare with your carrier',
            icon: Icon(Icons.calculate_outlined, color: context.onSurfaceColor),
            onPressed: () => context.push(
              '${AppRoutes.esimRoamCalculator}?country=$_selectedCountryCode',
            ),
          ),
          _buildPriceWatchAction(context, ref),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.onSurfaceColor),
            onPressed: () => ref
                .read(
                    esimPlansControllerProvider(_selectedCountryCode).notifier)
                .refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Country Selector Bar ─────────────────────────────────
          _buildCountrySelectorHeader(context, isDark),

          // ── Local / Regional / Global Tabs ───────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor:
                  context.onSurfaceColor.withValues(alpha: 0.6),
              labelStyle: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: l10n.localTab),
                Tab(text: l10n.regionalTab),
                Tab(text: l10n.globalTab),
              ],
            ),
          ),

          // ── Filters & Sort Bar ───────────────────────────────────
          _buildFilterAndSortBar(context, isDark),

          // ── Plans List per Tab ───────────────────────────────────
          Expanded(
            child: plansState.when(
              data: (plans) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPlanListForTab(
                      context,
                      isDark,
                      plans,
                      tabCategory: 'local',
                      isDeviceSupported: isDeviceSupported,
                    ),
                    _buildPlanListForTab(
                      context,
                      isDark,
                      plans,
                      tabCategory: 'regional',
                      isDeviceSupported: isDeviceSupported,
                    ),
                    _buildPlanListForTab(
                      context,
                      isDark,
                      plans,
                      tabCategory: 'global',
                      isDeviceSupported: isDeviceSupported,
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Error loading plans: $err',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Price watch bell for the selected destination (G2) ────────
  //
  // A filled bell means an `offer_price_watches` row exists for this country,
  // so the nightly job will alert on the best $/GB dropping. Long-press opens
  // the full list. The icon is silent while the query is in flight rather than
  // guessing a state and flipping under the user's finger.
  Widget _buildPriceWatchAction(BuildContext context, WidgetRef ref) {
    final watchAsync =
        ref.watch(esimWatchForCountryProvider(_selectedCountryCode));
    final watch = watchAsync.value;
    final isWatching = watch != null && watch.isActive;

    // IconButton has no onLongPress, hence the wrapper.
    return GestureDetector(
      onLongPress: () => context.push(AppRoutes.esimPriceWatch),
      child: IconButton(
        tooltip: isWatching
            ? 'Watching $_selectedCountryCode prices'
            : 'Watch $_selectedCountryCode prices',
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
                  await controller.watchEsimCountry(_selectedCountryCode);
                } else {
                  // The row is kept and flipped rather than deleted, so a
                  // per-watch threshold the user set survives a mistaken tap.
                  await controller.setActive(watch.id, !watch.isActive);
                }

                if (!context.mounted) return;
                final nowWatching = watch == null || !watch.isActive;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 4),
                    content: Text(nowWatching
                        ? 'Watching $_selectedCountryName — we will tell you '
                            'if the best price drops.'
                        : 'Stopped watching $_selectedCountryName.'),
                    action: SnackBarAction(
                      label: 'View all',
                      onPressed: () => context.push(AppRoutes.esimPriceWatch),
                    ),
                  ),
                );
              },
      ),
    );
  }

  // ── Header: Country Picker Button ─────────────────────────────
  Widget _buildCountrySelectorHeader(BuildContext context, bool isDark) {
    final flag = _countryCodeToEmoji(_selectedCountryCode);

    return InkWell(
      onTap: () => _showCountryPickerBottomSheet(context, isDark),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Destination',
                    style: AppTextStyles.caption.copyWith(
                      color: context.onSurfaceColor.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    '$_selectedCountryName ($_selectedCountryCode)',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    'Change',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter and Sort Controls Bar ─────────────────────────────
  Widget _buildFilterAndSortBar(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Sort Dropdown
          PopupMenuButton<EsimSortMode>(
            initialValue: _sortMode,
            onSelected: (mode) {
              setState(() => _sortMode = mode);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sort_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _getSortTitle(_sortMode, l10n),
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: EsimSortMode.priceLowToHigh,
                child: Text(l10n.sortPriceLowToHigh),
              ),
              PopupMenuItem(
                value: EsimSortMode.pricePerGbLowToHigh,
                child: Text(l10n.sortPricePerGb),
              ),
              PopupMenuItem(
                value: EsimSortMode.dataHighToLow,
                child: Text(l10n.sortDataHighToLow),
              ),
            ],
          ),
          const SizedBox(width: 8),

          // Filter Chips
          _buildFilterChip(l10n.filterAll, EsimFilterMode.all, isDark),
          const SizedBox(width: 6),
          _buildFilterChip(l10n.filterMin5Gb, EsimFilterMode.min5Gb, isDark),
          const SizedBox(width: 6),
          _buildFilterChip(
              l10n.filterMin15Days, EsimFilterMode.min15Days, isDark),
          const SizedBox(width: 6),
          _buildFilterChip(
              l10n.filterUnlimited, EsimFilterMode.unlimited, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      String label, EsimFilterMode filter, bool isDark) {
    final isSelected = _filterMode == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filterMode = filter);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : context.onSurfaceColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
    );
  }

  String _getSortTitle(EsimSortMode mode, dynamic l10n) {
    switch (mode) {
      case EsimSortMode.priceLowToHigh:
        return 'Sort: Price';
      case EsimSortMode.pricePerGbLowToHigh:
        return 'Sort: \$/GB';
      case EsimSortMode.dataHighToLow:
        return 'Sort: Data';
    }
  }

  // ── Tab List Builder ──────────────────────────────────────────
  Widget _buildPlanListForTab(
    BuildContext context,
    bool isDark,
    List<EsimPlan> rawPlans, {
    required String tabCategory,
    required bool isDeviceSupported,
  }) {
    // 1. Filter by category
    List<EsimPlan> categoryPlans = rawPlans.where((p) {
      final total = p.supportedCountries.length;
      if (tabCategory == 'local') {
        return total <= 2; // Local bundle
      } else if (tabCategory == 'regional') {
        return total > 2 && total < 50; // Regional bundle
      } else {
        return total >= 50; // Global bundle
      }
    }).toList();

    // 2. Apply quick filters
    categoryPlans = categoryPlans.where((p) {
      switch (_filterMode) {
        case EsimFilterMode.all:
          return true;
        case EsimFilterMode.min5Gb:
          return p.dataAmountMB >= 5120;
        case EsimFilterMode.min15Days:
          return p.durationDays >= 15;
        case EsimFilterMode.unlimited:
          return p.dataAmountMB <= 0;
      }
    }).toList();

    // 3. Sort plans
    categoryPlans.sort((a, b) {
      switch (_sortMode) {
        case EsimSortMode.priceLowToHigh:
          return a.priceUsd.compareTo(b.priceUsd);
        case EsimSortMode.pricePerGbLowToHigh:
          return a.pricePerGb.compareTo(b.pricePerGb);
        case EsimSortMode.dataHighToLow:
          return b.dataAmountMB.compareTo(a.dataAmountMB);
      }
    });

    if (categoryPlans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No eSIM plans found',
                style: AppTextStyles.headlineSmall.copyWith(
                  color: context.onSurfaceColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try choosing another tab or clearing filter chips.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.onSurfaceColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Identify cheapest pricePerGb plan for "BEST VALUE" badge
    String? bestValuePlanId;
    double lowestPricePerGb = double.infinity;
    for (final plan in categoryPlans) {
      if (plan.pricePerGb > 0 && plan.pricePerGb < lowestPricePerGb) {
        lowestPricePerGb = plan.pricePerGb;
        bestValuePlanId = plan.id;
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: categoryPlans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final plan = categoryPlans[index];
        final isBestValue = plan.id == bestValuePlanId;

        return _buildPlanCard(
          context,
          isDark,
          plan,
          isBestValue: isBestValue,
          isDeviceSupported: isDeviceSupported,
        );
      },
    );
  }

  // ── Plan Card Item ────────────────────────────────────────────
  Widget _buildPlanCard(
    BuildContext context,
    bool isDark,
    EsimPlan plan, {
    required bool isBestValue,
    required bool isDeviceSupported,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _showPlanDetailSheet(
          context,
          isDark,
          plan,
          isBestValue: isBestValue,
          isDeviceSupported: isDeviceSupported,
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isBestValue
                  ? const Color(0xFF10B981)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: isBestValue ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Data amount badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      plan.formattedData,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Best Value Badge
                  if (isBestValue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.bestValueBadge,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${plan.priceUsd.toStringAsFixed(2)}',
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: context.onSurfaceColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // G11 — the headline price in the buyer's own currency.
                      // Only the total is converted, not the per-GB unit: two
                      // approximations stacked read as a quoted price rather
                      // than a rough guide.
                      ApproxLocalText(
                        plan.priceUsd,
                        textAlign: TextAlign.end,
                      ),
                      if (plan.pricePerGb > 0)
                        Text(
                          '\$${plan.pricePerGb.toStringAsFixed(2)} ${l10n.perGb}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(
                plan.name,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: context.onSurfaceColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${plan.durationDays} Days validity',
                    style: AppTextStyles.caption.copyWith(
                      color: context.onSurfaceColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.public_rounded,
                    size: 16,
                    color: context.onSurfaceColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${plan.supportedCountries.length} countries',
                    style: AppTextStyles.caption.copyWith(
                      color: context.onSurfaceColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Plan Detail Bottom Sheet ─────────────────────────────────
  void _showPlanDetailSheet(
    BuildContext context,
    bool isDark,
    EsimPlan plan, {
    required bool isBestValue,
    required bool isDeviceSupported,
  }) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Destination & Flag
                Row(
                  children: [
                    Text(
                      _countryCodeToEmoji(_selectedCountryCode),
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: AppTextStyles.titleLarge.copyWith(
                              color: context.onSurfaceColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Provider: ${plan.providerName}',
                            style: AppTextStyles.caption.copyWith(
                              color: context.onSurfaceColor
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Key Spec Chips Grid
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSpecItem(context, 'Data', plan.formattedData,
                          Icons.data_usage_rounded),
                      _buildSpecItem(context, 'Validity',
                          '${plan.durationDays} Days', Icons.timer_rounded),
                      _buildSpecItem(context, 'Price',
                          '\$${plan.priceUsd.toStringAsFixed(2)}', Icons.payments_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Activation Policy Card
                Text(
                  l10n.activationPolicyTitle,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.activationPolicyNotice,
                          style: AppTextStyles.caption.copyWith(
                            color: context.onSurfaceColor,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Covered Countries Section
                Text(
                  l10n.coveredCountriesTitle,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: plan.supportedCountries.take(20).map((code) {
                    return Chip(
                      avatar: Text(_countryCodeToEmoji(code)),
                      label: Text(code),
                      backgroundColor:
                          isDark ? AppColors.darkCard : AppColors.lightCard,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                if (plan.supportedCountries.length > 20)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '+ ${plan.supportedCountries.length - 20} more countries',
                      style: AppTextStyles.caption.copyWith(
                        color: context.onSurfaceColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                const SizedBox(height: 28),

                // Buy CTA Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isDeviceSupported
                        ? () async {
                            await HapticHelper.mediumImpact();
                            if (context.mounted) {
                              Navigator.pop(context);
                              EsimCheckoutSheet.show(context, plan);
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isDeviceSupported
                          ? '${l10n.buyPlanButton} • \$${plan.priceUsd.toStringAsFixed(2)}'
                          : l10n.deviceIncompatibleNotice,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpecItem(
      BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: context.onSurfaceColor,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: context.onSurfaceColor.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // ── Country Picker Bottom Sheet ──────────────────────────────
  void _showCountryPickerBottomSheet(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    String filterQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = _popularDestinations.entries.where((entry) {
              final code = entry.key.toLowerCase();
              final name = entry.value.toLowerCase();
              final q = filterQuery.toLowerCase();
              return code.contains(q) || name.contains(q);
            }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              padding: const EdgeInsets.all(24),
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
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.selectDestinationTitle,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Field
                  TextField(
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
                    onChanged: (val) {
                      setSheetState(() => filterQuery = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // List of destinations
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        final code = entry.key;
                        final name = entry.value;
                        final flag = _countryCodeToEmoji(code);

                        return ListTile(
                          leading: Text(flag, style: const TextStyle(fontSize: 24)),
                          title: Text(name,
                              style: TextStyle(
                                fontWeight: code == _selectedCountryCode
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              )),
                          trailing: code == _selectedCountryCode
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedCountryCode = code;
                              _selectedCountryName = name;
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
        );
      },
    );
  }
}
