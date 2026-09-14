import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/esim/domain/entities/compare_offer.dart';
import 'package:keep_sims/features/esim/presentation/widgets/compare_offer_card.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class CompareOfferDetailsSheet extends StatefulWidget {
  const CompareOfferDetailsSheet({
    super.key,
    required this.offer,
    required this.onBuyPressed,
  });

  final CompareOffer offer;
  final VoidCallback onBuyPressed;

  static Future<void> show(
    BuildContext context, {
    required CompareOffer offer,
    required VoidCallback onBuyPressed,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompareOfferDetailsSheet(
        offer: offer,
        onBuyPressed: onBuyPressed,
      ),
    );
  }

  @override
  State<CompareOfferDetailsSheet> createState() =>
      _CompareOfferDetailsSheetState();
}

class _CompareOfferDetailsSheetState extends State<CompareOfferDetailsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<({String code, String name})> _resolvedCountries() {
    final list = <({String code, String name})>[];
    for (final code in widget.offer.countries) {
      final name = CompareOffer.countryNameForCode(code) ?? code;
      list.add((code: code, name: name));
    }
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    final offer = widget.offer;
    final countries = _resolvedCountries();
    final countryCount =
        offer.countryCount > 0 ? offer.countryCount : countries.length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
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
          const SizedBox(height: 12),
          // Drag handle pill
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header: Title & Close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title.isNotEmpty ? offer.title : offer.sourceName,
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: context.onSurfaceColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            offer.sourceName,
                            style: AppTextStyles.caption.copyWith(
                              color: context.onSurfaceColor.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (offer.typeTag != null) ...[
                            const SizedBox(width: 8),
                            _typeTagBadge(offer.typeTag!),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: context.onSurfaceColor.withValues(alpha: 0.7),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Summary Metric Cards (Airalo-inspired, retail price omitted)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _summaryCard(context, l10n, countryCount),
          ),

          const SizedBox(height: 12),

          // Tab Bar: Details & Countries
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: AppColors.primary,
            unselectedLabelColor:
                context.onSurfaceColor.withValues(alpha: 0.6),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            tabs: [
              Tab(text: l10n.compareDetailsTab),
              Tab(text: '${l10n.compareCountriesTab} ($countryCount)'),
            ],
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _detailsTab(context, l10n, countryCount),
                _countriesTab(context, l10n, countries),
              ],
            ),
          ),

          // Pinned Bottom Button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: offer.isAffiliate
                    ? OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onBuyPressed();
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(l10n.compareViewDeal),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8B5CF6),
                          side: const BorderSide(color: Color(0xFF8B5CF6)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onBuyPressed();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          '${l10n.buyPlanButton} • \$${offer.priceUsd.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary Cards ─────────────────────────────────────────────────────────
  Widget _summaryCard(
      BuildContext context, AppLocalizations l10n, int countryCount) {
    final isDark = context.isDarkMode;
    final offer = widget.offer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _metricItem(
            context,
            icon: Icons.public_rounded,
            label: l10n.compareCoverageLabel,
            value: countryCount > 1
                ? '$countryCount'
                : (offer.countries.isNotEmpty
                    ? (CompareOffer.countryNameForCode(offer.countries.first) ??
                        offer.countries.first)
                    : '1'),
            sub: countryCount > 1 ? l10n.compareCountriesSuffix : '',
          ),
          _divider(),
          _metricItem(
            context,
            icon: Icons.calendar_today_rounded,
            label: l10n.compareValidityLabel,
            value: '${offer.durationDays}',
            sub: l10n.compareDaysSuffix,
          ),
          _divider(),
          _metricItem(
            context,
            icon: Icons.data_usage_rounded,
            label: l10n.compareDataLabel,
            value: offer.formattedData,
            sub: '',
          ),
          _divider(),
          _metricItem(
            context,
            icon: Icons.payments_outlined,
            label: l10n.comparePriceLabel,
            value: '\$${offer.priceUsd.toStringAsFixed(2)}',
            sub: 'USD',
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        height: 32,
        width: 1,
        color: Colors.grey.withValues(alpha: 0.25),
      );

  Widget _metricItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String sub,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: context.onSurfaceColor,
          ),
        ),
        if (sub.isNotEmpty)
          Text(
            sub,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: context.onSurfaceColor.withValues(alpha: 0.55),
            ),
          ),
      ],
    );
  }

  // ── Details Tab ───────────────────────────────────────────────────────────
  Widget _detailsTab(
      BuildContext context, AppLocalizations l10n, int countryCount) {
    final offer = widget.offer;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      children: [
        _detailRow(
          context,
          icon: Icons.cell_tower_rounded,
          title: l10n.compareNetworkLabel,
          description: l10n.compareNetworkDesc(countryCount),
        ),
        _detailDivider(),
        _detailRow(
          context,
          icon: Icons.sim_card_outlined,
          title: l10n.comparePlanTypeLabel,
          description: l10n.comparePlanTypeDesc,
          badge: offer.typeTag,
        ),
        _detailDivider(),
        _detailRow(
          context,
          icon: Icons.speed_rounded,
          title: l10n.compareSpeedLabel,
          description: offer.exactSpeedDetail ??
              'High-speed 4G / 5G data with no throttling until data allowance is used.',
        ),
        _detailDivider(),
        _detailRow(
          context,
          icon: Icons.check_circle_outline_rounded,
          title: l10n.activationPolicyTitle,
          description: l10n.activationPolicyNotice,
        ),
        _detailDivider(),
        _detailRow(
          context,
          icon: Icons.verified_user_outlined,
          title: l10n.compareEkycLabel,
          description: l10n.compareEkycNotRequired,
        ),
        _detailDivider(),
        _detailRow(
          context,
          icon: Icons.qr_code_2_rounded,
          title: l10n.compareDeliveryLabel,
          description: offer.isAffiliate
              ? l10n.compareDeliveryPartnerDesc
              : l10n.compareDeliveryResaleDesc,
        ),
        _detailDivider(),
        _detailRow(
          context,
          icon: Icons.info_outline_rounded,
          title: l10n.compareOtherInfoLabel,
          description:
              '${l10n.compareRoamingNotice}\n${l10n.compareApnNotice}',
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.onSurfaceColor,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      _typeTagBadge(badge),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: AppTextStyles.caption.copyWith(
                    color: context.onSurfaceColor.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailDivider() => const Divider(height: 16, thickness: 0.7);

  // ── Countries Tab ─────────────────────────────────────────────────────────
  Widget _countriesTab(BuildContext context, AppLocalizations l10n,
      List<({String code, String name})> countries) {
    final isDark = context.isDarkMode;
    final q = _searchQuery.trim().toLowerCase();
    final filtered = countries.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Search Input
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.compareSearchCountryHint,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),

        // Countries List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            size: 40, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          l10n.compareNoCountriesMatch,
                          style: AppTextStyles.caption.copyWith(
                            color:
                                context.onSurfaceColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, thickness: 0.6),
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Text(
                            CompareOfferCard.countryFlag(item.code),
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: context.onSurfaceColor,
                                  ),
                                ),
                                Text(
                                  item.code,
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 11,
                                    color: context.onSurfaceColor
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.signal_cellular_alt_rounded,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '4G / 5G',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _typeTagBadge(String tag) {
    final isDayPass = tag == 'DayPass';
    final bg = isDayPass ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF);
    final fg = isDayPass ? const Color(0xFFD97706) : const Color(0xFF2563EB);
    final bd = isDayPass ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bd, width: 0.8),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
