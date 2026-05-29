import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/sim_line_card.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/core/widgets/shimmer_loading.dart';
import 'package:keep_sims/core/widgets/empty_state.dart';
import 'package:keep_sims/core/widgets/error_state.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/profile/presentation/widgets/subscription_upsell_sheet.dart';

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

  @override
  void initState() {
    super.initState();
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
    _tabController.dispose();
    super.dispose();
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

  Future<void> _bulkSimulateRefill(
    List<SimLine> selectedLines,
    List<ScheduledTopup> schedules,
  ) async {
    setState(() => _isBulkActionLoading = true);
    int successCount = 0;
    int failCount = 0;
    String? errorMessage;

    for (final line in selectedLines) {
      final schedule = schedules.firstWhereOrNull(
        (s) => s.simLineId == line.id,
      );
      if (schedule != null) {
        if (schedule.isActive) {
          final res = await ref
              .read(scheduledTopupControllerProvider.notifier)
              .executeMockTopup(schedule.id);
          if (res is Success) {
            successCount++;
          } else {
            failCount++;
            if (res is Failure) {
              errorMessage = (res as Failure).error.message;
            }
          }
        } else {
          failCount++;
        }
      } else {
        failCount++;
      }
    }

    if (mounted) {
      if (successCount > 0) {
        ref.invalidate(simLinesControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully simulated auto-refill for $successCount SIM card(s)! Balance deducted & validity extended.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
      if (failCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to simulate auto-refill for $failCount SIM(s).${errorMessage != null ? ' Last error: $errorMessage' : ' Ensure schedules are configured & active.'}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
    final schedules =
        ref.read(scheduledTopupControllerProvider).valueOrNull ?? [];

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.15),
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
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count Selected',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Bulk Actions Console',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondaryDark,
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
                      label: 'Resume',
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
                      label: 'Pause',
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildConsoleButton(
                      label: 'Simulate',
                      icon: Icons.flash_on_rounded,
                      color: AppColors.success,
                      onPressed: _isBulkActionLoading || count == 0
                          ? null
                          : () => _bulkSimulateRefill(selectedLines, schedules),
                    ),
                  ),
                ],
              ),
              if (_isBulkActionLoading) ...[
                const SizedBox(height: 12),
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                  child: LinearProgressIndicator(
                    color: AppColors.primary,
                    backgroundColor: AppColors.darkBg,
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
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3), width: 1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final simLinesState = ref.watch(simLinesControllerProvider);
    final countriesState = ref.watch(supportedCountriesProvider);
    final householdState = ref.watch(householdControllerProvider).valueOrNull;

    final simLines = simLinesState.valueOrNull ?? [];
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;
    final myLines = simLines
        .where((line) => line.userId == currentUserId)
        .toList();
    final sharedLines = simLines
        .where((line) => line.userId != currentUserId)
        .toList();
    final visibleLines = _tabController.index == 0 ? myLines : sharedLines;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        leading: _isSelectMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSelectMode = false;
                    _selectedIds.clear();
                  });
                },
              )
            : null,
        title: Text(
          _isSelectMode ? '${_selectedIds.length} Selected' : 'Protected SIMs',
          style: AppTextStyles.headlineLarge.copyWith(
            color: AppColors.textPrimaryDark,
          ),
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
                color: Colors.white,
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
          else
            IconButton(
              icon: const Icon(
                Icons.refresh,
                color: AppColors.textSecondaryDark,
              ),
              onPressed: () async {
                await HapticHelper.mediumImpact();
                ref.invalidate(simLinesControllerProvider);
                ref.invalidate(householdControllerProvider);
                await HapticHelper.successFeedback();
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondaryDark,
          tabs: const [
            Tab(icon: Icon(Icons.person, size: 20), text: 'My SIM Cards'),
            Tab(icon: Icon(Icons.people, size: 20), text: 'Family Shared SIMs'),
          ],
        ),
      ),
      body: simLinesState.when(
        data: (lines) {
          final currentUserId = ref
              .watch(authControllerProvider)
              .valueOrNull
              ?.id;
          final myLines = lines
              .where((line) => line.userId == currentUserId)
              .toList();
          final sharedLines = lines
              .where((line) => line.userId != currentUserId)
              .toList();

          return Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: My SIM Cards
                  myLines.isEmpty
                      ? _buildEmptyState(context, myLines.length)
                      : _buildLinesList(
                          context,
                          myLines,
                          countriesState.valueOrNull ?? [],
                          currentUserId,
                          householdState,
                          isShared: false,
                        ),

                  // Tab 2: Family Shared SIMs
                  sharedLines.isEmpty
                      ? _buildSharedEmptyState(context)
                      : _buildLinesList(
                          context,
                          sharedLines,
                          countriesState.valueOrNull ?? [],
                          currentUserId,
                          householdState,
                          isShared: true,
                        ),
                ],
              ),
              _buildBulkActionsConsole(myLines),
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

  Widget _buildEmptyState(BuildContext context, int myLinesCount) {
    return EmptyStateView(
      icon: Icons.sim_card_outlined,
      title: 'No Protected Lines',
      description:
          'You don\'t have any international SIM cards added yet. Protect your first card now to keep it active forever.',
      buttonText: 'Protect New Line',
      onButtonPressed: () async {
        await HapticHelper.lightTick();
        _checkLineLimitAndAdd(context, myLinesCount);
      },
    );
  }

  Widget _buildSharedEmptyState(BuildContext context) {
    return EmptyStateView(
      icon: Icons.people_outline,
      title: 'No Shared SIMs yet',
      description:
          'Invite family members to join your Household. Once they accept, their protected SIM lines will appear here for collaborative monitoring.',
      buttonText: 'Manage Household',
      onButtonPressed: () async {
        await HapticHelper.lightTick();
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
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: isShared ? lines.length : lines.length + 1,
      itemBuilder: (context, index) {
        if (!isShared && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildAddHeaderCard(context, lines.length),
          );
        }

        final line = lines[isShared ? index : index - 1];
        final country = countries.isEmpty
            ? null
            : countries.firstWhereOrNull((c) => c.id == line.countryId);

        final isSelected = _selectedIds.contains(line.id);

        return SimLineCard(
          line: line,
          index: isShared ? index : index - 1,
          country: country,
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
    );
  }

  Widget _buildAddHeaderCard(BuildContext context, int myLinesCount) {
    return InkWell(
      onTap: () async {
        await HapticHelper.lightTick();
        _checkLineLimitAndAdd(context, myLinesCount);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.white, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Protect Another SIM Line',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Keep infinite international numbers alive',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  void _checkLineLimitAndAdd(BuildContext context, int myLinesCount) {
    final user = ref.read(authControllerProvider).valueOrNull;
    final tier = user?.subscriptionTier ?? 'standard';

    if (tier == 'basic' && myLinesCount >= 1) {
      SubscriptionUpsellSheet.show(
        context: context,
        title: 'Free Plan Limit Reached 🚨',
        description: 'Under the Free Plan, you can protect up to 1 SIM line. Upgrade to Starter or Premium to keep more active international numbers protected simultaneously!',
        requiredPlan: 'Starter Plan',
        highlights: [
          'Protect up to 5 SIM lines simultaneously',
          'Unlock WhatsApp, Telegram & Email notifications',
          'Enable Travel & Home automated renewal modes',
        ],
      );
      return;
    } else if (tier == 'standard' && myLinesCount >= 5) {
      SubscriptionUpsellSheet.show(
        context: context,
        title: 'Starter Plan Limit Reached 🚨',
        description: 'You have reached the 5 SIM card limit for the Starter Plan. Go Premium to unlock unlimited active protection shields!',
        requiredPlan: 'Premium Shield',
        highlights: [
          'Protect UNLIMITED SIM lines simultaneously',
          'Unlock 100% automated in-app balance top-ups',
          'Smart Geolocation deactivation freeze shields',
          'Baqa local calls + data operator detection',
        ],
      );
      return;
    }

    context.push('/sim-lines/add');
  }
}
