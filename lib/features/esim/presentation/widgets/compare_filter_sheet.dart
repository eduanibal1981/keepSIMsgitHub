/// The mobile equivalent of a desktop comparison site's left-hand filter rail.
///
/// Every control here maps to a parameter of `compare_esim_offers()`. Nothing
/// filters in Dart: the catalogue is 5,412 bundles, so the sheet edits a query
/// and the server does the work.
///
/// Values are drawn from what eSIM Go actually sells rather than round numbers
/// that look tidy — the real durations are 1/3/5/7/10/15/30/60/90/180 days and
/// the real data tiers are 1/2/3/5/10/20/50/100 GB, so a "14 days" chip would
/// match nothing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_compare_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class CompareFilterSheet extends ConsumerWidget {
  const CompareFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CompareFilterSheet(),
    );
  }

  static const _durations = <int>[1, 3, 7, 15, 30, 90];
  static const _dataGb = <int>[1, 3, 5, 10, 20, 50];
  static const _speedTiers = <(String, String)>[
    ('fixed', 'Fixed data'),
    ('lite', 'Unlimited Lite'),
    ('essential', 'Unlimited Essential'),
    ('plus', 'Unlimited Plus'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    final filters = ref.watch(esimCompareFiltersProvider);
    final notifier = ref.read(esimCompareFiltersProvider.notifier);

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
                      l10n.filterAll,
                      l10n.localTab,
                      l10n.regionalTab,
                      l10n.globalTab,
                    ],
                    selected: filters.coverage,
                    onTap: notifier.setCoverage,
                  ),
                  const SizedBox(height: 20),

                  _section(context, l10n.compareValidityLabel),
                  _chips<int?>(
                    context,
                    values: [null, ..._durations],
                    labels: [
                      l10n.filterAll,
                      ..._durations
                          .map((d) => '$d+ ${l10n.compareDaysSuffix}'),
                    ],
                    selected: filters.minDays,
                    onTap: notifier.setMinDays,
                  ),
                  const SizedBox(height: 20),

                  _section(context, l10n.compareDataLabel),
                  _chips<int?>(
                    context,
                    values: [null, ..._dataGb.map((g) => g * 1024)],
                    labels: [l10n.filterAll, ..._dataGb.map((g) => '$g GB+')],
                    selected: filters.minDataMb,
                    onTap: notifier.setMinData,
                  ),
                  // A minimum-data filter and "unlimited only" ask opposite
                  // questions, so the hint says which one wins rather than
                  // letting the list look mysteriously empty.
                  if (filters.unlimitedOnly && filters.minDataMb != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.compareUnlimitedOverridesData,
                        style: AppTextStyles.caption.copyWith(
                          color: context.onSurfaceColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  _section(context, l10n.compareSpeedLabel),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _speedTiers.map((t) {
                      final on = filters.speedTiers?.contains(t.$1) ?? false;
                      return FilterChip(
                        label: Text(t.$2),
                        selected: on,
                        onSelected: (sel) {
                          final next = <String>[
                            ...(filters.speedTiers ?? const <String>[])
                          ];
                          sel ? next.add(t.$1) : next.remove(t.$1);
                          notifier.setSpeedTiers(next);
                        },
                        selectedColor:
                            AppColors.primary.withValues(alpha: 0.2),
                        labelStyle: AppTextStyles.caption.copyWith(
                          color: on
                              ? AppColors.primary
                              : context.onSurfaceColor,
                          fontWeight:
                              on ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor:
                            isDark ? AppColors.darkCard : AppColors.lightCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: on
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: filters.unlimitedOnly,
                    onChanged: notifier.setUnlimitedOnly,
                    title: Text(
                      l10n.filterUnlimited,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: context.onSurfaceColor),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _section(context, l10n.compareMaxPriceLabel),
                  _chips<double?>(
                    context,
                    values: const [null, 10, 25, 50, 100],
                    labels: [
                      l10n.filterAll,
                      ...const [10, 25, 50, 100].map((p) => '\$$p'),
                    ],
                    selected: filters.maxPriceUsd,
                    onTap: notifier.setMaxPrice,
                  ),
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

  Widget _chips<T>(
    BuildContext context, {
    required List<T> values,
    required List<String> labels,
    required T selected,
    required void Function(T) onTap,
  }) {
    final isDark = context.isDarkMode;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(values.length, (i) {
        final on = values[i] == selected;
        return ChoiceChip(
          label: Text(labels[i]),
          selected: on,
          onSelected: (_) async {
            await HapticHelper.lightTick();
            onTap(values[i]);
          },
          selectedColor: AppColors.primary.withValues(alpha: 0.2),
          labelStyle: AppTextStyles.caption.copyWith(
            color: on ? AppColors.primary : context.onSurfaceColor,
            fontWeight: on ? FontWeight.bold : FontWeight.normal,
          ),
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: on
                  ? AppColors.primary
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
        );
      }),
    );
  }
}
