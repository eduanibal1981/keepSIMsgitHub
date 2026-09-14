/// The mobile equivalent of a desktop comparison site's left-hand filter rail.
///
/// Every control here maps to a parameter of `compare_esim_offers()`. Nothing
/// filters in Dart: the catalogue is 5,412 bundles, so the sheet edits a query
/// and the server does the work.
///
/// Each numeric dimension offers the same three shapes, because "any length",
/// "between 1 and 7 days" and "the 3-day or the 7-day one" are three different
/// questions and the old minimum-only chips could express none of the last two.
/// Data has a fourth, Unlimited, which is not a quantity: it used to be a
/// switch sitting one section above a Speed list containing "Unlimited Lite"
/// and "Unlimited Plus", so it fairly asked "unlimited what?". As one of the
/// answers to "how much data" there is nothing left to misread.
///
/// The values on offer are read from the catalogue via
/// `compare_esim_filter_bounds()` rather than hard-coded. They are a property
/// of what is on sale and they differ by destination — France sells metered
/// data at four durations where the global catalogue spans ten — so a fixed
/// ladder is an empty result waiting to happen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/esim/domain/entities/compare_offer.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_compare_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class CompareFilterSheet extends ConsumerStatefulWidget {
  const CompareFilterSheet({
    super.key,
    required this.countryIsoCode,
    this.countryName,
  });

  final String countryIsoCode;
  final String? countryName;

  static Future<void> show(
    BuildContext context,
    String countryIsoCode, {
    String? countryName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompareFilterSheet(
        countryIsoCode: countryIsoCode,
        countryName: countryName,
      ),
    );
  }

  @override
  ConsumerState<CompareFilterSheet> createState() => _CompareFilterSheetState();
}

class _CompareFilterSheetState extends ConsumerState<CompareFilterSheet> {
  static const _speedTiers = <(String, String)>[
    ('lite', 'Lite – 1 GB at Max speed then throttle to 512 kb/s'),
    ('essential', 'Essential – 2 GB at Max speed then throttle to 1 Mb/s'),
    ('plus', 'Plus – 3 GB at Max speed then throttle to 1 Mb/s'),
  ];

  late final TextEditingController _minPrice;
  late final TextEditingController _maxPrice;

  /// Each keystroke would otherwise be a round trip to a query over 5,412
  /// bundles. Typing "100" is one search, not three.
  Timer? _priceDebounce;

  @override
  void initState() {
    super.initState();
    final f = ref.read(esimCompareFiltersProvider);
    _minPrice = TextEditingController(text: _money(f.minPriceUsd));
    _maxPrice = TextEditingController(text: _money(f.maxPriceUsd));
  }

  @override
  void dispose() {
    _priceDebounce?.cancel();
    _minPrice.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  static String _money(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  void _onPriceTyped() {
    _priceDebounce?.cancel();
    _priceDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      // An empty box is null, never 0. On the maximum side those are opposite
      // instructions — "no ceiling" versus "free only" — so a blank field is
      // never substituted with a number.
      ref.read(esimCompareFiltersProvider.notifier).setPriceRange(
            min: double.tryParse(_minPrice.text.trim()),
            max: double.tryParse(_maxPrice.text.trim()),
          );
    });
  }

  String _localCoverageLabel(AppLocalizations l10n) {
    final name = (widget.countryName != null && widget.countryName!.trim().isNotEmpty)
        ? widget.countryName!.trim()
        : (CompareOffer.countryNameForCode(widget.countryIsoCode) ??
            widget.countryIsoCode.trim());
    if (name.isNotEmpty) {
      return l10n.compareCoverageLocalCountry(name);
    }
    return l10n.localTab;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    final filters = ref.watch(esimCompareFiltersProvider);
    final notifier = ref.read(esimCompareFiltersProvider.notifier);
    final bounds = ref
            .watch(esimCompareBoundsProvider(widget.countryIsoCode))
            .value ??
        const CompareBounds();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.compareFiltersTitle,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: filters.activeCount == 0
                      ? null
                      : () async {
                          await HapticHelper.lightTick();
                          _minPrice.clear();
                          _maxPrice.clear();
                          notifier.reset();
                        },
                  child: Text(l10n.compareReset),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section(context, l10n.compareCoverageLabel),
                  _chips<String?>(
                    context,
                    values: const [null, 'local', 'regional', 'global'],
                    labels: [
                      l10n.compareModeAll,
                      _localCoverageLabel(l10n),
                      l10n.regionalTab,
                      l10n.globalTab,
                    ],
                    selected: filters.coverage,
                    onTap: notifier.setCoverage,
                  ),
                  const SizedBox(height: 20),

                  ..._validitySection(context, l10n, filters, notifier, bounds),
                  const SizedBox(height: 20),

                  ..._dataSection(context, l10n, filters, notifier, bounds),
                  const SizedBox(height: 20),

                  if (filters.dataMode == DataFilterMode.unlimited) ...[
                    _section(context, l10n.compareSpeedLabel),
                    _speedChips(context, filters, notifier),
                    const SizedBox(height: 20),
                  ],

                  ..._priceSection(context, l10n, filters, notifier, bounds),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    l10n.compareShowResults,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Validity ──────────────────────────────────────────────────────────────
  List<Widget> _validitySection(
    BuildContext context,
    AppLocalizations l10n,
    CompareFilters filters,
    EsimCompareFilters notifier,
    CompareBounds bounds,
  ) {
    final ladder = bounds.durations;
    String label(int d) => '$d ${l10n.compareDaysSuffix}';

    return [
      _section(context, l10n.compareValidityLabel),
      _modeChips<RangeFilterMode>(
        context,
        values: ladder.isEmpty
            ? const [RangeFilterMode.all]
            : RangeFilterMode.values,
        labels: [
          l10n.compareModeAll,
          l10n.compareModeRange,
          l10n.compareModePickDays,
        ],
        selected: filters.validityMode,
        onTap: notifier.setValidityMode,
      ),
      if (ladder.isEmpty) _note(context, l10n.compareBoundsUnavailable),
      if (filters.validityMode == RangeFilterMode.range && ladder.isNotEmpty)
        _ladderRange(
          context,
          ladder: ladder,
          min: filters.minDays,
          max: filters.maxDays,
          valueLabel: label,
          caption: (lo, hi) => l10n.compareRangeDays(lo, hi),
          onChanged: notifier.setDaysRange,
        ),
      if (filters.validityMode == RangeFilterMode.exact && ladder.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _multiChips<int>(
            context,
            values: ladder,
            label: label,
            selected: filters.daysExact,
            onToggle: notifier.toggleDayExact,
          ),
        ),
    ];
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  List<Widget> _dataSection(
    BuildContext context,
    AppLocalizations l10n,
    CompareFilters filters,
    EsimCompareFilters notifier,
    CompareBounds bounds,
  ) {
    final ladder = bounds.canonicalDataMb;

    // Unlimited is offered only where unlimited plans exist, for the same
    // reason the sizes come from the catalogue: a mode that can only return
    // nothing is not a choice.
    final modes = <DataFilterMode>[
      DataFilterMode.all,
      if (ladder.isNotEmpty) DataFilterMode.range,
      if (ladder.isNotEmpty) DataFilterMode.exact,
      if (bounds.hasUnlimited) DataFilterMode.unlimited,
    ];

    return [
      _section(context, l10n.compareDataLabel),
      _modeChips<DataFilterMode>(
        context,
        values: modes,
        labels: [
          for (final m in modes)
            switch (m) {
              DataFilterMode.all => l10n.compareModeAll,
              DataFilterMode.range => l10n.compareModeRange,
              DataFilterMode.exact => l10n.compareModePickSizes,
              DataFilterMode.unlimited => l10n.compareModeUnlimited,
            }
        ],
        selected: filters.dataMode,
        onTap: notifier.setDataMode,
      ),
      if (ladder.isEmpty && !bounds.hasUnlimited)
        _note(context, l10n.compareBoundsUnavailable),
      if (filters.dataMode == DataFilterMode.range && ladder.isNotEmpty) ...[
        _ladderRange(
          context,
          ladder: ladder,
          min: filters.minDataMb,
          max: filters.maxDataMb,
          valueLabel: CompareOffer.formatDataMb,
          caption: (lo, hi) => l10n.compareRangeData(
              CompareOffer.formatDataMb(lo), CompareOffer.formatDataMb(hi)),
          onChanged: notifier.setDataRange,
        ),
        _note(context, l10n.compareMeteredOnlyNote),
      ],
      if (filters.dataMode == DataFilterMode.exact && ladder.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _multiChips<int>(
            context,
            values: ladder,
            label: CompareOffer.formatDataMb,
            selected: filters.dataExactMb,
            onToggle: notifier.toggleDataExact,
          ),
        ),
        _note(context, l10n.compareMeteredOnlyNote),
      ],
    ];
  }

  // ── Price ─────────────────────────────────────────────────────────────────
  List<Widget> _priceSection(
    BuildContext context,
    AppLocalizations l10n,
    CompareFilters filters,
    EsimCompareFilters notifier,
    CompareBounds bounds,
  ) {
    return [
      _section(context, l10n.comparePriceLabel),
      _modeChips<bool>(
        context,
        values: const [false, true],
        labels: [l10n.compareModeAll, l10n.compareModeRange],
        selected: filters.priceRangeOn,
        onTap: (on) {
          _priceDebounce?.cancel();
          _minPrice.clear();
          _maxPrice.clear();
          notifier.setPriceRangeOn(on);
        },
      ),
      if (filters.priceRangeOn) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _priceField(context, _minPrice, l10n.comparePriceMinHint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _priceField(context, _maxPrice, l10n.comparePriceMaxHint),
            ),
          ],
        ),
        _note(
          context,
          // The concrete floor and ceiling turn "leave it empty for the
          // highest price available" into something the user can picture.
          // Without bounds we can still state the rule, just not the numbers.
          bounds.minPriceUsd == null || bounds.maxPriceUsd == null
              ? l10n.comparePriceRangeHelpPlain
              : l10n.comparePriceRangeHelp(
                  '\$${bounds.minPriceUsd!.toStringAsFixed(2)}',
                  '\$${bounds.maxPriceUsd!.toStringAsFixed(2)}',
                ),
        ),
      ],
    ];
  }

  Widget _priceField(
      BuildContext context, TextEditingController controller, String hint) {
    final isDark = context.isDarkMode;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      onChanged: (_) => _onPriceTyped(),
      style: AppTextStyles.bodyMedium.copyWith(color: context.onSurfaceColor),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: '\$ ',
        isDense: true,
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  // ── Shared pieces ─────────────────────────────────────────────────────────
  /// A range over a ladder of real catalogue values.
  ///
  /// The slider moves over POSITIONS in that ladder, not over days or
  /// megabytes, because the ladders are not evenly spaced — 1/3/5/7/10/15/30/
  /// 60/90/180 on a linear axis would spend most of its travel between 90 and
  /// 180, where four bundles live. Position-based travel gives every real
  /// choice the same width of thumb.
  ///
  /// An end left at the extreme is reported as null: dragging the handles wide
  /// open means "no bound on that side", which is exactly what an untouched
  /// range should mean, and keeps the Filters badge from counting a filter
  /// that excludes nothing.
  Widget _ladderRange(
    BuildContext context, {
    required List<int> ladder,
    required int? min,
    required int? max,
    required String Function(int value) valueLabel,
    required String Function(int lo, int hi) caption,
    required void Function(int?, int?) onChanged,
  }) {
    final last = ladder.length - 1;
    var startIdx = min == null ? 0 : ladder.indexOf(min);
    var endIdx = max == null ? last : ladder.indexOf(max);
    // A bound that is no longer on sale here (the destination changed under a
    // filter that survived it) falls back to the open end rather than to
    // index -1, which would read as the smallest value and silently narrow.
    if (startIdx < 0) startIdx = 0;
    if (endIdx < 0) endIdx = last;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption(ladder[startIdx], ladder[endIdx]),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (last > 0)
            RangeSlider(
              values: RangeValues(startIdx.toDouble(), endIdx.toDouble()),
              min: 0,
              max: last.toDouble(),
              divisions: last,
              activeColor: AppColors.primary,
              inactiveColor: context.onSurfaceColor.withValues(alpha: 0.2),
              labels: RangeLabels(
                valueLabel(ladder[startIdx]),
                valueLabel(ladder[endIdx]),
              ),
              onChanged: (v) {
                final s = v.start.round();
                final e = v.end.round();
                onChanged(
                  s == 0 ? null : ladder[s],
                  e == last ? null : ladder[e],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _speedChips(BuildContext context, CompareFilters filters,
      EsimCompareFilters notifier) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _speedTiers.map((t) {
        final on = filters.speedTiers?.contains(t.$1) ?? false;
        return _chip(
          context,
          label: t.$2,
          selected: on,
          onTap: () {
            final next = <String>[
              ...(filters.speedTiers ?? const <String>[])
            ];
            if (on) {
              next.remove(t.$1);
            } else {
              next.add(t.$1);
            }
            notifier.setSpeedTiers(next);
          },
        );
      }).toList(),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: context.onSurfaceColor.withValues(alpha: 0.55),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _note(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          text,
          style: AppTextStyles.caption.copyWith(
            color: context.onSurfaceColor.withValues(alpha: 0.6),
            height: 1.35,
          ),
        ),
      );

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = context.isDarkMode;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      // The tick is a side effect, not a precondition. Awaiting it — which is
      // what this sheet used to do — puts a platform round trip between the
      // tap and the filter being applied, and holds the filter hostage to the
      // vibration motor answering at all.
      onSelected: (_) {
        unawaited(HapticHelper.lightTick());
        onTap();
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: AppTextStyles.caption.copyWith(
        color: selected ? AppColors.primary : context.onSurfaceColor,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? AppColors.primary
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
    );
  }

  Widget _chips<T>(
    BuildContext context, {
    required List<T> values,
    required List<String> labels,
    required T selected,
    required void Function(T) onTap,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        values.length,
        (i) => _chip(
          context,
          label: labels[i],
          selected: values[i] == selected,
          onTap: () => onTap(values[i]),
        ),
      ),
    );
  }

  /// Same control as [_chips]; named apart because these pick the SHAPE of the
  /// question rather than a value, and switching one clears the other shape's
  /// answers.
  Widget _modeChips<T>(
    BuildContext context, {
    required List<T> values,
    required List<String> labels,
    required T selected,
    required void Function(T) onTap,
  }) =>
      _chips<T>(
        context,
        values: values,
        labels: labels,
        selected: selected,
        onTap: onTap,
      );

  Widget _multiChips<T>(
    BuildContext context, {
    required List<T> values,
    required String Function(T) label,
    required List<T> selected,
    required void Function(T) onToggle,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map((v) => _chip(
                context,
                label: label(v),
                selected: selected.contains(v),
                onTap: () => onToggle(v),
              ))
          .toList(),
    );
  }
}
