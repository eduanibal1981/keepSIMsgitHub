import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/sim_line_card.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/core/widgets/shimmer_loading.dart';
import 'package:keep_sims/core/widgets/empty_state.dart';
import 'package:keep_sims/core/widgets/error_state.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/core/services/analytics_service.dart';

import 'package:keep_sims/features/sim_lines/presentation/models/sim_lines_list_filter.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/sim_lines_list_header.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class SimLinesListScreen extends ConsumerStatefulWidget {
  const SimLinesListScreen({super.key});

  @override
  ConsumerState<SimLinesListScreen> createState() => _SimLinesListScreenState();
}

class _SimLinesListScreenState extends ConsumerState<SimLinesListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSelectMode = false;
  final Set<String> _selectedIds = {};
  bool _isBulkActionLoading = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SimLinesListFilter _selectedFilter = SimLinesListFilter.all;
  bool _filtersExpanded = true;

  /// Live "a refill just completed" signal — see [_subscribeToRefillActivity].
  RealtimeChannel? _refillChannel;
  Timer? _refillRefreshDebounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(analyticsServiceProvider).logScreenView('sim_lines_list');
      _subscribeToRefillActivity();
    });
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _isSelectMode = false;
          _selectedIds.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refillRefreshDebounce?.cancel();
    _refillChannel?.unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

  /// Re-reads the lines when one of this user's refills actually completes or lines update.
  void _subscribeToRefillActivity() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _refillChannel?.unsubscribe();
    _refillChannel = Supabase.instance.client
        .channel('sim_lines_refill_activity_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'topup_executions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _triggerDebouncedRefresh();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sim_lines',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _triggerDebouncedRefresh();
          },
        )
        .subscribe();
  }

  void _triggerDebouncedRefresh() {
    _refillRefreshDebounce?.cancel();
    _refillRefreshDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      ref.invalidate(simLinesControllerProvider);
      ref.invalidate(scheduledTopupControllerProvider);
    });
  }

  Future<void> _bulkToggleRefill(
    List<SimLine> selectedLines,
    List<ScheduledTopup> schedules,
    bool enable,
  ) async {
    setState(() => _isBulkActionLoading = true);
    int successCount = 0;
    int failCount = 0;

    for (final line in selectedLines) {
      final schedule = schedules.firstWhereOrNull(
        (s) => s.simLineId == line.id,
      );
      if (schedule != null) {
        if (schedule.isActive != enable) {
          final res = await ref
              .read(scheduledTopupControllerProvider.notifier)
              .toggleActive(schedule.id, enable);
          if (res is Success) {
            successCount++;
          } else {
            failCount++;
          }
        } else {
          successCount++;
        }
      } else {
        failCount++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enable
                ? 'Bulk Resume complete: $successCount active, $failCount skipped.'
                : 'Bulk Pause complete: $successCount paused, $failCount skipped.',
          ),
          backgroundColor: failCount > 0
              ? AppColors.warning
              : AppColors.success,
        ),
      );
      setState(() {
        _isBulkActionLoading = false;
        _isSelectMode = false;
        _selectedIds.clear();
      });
    }
  }

  Widget _buildBulkActionsConsole(List<SimLine> myLines) {
    if (!_isSelectMode) return const SizedBox.shrink();

    final selectedLines = myLines
        .where((l) => _selectedIds.contains(l.id))
        .toList();
    final count = selectedLines.length;
    final schedules = ref.read(scheduledTopupControllerProvider).value ?? [];

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: context.isDarkMode ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  (context.isDarkMode
                          ? AppColors.primary
                          : AppColors.lightPrimary)
                      .withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (context.isDarkMode
                            ? AppColors.primary
                            : AppColors.lightPrimary)
                        .withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (context.isDarkMode
                                      ? AppColors.primary
                                      : AppColors.lightPrimary)
                                  .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count Selected',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: context.isDarkMode
                                ? AppColors.primaryLight
                                : AppColors.lightPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context)!.bulkActionsConsole,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: context.isDarkMode
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: context.isDarkMode
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSelectMode = false;
                        _selectedIds.clear();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildConsoleButton(
                      label: AppLocalizations.of(context)!.resume,
                      icon: Icons.play_arrow_rounded,
                      color: AppColors.secondary,
                      onPressed: _isBulkActionLoading || count == 0
                          ? null
                          : () => _bulkToggleRefill(
                              selectedLines,
                              schedules,
                              true,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildConsoleButton(
                      label: AppLocalizations.of(context)!.pause,
                      icon: Icons.pause_rounded,
                      color: AppColors.warning,
                      onPressed: _isBulkActionLoading || count == 0
                          ? null
                          : () => _bulkToggleRefill(
                              selectedLines,
                              schedules,
                              false,
                            ),
                    ),
                  ),
                ],
              ),
              if (_isBulkActionLoading) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                  child: LinearProgressIndicator(
                    color: context.isDarkMode
                        ? AppColors.primary
                        : AppColors.lightPrimary,
                    backgroundColor: context.isDarkMode
                        ? AppColors.darkBg
                        : AppColors.lightBg,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsoleButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final isDark = context.isDarkMode;
    final buttonColor = isDark
        ? color
        : (color == AppColors.secondary || color == AppColors.success
              ? AppColors.lightSecondary
              : (color == AppColors.warning ? AppColors.lightWarning : color));

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: buttonColor),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: buttonColor,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor.withValues(alpha: 0.15),
        foregroundColor: buttonColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: buttonColor.withValues(alpha: 0.3), width: 1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final simLinesState = ref.watch(simLinesControllerProvider);
    final countriesState = ref.watch(supportedCountriesProvider);
    final householdState = ref.watch(householdControllerProvider).value;
    final scheduledTopupsAsync = ref.watch(scheduledTopupControllerProvider);

    final simLines = simLinesState.value ?? [];
    final currentUserId = ref.watch(authControllerProvider).value?.id;
    final myLines = simLines
        .where((line) => line.userId == currentUserId)
        .toList();
    final sharedLines = simLines
        .where((line) => line.userId != currentUserId)
        .toList();

    final schedules = scheduledTopupsAsync.value ?? <ScheduledTopup>[];
    final scheduleFiltersEnabled =
        scheduledTopupsAsync.hasValue && !scheduledTopupsAsync.hasError;

    final filteredMyLines = filterSimLines(
      lines: myLines,
      schedules: schedules,
      query: _searchQuery,
      filter: _selectedFilter,
    );

    final filteredSharedLines = filterSimLines(
      lines: sharedLines,
      schedules: schedules,
      query: _searchQuery,
      filter: _selectedFilter,
    );

    final currentTabLines = _tabController.index == 0 ? myLines : sharedLines;
    final visibleLines = _tabController.index == 0
        ? filteredMyLines
        : filteredSharedLines;

    return Scaffold(
      backgroundColor: context.isDarkMode
          ? AppColors.darkBg
          : AppColors.lightBg,
      appBar: AppBar(
        toolbarHeight: 68,
        leading: _isSelectMode
            ? IconButton(
                icon: Icon(
                  Icons.close,
                  color: context.isDarkMode
                      ? Colors.white
                      : AppColors.textPrimaryLight,
                ),
                onPressed: () {
                  setState(() {
                    _isSelectMode = false;
                    _selectedIds.clear();
                  });
                },
              )
            : null,
        title: Text(
          _isSelectMode
              ? '${_selectedIds.length} Selected'
              : AppLocalizations.of(context)!.protectedSims,
          style: AppTextStyles.headlineLarge.copyWith(
            color: context.isDarkMode
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isSelectMode)
            IconButton(
              icon: Icon(
                _selectedIds.length == visibleLines.length
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
                color: context.isDarkMode
                    ? Colors.white
                    : AppColors.textPrimaryLight,
              ),
              onPressed: () {
                setState(() {
                  if (_selectedIds.length == visibleLines.length) {
                    _selectedIds.clear();
                    _isSelectMode = false;
                  } else {
                    _selectedIds.addAll(visibleLines.map((l) => l.id));
                  }
                });
              },
            )
          else ...[
            _buildAddSimAction(context),
            _buildRefreshAction(context),
            const SizedBox(width: 8),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: context.isDarkMode
                ? AppColors.primary
                : AppColors.lightPrimary,
            indicatorWeight: 3,
            labelColor: context.isDarkMode
                ? Colors.white
                : AppColors.lightPrimary,
            unselectedLabelColor: context.isDarkMode
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            tabs: [
              _buildTabItem(
                context: context,
                index: 0,
                icon: Icons.person_rounded,
                label: AppLocalizations.of(context)!.mySims,
                count: myLines.length,
              ),
              _buildTabItem(
                context: context,
                index: 1,
                icon: Icons.people_rounded,
                label: AppLocalizations.of(context)!.sharedWithMe,
                count: sharedLines.length,
              ),
            ],
          ),
        ),
      ),
      body: simLinesState.when(
        data: (lines) {
          final showHeader = !_isSelectMode && currentTabLines.isNotEmpty;

          return Column(
            children: [
              if (showHeader)
                SimLinesListHeader(
                  searchController: _searchController,
                  selectedFilter: _selectedFilter,
                  filtersExpanded: _filtersExpanded,
                  scheduleFiltersEnabled: scheduleFiltersEnabled,
                  onSearchChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  onClearSearch: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  onToggleFilters: () {
                    setState(() {
                      _filtersExpanded = !_filtersExpanded;
                    });
                  },
                  onFilterChanged: (filter) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                ),
              Expanded(
                child: Stack(
                  children: [
                    TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: My SIM Cards
                        myLines.isEmpty
                            ? _buildEmptyState(context)
                            : (filteredMyLines.isEmpty
                                  ? _buildNoResultsState(context)
                                  : _buildLinesList(
                                      context,
                                      filteredMyLines,
                                      countriesState.value ?? [],
                                      currentUserId,
                                      householdState,
                                      isShared: false,
                                    )),

                        // Tab 2: Family Shared SIMs
                        sharedLines.isEmpty
                            ? _buildSharedEmptyState(context)
                            : (filteredSharedLines.isEmpty
                                  ? _buildNoResultsState(context)
                                  : _buildLinesList(
                                      context,
                                      filteredSharedLines,
                                      countriesState.value ?? [],
                                      currentUserId,
                                      householdState,
                                      isShared: true,
                                    )),
                      ],
                    ),
                    _buildBulkActionsConsole(visibleLines),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const SIMLinesShimmer(),
        error: (err, stack) => ErrorStateView(
          errorMessage: err.toString(),
          onRetry: () async {
            await HapticHelper.mediumImpact();
            ref.invalidate(simLinesControllerProvider);
            ref.invalidate(householdControllerProvider);
          },
        ),
      ),
    );
  }

  Widget _buildAddSimAction(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isCompact = screenWidth < 380 || textScale > 1.25;
    final isDark = context.isDarkMode;

    if (isCompact) {
      return IconButton(
        icon: const Icon(Icons.add_rounded, size: 22),
        tooltip: AppLocalizations.of(context)!.addSim,
        style: IconButton.styleFrom(
          backgroundColor: isDark ? AppColors.primary : const Color(0xFF00B4D8),
          foregroundColor: isDark ? AppColors.darkBg : Colors.white,
          minimumSize: const Size(42, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () async {
          await HapticHelper.lightTick();
          if (!context.mounted) return;
          _openAddSim(context);
        },
      );
    }

    return FilledButton.icon(
      onPressed: () async {
        await HapticHelper.lightTick();
        if (!context.mounted) return;
        _openAddSim(context);
      },
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text(
        AppLocalizations.of(context)!.addSim,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: isDark ? AppColors.primary : const Color(0xFF00B4D8),
        foregroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      ),
    );
  }

  Widget _buildRefreshAction(BuildContext context) {
    final isDark = context.isDarkMode;
    return IconButton(
      icon: const Icon(Icons.refresh_rounded),
      tooltip: AppLocalizations.of(context)!.refreshSims,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      color: isDark
          ? AppColors.textSecondaryDark
          : AppColors.textSecondaryLight,
      onPressed: () async {
        await HapticHelper.mediumImpact();
        ref.invalidate(simLinesControllerProvider);
        ref.invalidate(householdControllerProvider);
        await HapticHelper.successFeedback();
      },
    );
  }

  Widget _buildTabItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    required int count,
  }) {
    final isDark = context.isDarkMode;
    final isSelected = _tabController.index == index;

    final selectedBadgeBg = isDark
        ? AppColors.primary.withValues(alpha: 0.2)
        : const Color(0xFFE0F7FA);
    final selectedBadgeText = isDark
        ? AppColors.primary
        : AppColors.lightPrimary;

    final unselectedBadgeBg = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);
    final unselectedBadgeText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Tab(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? selectedBadgeBg : unselectedBadgeBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? selectedBadgeText : unselectedBadgeText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearSearchAndFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedFilter = SimLinesListFilter.all;
    });
  }

  Widget _buildNoResultsState(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await HapticHelper.mediumImpact();
        ref.invalidate(simLinesControllerProvider);
        ref.invalidate(scheduledTopupControllerProvider);
        ref.invalidate(householdControllerProvider);
        await HapticHelper.successFeedback();
      },
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 64,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noMatchingSims,
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.tryDifferentSimSearch,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _clearSearchAndFilters,
                      child: Text(
                        l10n.clearSearchAndFilters,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.primary
                              : AppColors.lightPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyStateView(
      icon: Icons.sim_card_outlined,
      title: AppLocalizations.of(context)!.noProtectedLines,
      description: AppLocalizations.of(context)!.noInternationalSimsAdded,
      buttonText: AppLocalizations.of(context)!.protectNewLine,
      onButtonPressed: () async {
        await HapticHelper.lightTick();
        if (!context.mounted) return;
        _openAddSim(context);
      },
    );
  }

  Widget _buildSharedEmptyState(BuildContext context) {
    return EmptyStateView(
      icon: Icons.people_outline,
      title: AppLocalizations.of(context)!.noSharedSimsYet,
      description: AppLocalizations.of(context)!.inviteFamilyMembers,
      buttonText: AppLocalizations.of(context)!.manageHousehold,
      onButtonPressed: () async {
        await HapticHelper.lightTick();
        if (!context.mounted) return;
        context.push('/household');
      },
    );
  }

  Widget _buildLinesList(
    BuildContext context,
    List<SimLine> lines,
    List<Country> countries,
    String? currentUserId,
    HouseholdState? householdState, {
    required bool isShared,
  }) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await HapticHelper.mediumImpact();
        ref.invalidate(simLinesControllerProvider);
        ref.invalidate(scheduledTopupControllerProvider);
        ref.invalidate(householdControllerProvider);
        await HapticHelper.successFeedback();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final country = countries.isEmpty
              ? null
              : countries.firstWhereOrNull((c) => c.id == line.countryId);

          // Resolve carrier from the carriers list for this line's country.
          final carriersAsync = line.countryId != null
              ? ref.watch(carriersForCountryProvider(line.countryId!))
              : null;
          final allCarriers = carriersAsync?.value ?? <Carrier>[];
          final carrier = allCarriers.firstWhereOrNull(
            (c) => c.id == line.carrierId,
          );

          final isSelected = _selectedIds.contains(line.id);

          return SimLineCard(
            line: line,
            index: index,
            country: country,
            carrier: carrier,
            isShared: isShared,
            isSelected: isSelected,
            isSelectMode: _isSelectMode,
            householdState: householdState,
            onTap: () async {
              if (_isSelectMode) {
                setState(() {
                  if (isSelected) {
                    _selectedIds.remove(line.id);
                    if (_selectedIds.isEmpty) {
                      _isSelectMode = false;
                    }
                  } else {
                    _selectedIds.add(line.id);
                  }
                });
              } else {
                context.push('/sim-lines/detail/${line.id}');
              }
            },
            onLongPress: () async {
              if (!_isSelectMode) {
                setState(() {
                  _isSelectMode = true;
                  _selectedIds.add(line.id);
                });
              }
            },
          );
        },
      ),
    );
  }

  /// I2: the only line cap in this product is **one free line per account**.
  ///
  /// This method used to cap the *total* number of lines by the account-level
  /// `profiles.subscription_tier`: `basic` → 1 line, `standard` → 5 lines. That
  /// contradicted the actual rule enforced by the database
  /// (`check_free_lines_limit()`, which caps only `plan_type = 'free'`), and it
  /// was a hard block on revenue: 6 of 8 production accounts are `basic`, so
  /// they could not add a *paid* second line at all, and the sheet quoted
  /// per-line prices ("\$0.10/mo", "max 5") that exist nowhere in
  /// `system_configs` or `quote_plan_price`.
  ///
  /// The free cap is not enforced here on purpose: the add form disables the
  /// Free tier when one already exists, and the database refuses a second one
  /// regardless. Duplicating the rule in a third place is how the three copies
  /// drifted apart in the first place.
  Future<void> _openAddSim(BuildContext context) async {
    await context.push('/sim-lines/add');
    if (mounted) {
      ref.invalidate(simLinesControllerProvider);
      ref.invalidate(scheduledTopupControllerProvider);
      // Auto-poll after 2.5s and 5.5s to seamlessly catch server worker refill completion
      Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          ref.invalidate(simLinesControllerProvider);
          ref.invalidate(scheduledTopupControllerProvider);
        }
      });
      Timer(const Duration(milliseconds: 5500), () {
        if (mounted) {
          ref.invalidate(simLinesControllerProvider);
          ref.invalidate(scheduledTopupControllerProvider);
        }
      });
    }
  }
}
