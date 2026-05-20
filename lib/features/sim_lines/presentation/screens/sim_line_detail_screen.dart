import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_activity_log_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_line_detail_controller.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/scheduled_topups/model/topup_execution_model.dart';
import 'package:keep_sims/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/number_verification_dialog.dart';

class SimLineDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const SimLineDetailScreen({super.key, required this.id});

  @override
  ConsumerState<SimLineDetailScreen> createState() => _SimLineDetailScreenState();
}

class _SimLineDetailScreenState extends ConsumerState<SimLineDetailScreen> {
  bool _isOptimizing = false;
  bool _isToggling = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(simLineDetailControllerProvider(widget.id));
    final countriesState = ref.watch(supportedCountriesProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimaryDark, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Protection Console',
          style: AppTextStyles.headlineMedium.copyWith(color: AppColors.textPrimaryDark),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondaryDark),
            onPressed: () {
              ref.invalidate(simLineDetailControllerProvider(widget.id));
            },
          ),
        ],
      ),
      body: detailAsync.when(
        data: (detailState) {
          final countries = countriesState.valueOrNull ?? [];
          final country = countries.isEmpty
              ? null
              : countries.firstWhere((c) => c.id == detailState.simLine.countryId, orElse: () => countries.first);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Line Header Card
                _buildHeaderCard(context, detailState.simLine, country),
                const SizedBox(height: 20),

                // 2. Health & Optimization Ring Panel
                _buildHealthScoreSection(context, detailState),
                const SizedBox(height: 20),

                // 3. Auto-Refill Configuration Panel
                _buildAutoRefillSection(context, detailState),
                const SizedBox(height: 20),

                // 4. Historical Refill Executions
                _buildExecutionsSection(context, detailState),
                const SizedBox(height: 20),

                // 5. Activity Event Timeline Logs
                _buildTimelineSection(context, detailState),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 54),
                const SizedBox(height: 16),
                Text(
                  'Failed to load details',
                  style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimaryDark),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(simLineDetailControllerProvider(widget.id)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Retry Connection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. Header Card UI ──────────────────────────────────────────────────────
  Widget _buildHeaderCard(BuildContext context, SimLine line, dynamic country) {
    String flag = '🌐';
    if (country != null) {
      flag = country.flagEmoji as String;
    }

    IconData getIcon(String iconStr) {
      switch (iconStr) {
        case 'phone':
          return Icons.phone_android;
        case 'person':
          return Icons.person;
        case 'home':
          return Icons.home_outlined;
        default:
          return Icons.sim_card;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.darkCardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.darkBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar Icon & Country Flag overlay
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Icon(
                  getIcon(line.avatarIcon),
                  color: AppColors.primaryLight,
                  size: 28,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.darkSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Text(flag, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Info Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        line.nickname ?? 'My SIM Card',
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: AppColors.textPrimaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTierBadge(line.protectionTier),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  line.phoneNumber,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondaryDark,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (country != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    country.name as String,
                    style: AppTextStyles.caption.copyWith(color: AppColors.primaryLight),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierBadge(String tier) {
    Color getTierColor() {
      switch (tier.toLowerCase()) {
        case 'premium':
          return const Color(0xFFF59E0B);
        case 'standard':
          return AppColors.primary;
        default:
          return Colors.grey;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: getTierColor().withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: getTierColor().withOpacity(0.3), width: 1),
      ),
      child: Text(
        tier.toUpperCase(),
        style: TextStyle(
          color: getTierColor(),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── 2. Health & Circular score UI ──────────────────────────────────────────
  Widget _buildHealthScoreSection(BuildContext context, SimLineDetailState detail) {
    final score = detail.simLine.healthScore;
    Color scoreColor = AppColors.healthGreen;
    String rating = 'SECURE';
    String description = 'Your SIM card has active automated refill protection configured.';

    if (score < 30) {
      scoreColor = AppColors.healthRed;
      rating = 'CRITICAL RISK';
      description = 'Refill schedule is disabled or missing. Enable auto-renewal immediately to prevent card expiry!';
    } else if (score < 60) {
      scoreColor = AppColors.healthAmber;
      rating = 'WARNING';
      description = 'Last renewal attempt failed, or renewal due soon. Refill to restore score.';
    } else if (score < 100) {
      scoreColor = AppColors.healthGreen;
      rating = 'PROTECTED';
      description = 'Auto-renewal schedule is active, but you can optimize to 100 with a successful top-up.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Circular Glowing Progress
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 7,
                      backgroundColor: AppColors.darkCard,
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                    Text(
                      '$score',
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Descriptive Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shield Health Score',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textTertiaryDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rating,
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (detail.scheduledTopup != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(color: AppColors.darkBorder, height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Simulate a successful E2E refill to test flows & restore health instantly.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryDark),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: _isOptimizing ? null : () => _handleSimulateExecution(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      disabledBackgroundColor: AppColors.darkBorder,
                    ),
                    child: _isOptimizing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Optimize',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(color: AppColors.darkBorder, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verify Live Line Activity',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Test if your SIM line is reachable via Twilio Missed Call check.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: () => _handleVerifyLineActivity(context, detail.simLine),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.radar, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Verify',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. Auto-Refill Schedule UI ─────────────────────────────────────────────
  Widget _buildAutoRefillSection(BuildContext context, SimLineDetailState detail) {
    final schedule = detail.scheduledTopup;

    if (schedule == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.healthRed.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.healthRed.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.healthRed, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Auto-Refill: Disabled',
                  style: AppTextStyles.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your SIM card has no active automatic renewal schedule. SIM card will expire and get permanently deactivated if not recharged on time.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openScheduleSheet(context, detail.simLine),
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text('Configure Auto-Renewal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('MMM dd, yyyy');
    String getDueStr() {
      return dateFormat.format(schedule.nextExecutionAt);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Auto-Renewal Schedule',
                style: AppTextStyles.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (schedule.isActive ? AppColors.secondary : AppColors.warning).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: (schedule.isActive ? AppColors.secondary : AppColors.warning).withOpacity(0.3)),
                    ),
                    child: Text(
                      schedule.isActive ? 'ACTIVE' : 'PAUSED',
                      style: TextStyle(
                        color: schedule.isActive ? AppColors.secondary : AppColors.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: schedule.isActive,
                    activeColor: AppColors.secondary,
                    onChanged: _isToggling ? null : (val) => _handleToggleSchedule(context, schedule.id, val),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildScheduleRowItem(
            'Recharge Amount',
            '\$${schedule.amount.toStringAsFixed(2)} ${schedule.currency}',
            Icons.monetization_on_outlined,
          ),
          const SizedBox(height: 12),
          _buildScheduleRowItem(
            'Renewal Interval',
            'Every ${schedule.frequencyDays} days',
            Icons.repeat,
          ),
          const SizedBox(height: 12),
          _buildScheduleRowItem(
            'Next Refill Due',
            getDueStr(),
            Icons.date_range,
          ),
          if (schedule.retryCount > 0) ...[
            const SizedBox(height: 12),
            _buildScheduleRowItem(
              'Failed Refill Attempts',
              '${schedule.retryCount} / 4 retries',
              Icons.warning_amber_rounded,
              valueColor: AppColors.healthRed,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14.0),
            child: Divider(color: AppColors.darkBorder, height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openScheduleSheet(context, detail.simLine),
                  icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textPrimaryDark),
                  label: const Text('Edit Schedule', style: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppColors.darkBorder),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: () => _showDeleteScheduleConfirmation(context, schedule.id),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withOpacity(0.08),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.error.withOpacity(0.2)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleRowItem(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiaryDark),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark)),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: valueColor ?? AppColors.textPrimaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── 4. Refill Executions History ───────────────────────────────────────────
  Widget _buildExecutionsSection(BuildContext context, SimLineDetailState detail) {
    final list = detail.executions;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Refill Executions History',
            style: AppTextStyles.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'No historical top-up executions recorded for this line yet.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (context, index) => const Divider(color: AppColors.darkBorder, height: 16),
              itemBuilder: (context, index) {
                final ex = list[index];
                final isSuccess = ex.status == 'success';
                final dateStr = DateFormat('MMM dd, yyyy HH:mm').format(ex.executedAt);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isSuccess ? AppColors.success : AppColors.error).withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                        color: isSuccess ? AppColors.success : AppColors.error,
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isSuccess ? AppColors.success : AppColors.error).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ex.status.toUpperCase(),
                                  style: TextStyle(
                                    color: isSuccess ? AppColors.success : AppColors.error,
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
                            style: AppTextStyles.caption.copyWith(color: AppColors.textTertiaryDark),
                          ),
                          if (ex.reloadlyTransactionId != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Tx ID: ${ex.reloadlyTransactionId}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondaryDark,
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
                                color: AppColors.error.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.error.withOpacity(0.15)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reason: ${ex.failureReason}',
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 28,
                                    child: ElevatedButton(
                                      onPressed: () => _handleRetryFailedTopup(context, ex.id),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.error,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: const Text('Retry Now', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Actions
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.textTertiaryDark, size: 20),
                      onPressed: () => _handleDeleteExecution(context, ex.id),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ── 5. Activity Logs Timeline UI ───────────────────────────────────────────
  Widget _buildTimelineSection(BuildContext context, SimLineDetailState detail) {
    final list = detail.activityLogs;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Security Activity Logs',
                style: AppTextStyles.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              if (list.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _handleCleanMockLogs(context),
                  icon: const Icon(Icons.cleaning_services, size: 14, color: AppColors.primaryLight),
                  label: const Text('Clean Mock Logs', style: TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'No activity logs recorded for this line yet.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final log = list[index];
                final isLast = index == list.length - 1;

                Color iconColor = AppColors.primaryLight;
                IconData iconData = Icons.info_outline;

                if (log.eventType == 'topup_success') {
                  iconColor = AppColors.success;
                  iconData = Icons.check_circle_outline;
                } else if (log.eventType == 'topup_failed') {
                  iconColor = AppColors.error;
                  iconData = Icons.error_outline;
                } else if (log.eventType == 'health_update') {
                  iconColor = AppColors.secondary;
                  iconData = Icons.shield_outlined;
                } else if (log.eventType == 'created') {
                  iconColor = AppColors.primary;
                  iconData = Icons.add_box_outlined;
                }

                final dateStr = DateFormat('MMM dd, yyyy HH:mm').format(log.createdAt);

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Timeline connecting indicators
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.08),
                              shape: BoxShape.circle,
                              border: Border.all(color: iconColor.withOpacity(0.2)),
                            ),
                            child: Icon(iconData, color: iconColor, size: 16),
                          ),
                          Expanded(
                            child: isLast
                                ? const SizedBox(height: 20)
                                : Container(
                                    width: 2,
                                    color: AppColors.darkBorder,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Text Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.description ?? '',
                              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, height: 1.3),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiaryDark),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      // Actions
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.textTertiaryDark, size: 18),
                          onPressed: () => _handleDeleteActivityLog(context, log.id),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Action Handlers ────────────────────────────────────────────────────────
  void _openScheduleSheet(BuildContext context, SimLine line) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduledTopupSheet(
        simLineId: line.id,
        simNickname: line.nickname ?? line.phoneNumber,
      ),
    );
  }

  Future<void> _handleToggleSchedule(BuildContext context, String scheduleId, bool isActive) async {
    setState(() {
      _isToggling = true;
    });

    try {
      final result = await ref.read(scheduledTopupControllerProvider.notifier).toggleActive(scheduleId, isActive);
      if (result is Success<ScheduledTopup>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-Renewal successfully ${isActive ? 'enabled' : 'paused'}.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else if (result is Failure<ScheduledTopup>) {
        throw Exception((result as Failure<ScheduledTopup>).error.message);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update schedule: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isToggling = false;
        });
      }
    }
  }

  void _showDeleteScheduleConfirmation(BuildContext context, String scheduleId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Text(
              'Remove Schedule',
              style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this auto-refill schedule? Your SIM health score will drop significantly, risking deactivation.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondaryDark)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final result = await ref.read(scheduledTopupControllerProvider.notifier).removeSchedule(scheduleId);
                if (result is Success<void>) {
                  ref.invalidate(simLineDetailControllerProvider(widget.id));
                  ref.invalidate(simLinesControllerProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Auto-renewal schedule removed successfully.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } else if (result is Failure<void>) {
                  throw Exception((result as Failure<void>).error.message);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete schedule: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSimulateExecution(BuildContext context) async {
    setState(() {
      _isOptimizing = true;
    });

    try {
      final result = await ref.read(simLineDetailControllerProvider(widget.id).notifier).triggerRefill();
      if (mounted) {
        if (result is Success<void>) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Simulated auto-refill executed successfully! Wallet balance deducted & health restored.'),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (result is Failure<void>) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Refill failed: ${(result as Failure<void>).error.message}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Simulation error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOptimizing = false;
        });
      }
    }
  }

  Future<void> _handleRetryFailedTopup(BuildContext context, String executionId) async {
    try {
      final result = await ref.read(simLineDetailControllerProvider(widget.id).notifier).retryFailedTopup(executionId);
      if (mounted) {
        if (result is Success<void>) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Refill retry completed successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (result is Failure<void>) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Retry failed: ${(result as Failure<void>).error.message}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry execution error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteExecution(BuildContext context, String executionId) async {
    try {
      await ref.read(simLineDetailControllerProvider(widget.id).notifier).deleteExecution(executionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Execution record deleted.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete execution record: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteActivityLog(BuildContext context, String logId) async {
    try {
      await ref.read(simLineDetailControllerProvider(widget.id).notifier).deleteActivityLog(logId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity log entry deleted.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete activity log: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleCleanMockLogs(BuildContext context) async {
    try {
      await ref.read(simLineDetailControllerProvider(widget.id).notifier).cleanMockLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mock historical records cleaned successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clean mock records: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _handleVerifyLineActivity(BuildContext context, SimLine simLine) {
    HapticHelper.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NumberVerificationDialog(
        simLineId: simLine.id,
        phoneNumber: simLine.phoneNumber,
      ),
    );
  }
}
