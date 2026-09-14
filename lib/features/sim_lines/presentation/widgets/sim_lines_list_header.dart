import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/sim_lines/presentation/models/sim_lines_list_filter.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

/// Presentational header placed above the SIM lines list.
///
/// Contains the search input with clear action, the filter toggle button,
/// and the expandable row of quick-filter choice chips.
class SimLinesListHeader extends StatelessWidget {
  const SimLinesListHeader({
    super.key,
    required this.searchController,
    required this.selectedFilter,
    required this.filtersExpanded,
    required this.scheduleFiltersEnabled,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onToggleFilters,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final SimLinesListFilter selectedFilter;
  final bool filtersExpanded;
  final bool scheduleFiltersEnabled;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onToggleFilters;
  final ValueChanged<SimLinesListFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: searchController,
                    builder: (context, value, _) {
                      final hasText = value.text.isNotEmpty;
                      return TextField(
                        controller: searchController,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.search,
                        onChanged: onSearchChanged,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.searchNameOrNumber,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                          suffixIcon: hasText
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                  onPressed: () {
                                    searchController.clear();
                                    onClearSearch();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark
                              ? AppColors.darkSurface
                              : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.primary
                                  : AppColors.lightPrimary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterButton(context, isDark, l10n),
            ],
          ),
          if (filtersExpanded) ...[
            const SizedBox(height: 10),
            _buildQuickFilterRow(context, isDark, l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final hasActiveFilter = selectedFilter != SimLinesListFilter.all;
    final tooltip = filtersExpanded ? l10n.hideFilters : l10n.showFilters;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onToggleFilters,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder.withValues(alpha: 0.5),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                if (hasActiveFilter)
                  PositionedDirectional(
                    top: -4,
                    end: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00B4D8),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: const Center(
                        child: Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFilterRow(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip(
            context: context,
            isDark: isDark,
            filter: SimLinesListFilter.all,
            label: l10n.allFilter,
            isEnabled: true,
          ),
          const SizedBox(width: 8),
          _buildChip(
            context: context,
            isDark: isDark,
            filter: SimLinesListFilter.active,
            label: l10n.active,
            isEnabled: true,
          ),
          const SizedBox(width: 8),
          _buildChip(
            context: context,
            isDark: isDark,
            filter: SimLinesListFilter.alertSoon,
            label: l10n.alertSoon,
            isEnabled: scheduleFiltersEnabled,
          ),
          const SizedBox(width: 8),
          _buildChip(
            context: context,
            isDark: isDark,
            filter: SimLinesListFilter.autoRefill,
            label: l10n.autoRefill,
            isEnabled: scheduleFiltersEnabled,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required bool isDark,
    required SimLinesListFilter filter,
    required String label,
    required bool isEnabled,
  }) {
    final isSelected = selectedFilter == filter;
    const activeCyan = Color(0xFF00B4D8);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: isEnabled
          ? (selected) {
              onFilterChanged(filter);
            }
          : null,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: !isEnabled
            ? (isDark
                  ? AppColors.textTertiaryDark.withValues(alpha: 0.4)
                  : AppColors.textTertiaryLight.withValues(alpha: 0.4))
            : (isSelected
                  ? (isDark ? AppColors.darkBg : Colors.white)
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight)),
      ),
      selectedColor: isDark ? AppColors.primary : activeCyan,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      disabledColor: isDark
          ? AppColors.darkSurface.withValues(alpha: 0.5)
          : Colors.grey.shade100,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : (isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder.withValues(alpha: 0.5)),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
