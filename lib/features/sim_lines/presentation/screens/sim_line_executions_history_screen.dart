import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/widgets/glass_card.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_line_detail_controller.dart';

class SimLineExecutionsHistoryScreen extends ConsumerStatefulWidget {
  final String simLineId;

  const SimLineExecutionsHistoryScreen({super.key, required this.simLineId});

  @override
  ConsumerState<SimLineExecutionsHistoryScreen> createState() =>
      _SimLineExecutionsHistoryScreenState();
}

class _SimLineExecutionsHistoryScreenState
    extends ConsumerState<SimLineExecutionsHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isViewer = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref
          .read(simLineExecutionsHistoryProvider(widget.simLineId).notifier)
          .loadNextPage();
    }
  }

  Future<void> _handleRetryFailedTopup(
    BuildContext context,
    String executionId,
  ) async {
    try {
      await HapticHelper.mediumImpact();
      final detailController = ref.read(
        simLineDetailControllerProvider(widget.simLineId).notifier,
      );
      final res = await detailController.retryFailedTopup(executionId);

      if (context.mounted) {
        switch (res) {
          case Success():
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Top-up retry successfully triggered.'),
                backgroundColor: AppColors.success,
              ),
            );
            // Refresh paginated list
            ref.invalidate(simLineExecutionsHistoryProvider(widget.simLineId));
          case Failure(error: final err):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Retry failed: ${err.message}'),
                backgroundColor: AppColors.error,
              ),
            );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry execution error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Determine viewer status and premium status from details provider
    final detailAsync = ref.watch(
      simLineDetailControllerProvider(widget.simLineId),
    );
    final detailState = detailAsync.value;
    final householdState = ref.watch(householdControllerProvider).value;

    if (detailState != null) {
      final user = ref.watch(authControllerProvider).value;
      final isShared = detailState.simLine.userId != user?.id;
      final membership = isShared
          ? householdState?.memberships
                .where((m) => m.ownerId == detailState.simLine.userId)
                .firstOrNull
          : null;
      _isViewer =
          isShared && (membership == null || membership.role == 'viewer');
    }

    final stateAsync = ref.watch(
      simLineExecutionsHistoryProvider(widget.simLineId),
    );
    final notifier = ref.read(
      simLineExecutionsHistoryProvider(widget.simLineId).notifier,
    );
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Executions History',
          style: AppTextStyles.headlineSmall.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.onSurfaceColor,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: stateAsync.when(
        data: (executions) {
          if (executions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Execution History',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No top-up or renewal executions have been recorded for this SIM line yet.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(
                simLineExecutionsHistoryProvider(widget.simLineId),
              );
              await ref.read(
                simLineExecutionsHistoryProvider(widget.simLineId).future,
              );
            },
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: executions.length + (notifier.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == executions.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }

                final ex = executions[index];
                final isSuccess = ex.status == 'success';
                final targetDate = ex.executedAt ?? ex.executionTime ?? ex.createdAt ?? DateTime.now();
                final dateStr = DateFormat(
                  'MMM dd, yyyy HH:mm',
                ).format(targetDate);

                return GlassCard(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              (isSuccess ? AppColors.success : AppColors.error)
                                  .withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSuccess
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: isSuccess
                              ? AppColors.success
                              : AppColors.error,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Detail info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '\$${ex.amount.toStringAsFixed(2)} ${ex.currency}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: context.onSurfaceColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isSuccess
                                                ? AppColors.success
                                                : AppColors.error)
                                            .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    ex.status.toUpperCase(),
                                    style: TextStyle(
                                      color: isSuccess
                                          ? AppColors.success
                                          : AppColors.error,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: AppTextStyles.caption.copyWith(
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                            if (ex.reloadlyTransactionId != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Tx ID: ${ex.reloadlyTransactionId}',
                                style: AppTextStyles.caption.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                            if (!isSuccess && ex.failureReason != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.error.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Reason: ${ex.failureReason}',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.error,
                                      ),
                                    ),
                                    if (!_isViewer) ...[
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 28,
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _handleRetryFailedTopup(
                                                context,
                                                ex.id,
                                              ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.error,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: const Text(
                                            'Retry Now',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 54,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load history',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: context.onSurfaceColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => ref.invalidate(
                    simLineExecutionsHistoryProvider(widget.simLineId),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
