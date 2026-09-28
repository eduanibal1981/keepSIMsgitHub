import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/features/scheduled_topups/ui/widgets/refill_price_approval_dialog.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:keep_sims/core/services/destructive_action_guard.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/domain/sim_line_health.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_line_detail_controller.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/scheduled_topups/model/topup_execution_model.dart';
import 'package:keep_sims/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/number_verification_dialog.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/manual_refill_bottom_sheet.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/manual_recharge_dialog.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/premium_refill_config_sheet.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/depletion_forecast_card.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/alert_clock_card.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/sim_insurance_bottom_sheet.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/sim_health_score_sheet.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/rescue_policy_provider.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/usage_forecast_provider.dart';
import 'package:keep_sims/features/home_widget/presentation/live_activity_pin_button.dart';
import 'package:keep_sims/features/return_trip/domain/entities/active_return_trip_info.dart';
import 'package:keep_sims/features/return_trip/presentation/controllers/active_return_trip_provider.dart';
import 'package:keep_sims/features/return_trip/presentation/widgets/active_return_package_bottom_sheet.dart';
import 'package:keep_sims/features/return_trip/presentation/widgets/manage_return_trip_bottom_sheet.dart';
import 'package:keep_sims/features/geo/controller/geo_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class SimLineDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const SimLineDetailScreen({super.key, required this.id});

  @override
  ConsumerState<SimLineDetailScreen> createState() =>
      _SimLineDetailScreenState();
}

class _SimLineDetailScreenState extends ConsumerState<SimLineDetailScreen> {
  late bool _isShared;
  late bool _isViewer;
  dynamic _membership;

  /// Executions already seen in a terminal state, so re-emissions of the same
  /// row (realtime replays the whole matching set on every change) don't
  /// re-trigger the refresh.
  final Set<String> _settledExecutions = {};

  static const _terminalStatuses = {'success', 'failed', 'refunded'};

  /// Refresh the wallet and the activity log the moment the worker finishes an
  /// execution, rather than guessing at how long its round trip takes.
  void _watchExecutionStatus() {
    ref.listen(topupExecutionsLiveProvider(widget.id), (previous, next) {
      final rows = next.value;
      if (rows == null) return;

      for (final exec in rows) {
        if (!_terminalStatuses.contains(exec.status)) continue;
        if (!_settledExecutions.add(exec.id)) continue;

        ref.invalidate(walletControllerProvider);
        ref.invalidate(simLineActivityLogsProvider(widget.id));
        ref.invalidate(topupExecutionsForLineProvider(widget.id));
        ref.invalidate(simLinesControllerProvider);
        ref.invalidate(scheduledTopupControllerProvider);
        ref.invalidate(simLineDetailControllerProvider(widget.id));

        if (previous?.value != null && mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          if (exec.status == 'success') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Refill completed successfully! Line validity refreshed.',
                ),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 4),
              ),
            );
          } else if (exec.status == 'failed') {
            final reason = exec.failureReason ?? 'Declined by operator';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Refill failed: $reason'),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 5),
              ),
            );
          } else if (exec.status == 'refunded') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Refill failed and payment was refunded to wallet.',
                ),
                backgroundColor: AppColors.warning,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _watchExecutionStatus();
    final detailAsync = ref.watch(simLineDetailControllerProvider(widget.id));
    final countriesState = ref.watch(supportedCountriesProvider);
    final user = ref.watch(authControllerProvider).value;
    final simLine = detailAsync.value?.simLine;
    final householdState = ref.watch(householdControllerProvider).value;

    _isShared = simLine != null && simLine.userId != user?.id;
    _membership = _isShared
        ? householdState?.memberships.firstWhereOrNull(
            (m) => m.ownerId == simLine!.userId,
          )
        : null;
    _isViewer =
        _isShared && (_membership == null || _membership.role == 'viewer');

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: context.onSurfaceColor,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppLocalizations.of(context)!.protectionConsole,
          style: AppTextStyles.headlineMedium.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: context.onSurfaceColor),
            tooltip: 'More options',
            onPressed: () => _showMoreOptionsMenu(context, simLine, user),
          ),
        ],
      ),
      body: () {
        final detailState = detailAsync.value;
        if (detailState != null) {
          final countries = countriesState.value ?? [];
          final country = countries.isEmpty
              ? null
              : countries.firstWhere(
                  (c) => c.id == detailState.simLine.countryId,
                  orElse: () => countries.first,
                );

          final isPremium =
              detailState.simLine.protectionTier.toLowerCase() == 'premium';
          final line = detailState.simLine;
          final isKeepAliveActive = detailState.miniRefillSchedule != null &&
              detailState.miniRefillSchedule!.status == 'active' &&
              detailState.miniRefillSchedule!.isActive;
          final isCustomActive = detailState.customRefillSchedule != null &&
              detailState.customRefillSchedule!.status == 'active' &&
              detailState.customRefillSchedule!.isActive;
          final bool hasActiveAutoRefill = isKeepAliveActive || isCustomActive;
          final activeRefillSchedule = isCustomActive
              ? detailState.customRefillSchedule
              : (isKeepAliveActive ? detailState.miniRefillSchedule : null);
          final bool isNotifyActive = detailState.notifySchedule != null &&
              detailState.notifySchedule!.status == 'active' &&
              detailState.notifySchedule!.isActive;
          final bool isRealLiveVerified = detailState.activityLogs.any((l) =>
                  l.description?.toLowerCase().contains('live verified') == true ||
                  l.description?.toLowerCase().contains('verified active via') == true) ||
              (ref.watch(hasRealLiveVerificationProvider(line.id)).value ?? false);
          final bool isVerified = isRealLiveVerified;
          final carrierRule = line.carrierId != null
              ? ref.watch(carrierRuleProvider(line.carrierId!)).value
              : null;
          final int carrierDays = carrierRule?.inactivityLimitDays ?? 90;
          final int? daysSinceRecharge = line.lastTopupAt != null
              ? DateTime.now().difference(line.lastTopupAt!).inDays
              : null;
          final bool isRechargeOverdue =
              daysSinceRecharge != null && daysSinceRecharge > carrierDays;
          final score = line.displayHealthScore(
            isRealLiveVerified: isRealLiveVerified,
            hasNotificationSchedule: isNotifyActive,
            carrierExpirationDays: carrierDays,
          );

          final String tier = line.protectionTier.toLowerCase();

          final activeTripAsync = ref.watch(
            activeReturnTripInfoProvider(line.id),
          );
          final activeTrip = activeTripAsync.value;

          return Column(
            children: [
              // Fixed Compact Identity Card (pins under AppBar)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _buildCompactIdentityCard(context, line, country),
              ),
              // Single Scrolling Page
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Critical Risk Alert Banner (conditional)
                      if (score < 30) ...[
                        _buildCriticalRiskAlert(
                          context,
                          detailState,
                          isPremium,
                          tier,
                          isVerified,
                          score,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Card 1: Combined Health & Status Overview Card
                      _buildHealthOverviewCard(
                        context,
                        detailState,
                        country,
                        score,
                        line,
                        tier,
                        carrierExpirationDays: carrierRule?.inactivityLimitDays,
                      ),
                      const SizedBox(height: 14),

                      // Card 2: Unified Return Trip Wizard & Next Prepared Travel Data
                      _buildReturnTripWizardCard(
                        context,
                        line,
                        country,
                        activeTrip: activeTrip,
                        hasHistory: (ref.watch(returnTripHistoryProvider(line.id)).value?.isNotEmpty ?? false),
                      ),
                      const SizedBox(height: 18),

                      // Auxiliary Cards: Depletion Forecast vs. Overdue Alert
                      if (line.lastTopupAt != null && isRechargeOverdue) ...[
                        _buildRechargeOverdueAlertCard(
                          context,
                          line,
                          daysSinceRecharge: daysSinceRecharge,
                          carrierDays: carrierDays,
                        ),
                        const SizedBox(height: 18),
                      ] else if (line.lastTopupAt != null && !hasActiveAutoRefill) ...[
                        DepletionForecastCard(
                          line: line,
                          isPremium: isPremium,
                          existingRefillSchedule: activeRefillSchedule,
                          carrierDays: carrierDays,
                        ),
                      ],
                      LiveActivityPinButton(
                        line: line,
                        forecast: ref
                            .watch(usageForecastForLineProvider(line.id))
                            .value,
                      ),
                      const SizedBox(height: 18),

                      // Alert Clock: Authoritative Deactivation Countdown & Status
                      AlertClockCard(
                        simLineId: line.id,
                        onRecordRecharge: () {
                          ManualRechargeDialog.show(context: context, simLine: line);
                        },
                      ),
                      const SizedBox(height: 18),

                      // Section 3: Protection List Card
                      _buildProtectionSection(context, detailState),
                      const SizedBox(height: 18),

                      // Section 4: Quick Actions List Card
                      _buildQuickActionsSection(
                        context,
                        line,
                        country,
                        isPremium,
                        tier,
                        isVerified,
                      ),
                      const SizedBox(height: 18),

                      // Section 5: Security Activity Card
                      _buildSecurityActivitySection(context, detailState),
                      const SizedBox(height: 18),

                      // Footer: Manage SIM link
                      _buildManageSimButton(context, line),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        if (detailAsync.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final err = detailAsync.error ?? Exception('Unknown error');
        return Center(
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
                  AppLocalizations.of(context)!.failedToLoadDetails,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(
                    simLineDetailControllerProvider(widget.id),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.retryConnection,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }(),
    );
  }

  // ── Stitch Google UI Components ──────────────────────────────────────────

  void _showMoreOptionsMenu(
    BuildContext context,
    SimLine? simLine,
    dynamic user,
  ) {
    if (simLine == null) return;
    final isDark = context.isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF182234) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (!_isViewer)
                ListTile(
                  leading: Icon(
                    Icons.wifi_off_rounded,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.offlineRefillLabel,
                    style: TextStyle(color: context.onSurfaceColor),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(
                      '/settings/offline-recharge?simLineId=${simLine.id}',
                    );
                  },
                ),
              if (!_isShared)
                ListTile(
                  leading: Icon(
                    Icons.edit_outlined,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  title: const Text('Edit nickname'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditNicknameDialog(context, simLine);
                  },
                ),
              if (simLine.userId == user?.id)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.deleteProtectionTooltip,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirmation(context, simLine);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactIdentityCard(
    BuildContext context,
    SimLine line,
    dynamic country,
  ) {
    final isDark = context.isDarkMode;
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
          return Icons.sim_card_outlined;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182234) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? null
            : [
                const BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Icon(
                  getIcon(line.avatarIcon),
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  size: 22,
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF182234) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(flag, style: const TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (line.nickname != null && line.nickname!.trim().isNotEmpty)
                      ? line.nickname!.trim()
                      : (AppLocalizations.of(context)?.mySimCardDefault ?? 'My SIM Card'),
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.onSurfaceColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  line.phoneNumber,
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildTierBadge(line.protectionTier, isDark),
        ],
      ),
    );
  }

  Widget _buildTierBadge(String tier, bool isDark) {
    final String normalized = tier.toLowerCase();
    Color bg;
    Color border;
    Color text;
    String label;
    IconData icon;

    if (normalized == 'premium') {
      bg = isDark ? const Color(0xFFD97706).withValues(alpha: 0.2) : const Color(0xFFFEF3C7);
      border = isDark ? const Color(0xFFD97706).withValues(alpha: 0.5) : const Color(0xFFFDE68A);
      text = const Color(0xFFD97706);
      label = 'PREMIUM';
      icon = Icons.workspace_premium_rounded;
    } else if (normalized == 'standard') {
      bg = isDark ? const Color(0xFF0284C7).withValues(alpha: 0.2) : const Color(0xFFF0F9FF);
      border = isDark ? const Color(0xFF0284C7).withValues(alpha: 0.5) : const Color(0xFFBAE6FD);
      text = const Color(0xFF0284C7);
      label = 'STANDARD';
      icon = Icons.verified_rounded;
    } else {
      bg = isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF1F5F9);
      border = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
      text = isDark ? Colors.white70 : const Color(0xFF475569);
      label = 'BASIC';
      icon = Icons.shield_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthOverviewCard(
    BuildContext context,
    SimLineDetailState detail,
    dynamic country,
    int score,
    SimLine line,
    String tier, {
    int? carrierExpirationDays,
  }) {
    final isDark = context.isDarkMode;

    final bool isNotifyActive = detail.notifySchedule != null &&
        detail.notifySchedule!.status == 'active' &&
        detail.notifySchedule!.isActive;
    final bool isRealLiveVerified = detail.activityLogs.any((l) =>
            l.description?.toLowerCase().contains('live verified') == true ||
            l.description?.toLowerCase().contains('verified active via') == true) ||
        (ref.watch(hasRealLiveVerificationProvider(line.id)).value ?? false);

    final pillars = line.healthScoreBreakdown(
      isRealLiveVerified: isRealLiveVerified,
      hasNotificationSchedule: isNotifyActive,
      carrierExpirationDays: carrierExpirationDays,
    );

    Color scoreColor;
    if (score >= 60) {
      scoreColor = AppColors.healthGreen;
    } else if (score >= 30) {
      scoreColor = AppColors.healthAmber;
    } else {
      scoreColor = AppColors.healthRed;
    }

    final healthRing = SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100.0,
            strokeWidth: 4.5,
            backgroundColor: isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  fontSize: 13,
                ),
              ),
              Text(
                'HEALTH',
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final String lastCheckText = line.carrierVerifiedAt != null
        ? 'Last checked ${DateFormat('MMM dd, yyyy · HH:mm').format(line.carrierVerifiedAt!.toLocal())}'
        : 'Not yet verified';

    final String lastRechargeText = line.lastTopupAt != null
        ? DateFormat('MMM dd, yyyy').format(line.lastTopupAt!.toLocal())
        : 'No recharge recorded';

    final bool hasRechargeDate = line.lastTopupAt != null;
    final Color rechargeAlertColor = hasRechargeDate
        ? context.onSurfaceColor
        : AppColors.healthRed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182234) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? null
            : [
                const BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: SIM Health Indicator (Tappable - opens score breakdown sheet)
          InkWell(
            onTap: () {
              HapticHelper.lightTick();
              SimHealthScoreSheet.show(
                context: context,
                line: line,
                pillars: pillars,
                score: score,
                tier: tier,
                countryName: country?.name,
                onVerify: () => _handleVerifyLineActivity(context, line),
                onConfigureNotify: () => _openScheduleSheet(
                  context,
                  line,
                  detail.notifySchedule,
                  'notify',
                ),
                onUpdateRecharge: () {
                  HapticHelper.lightTick();
                  ManualRechargeDialog.show(context: context, simLine: line);
                },
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0C4A6E).withValues(alpha: 0.3)
                          : const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF0284C7),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SIM health',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$score ',
                              style: AppTextStyles.headlineSmall.copyWith(
                                fontWeight: FontWeight.w900,
                                color: context.onSurfaceColor,
                              ),
                            ),
                            Text(
                              '/ 100',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${tier.isEmpty ? 'Standard' : tier.substring(0, 1).toUpperCase() + tier.substring(1)} · ${country?.name ?? 'Standard'}',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  healthRing,
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              color: isDark ? const Color(0xFF263348) : const Color(0xFFF1F5F9),
              height: 1,
              thickness: 1,
            ),
          ),

          // Row 2: Network attached Row
          Builder(
            builder: (context) {
              final bool isAttached = line.isCarrierVerified && line.carrierStatus == 'active';
              final bool isDetached = line.carrierStatus == 'expired' || line.carrierStatus == 'barred';
              final Color dotColor = isAttached
                  ? const Color(0xFF10B981)
                  : (isDetached ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));
              final String statusTitle = isAttached
                  ? 'Network attached'
                  : (isDetached ? 'Network detached' : 'Attachment unverified');

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusTitle,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.onSurfaceColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lastCheckText,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '1 free verification / year',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _handleVerifyLineActivity(context, line),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.3) : const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF0369A1).withValues(alpha: 0.4) : const Color(0xFFBAE6FD),
                        ),
                      ),
                      child: Text(
                        'Verify',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              color: isDark ? const Color(0xFF263348) : const Color(0xFFF1F5F9),
              height: 1,
              thickness: 1,
            ),
          ),

          // Row 3: Last recharge Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: hasRechargeDate
                      ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC))
                      : AppColors.healthRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasRechargeDate
                        ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                        : AppColors.healthRed.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: hasRechargeDate
                      ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
                      : AppColors.healthRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last recharge',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastRechargeText,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: hasRechargeDate ? FontWeight.w600 : FontWeight.w700,
                        color: rechargeAlertColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  HapticHelper.lightTick();
                  ManualRechargeDialog.show(context: context, simLine: line);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    'Update',
                    style: TextStyle(
                      color: context.onSurfaceColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReturnTripWizardCard(
    BuildContext context,
    SimLine line,
    dynamic country, {
    ActiveReturnTripInfo? activeTrip,
    bool hasHistory = false,
  }) {
    final isDark = context.isDarkMode;
    final String countryName = (country != null && country.name != null)
        ? (country.name as String)
        : 'Egypt';
    final String? flagEmoji = (country != null && country.flagEmoji != null)
        ? (country.flagEmoji as String)
        : null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bool isFutureOrToday = activeTrip != null &&
        !DateTime(
          activeTrip.arrivalDate.year,
          activeTrip.arrivalDate.month,
          activeTrip.arrivalDate.day,
        ).isBefore(today);

    final bool hasTripOrHistory = activeTrip != null || hasHistory;

    final geoState = ref.watch(geoControllerProvider);
    final userIso = geoState.currentIsoCode.trim().toUpperCase();

    final lineIso = (country != null && country.isoCode != null)
        ? (country.isoCode as String).trim().toUpperCase()
        : null;

    final bool isUserInCountry = lineIso != null && userIso == lineIso;

    void openManage() {
      HapticHelper.lightTick();
      ManageReturnTripBottomSheet.show(
        context,
        simLineId: line.id,
        countryName: countryName,
        flagEmoji: flagEmoji,
      );
    }

    void openWizard() {
      HapticHelper.lightTick();
      context.push('/sim-lines/${line.id}/return-trip');
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182234) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? null
            : [
                const BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Wizard Header & Action Button
          InkWell(
            onTap: hasTripOrHistory ? openManage : openWizard,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0C4A6E).withValues(alpha: 0.35)
                        : const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Transform.rotate(
                    angle: isUserInCountry ? 0.0 : -0.5,
                    child: Icon(
                      isUserInCountry
                          ? Icons.place_rounded
                          : Icons.flight_takeoff_rounded,
                      color: isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF0284C7),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUserInCountry
                            ? 'You are at $countryName!'
                            : 'Back to $countryName Wizard',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.onSurfaceColor,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isFutureOrToday
                            ? 'Trip prepared · Tap to update arrival date or package'
                            : (isUserInCountry
                                ? 'Do you need a data package?'
                                : (hasHistory
                                    ? 'Tap to prepare data or view past trips'
                                    : 'Set your arrival date & prepare your data')),
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: hasTripOrHistory ? openManage : openWizard,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0284C7).withValues(alpha: 0.18)
                          : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasTripOrHistory ? 'Manage' : 'Start',
                          style: const TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 15,
                          color: Color(0xFF0284C7),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Next Prepared Travel Data (Shown ONLY if prepared is a future or same day of travel)
          if (isFutureOrToday) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: isDark ? const Color(0xFF263348) : const Color(0xFFF1F5F9),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                HapticHelper.lightTick();
                ActiveReturnPackageBottomSheet.show(
                  context,
                  tripInfo: activeTrip,
                  countryName: countryName,
                  flagEmoji: flagEmoji,
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0C241D)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF059669).withValues(alpha: 0.45)
                        : const Color(0xFF86EFAC),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF064E3B) : const Color(0xFF047857),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'next Prepared Travel Data',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeTrip.packageTitle,
                        style: TextStyle(
                          color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF065F46),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'click here',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                            decorationColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProtectionSection(
    BuildContext context,
    SimLineDetailState detail,
  ) {
    final isDark = context.isDarkMode;
    final line = detail.simLine;
    final isPremium = line.protectionTier.toLowerCase() == 'premium';
    final notifySchedule = detail.notifySchedule;
    final miniRefillSchedule = detail.miniRefillSchedule;
    final customSchedule = detail.customRefillSchedule;

    final isNotifyActive = notifySchedule != null && notifySchedule.status == 'active';
    final carrierRule = line.carrierId != null
        ? ref.watch(carrierRuleProvider(line.carrierId!)).value
        : null;
    final String notifySubtitle = notifySchedule != null
        ? 'Every ${notifySchedule.frequencyDays} days'
        : (carrierRule?.inactivityLimitDays != null
            ? 'Carrier rule · ${carrierRule!.inactivityLimitDays} days'
            : 'Not scheduled');
    final isKeepAliveActive = miniRefillSchedule != null && miniRefillSchedule.status == 'active';
    final isCustomConfigured = customSchedule != null;
    final isCustomActive = isCustomConfigured && customSchedule.isActive && customSchedule.status == 'active';
    final insurancePolicy = ref.watch(rescuePolicyForLineProvider(line.id)).value;
    final bool isInsured = insurancePolicy?.isInsured ?? false;

    Widget buildRow({
      required IconData icon,
      required String title,
      required String subtitle,
      String? badgeText,
      Color? badgeColor,
      Color? badgeBg,
      required VoidCallback onTap,
      bool showDivider = true,
    }) {
      return InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.3) : const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.onSurfaceColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (badgeText != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg ?? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor ?? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
            if (showDivider)
              Padding(
                padding: const EdgeInsets.only(left: 64, right: 16),
                child: Divider(
                  color: isDark ? const Color(0xFF263348) : const Color(0xFFF8FAFC),
                  height: 1,
                  thickness: 1,
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'PROTECTION',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF182234) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0),
            ),
            boxShadow: isDark
                ? null
                : [
                    const BoxShadow(
                      color: Color(0x080F172A),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              buildRow(
                icon: Icons.notifications_outlined,
                title: 'Auto-notify',
                subtitle: notifySubtitle,
                badgeText: isNotifyActive ? 'Active' : 'Paused',
                badgeColor: isNotifyActive ? const Color(0xFF10B981) : const Color(0xFFD97706),
                badgeBg: isNotifyActive
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : const Color(0xFFFEF3C7),
                onTap: () => _openScheduleSheet(context, line, notifySchedule, 'notify'),
              ),
              buildRow(
                icon: Icons.sync_rounded,
                title: 'Keep-alive refill',
                subtitle: line.protectionTier.toUpperCase(),
                badgeText: isKeepAliveActive ? 'Active' : 'Off',
                badgeColor: isKeepAliveActive ? const Color(0xFF10B981) : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                badgeBg: isKeepAliveActive
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                onTap: () {
                  if (miniRefillSchedule != null) {
                    if (isPremium) {
                      HapticHelper.mediumImpact();
                      PremiumRefillConfigSheet.show(
                        context: context,
                        simLineId: line.id,
                        simNickname: line.nickname ?? line.phoneNumber,
                      );
                    } else {
                      _openScheduleSheet(
                        context,
                        line,
                        miniRefillSchedule,
                        'refill_mini',
                      );
                    }
                  } else {
                    LineUpgradeSheet.show(context: context, simLine: line);
                  }
                },
              ),
              buildRow(
                icon: Icons.add_circle_outline_rounded,
                title: 'Custom auto-refill',
                subtitle: customSchedule != null ? 'Configured (${customSchedule.frequencyDays}d)' : 'Set up a schedule',
                badgeText: isCustomActive
                    ? 'Active'
                    : (isCustomConfigured ? 'Paused' : 'Off'),
                badgeColor: isCustomActive
                    ? const Color(0xFF10B981)
                    : (isCustomConfigured
                        ? const Color(0xFFD97706)
                        : (isDark ? Colors.white54 : const Color(0xFF64748B))),
                badgeBg: isCustomActive
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : (isCustomConfigured
                          ? (isDark
                                ? const Color(
                                    0xFFD97706,
                                  ).withValues(alpha: 0.15)
                                : const Color(0xFFFEF3C7))
                          : (isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9))),
                showDivider: true,
                onTap: () => _openScheduleSheet(
                  context,
                  line,
                  customSchedule,
                  'refill_custom',
                ),
              ),
              buildRow(
                icon: Icons.health_and_safety_outlined,
                title: 'SIM insurance',
                subtitle: isInsured
                    ? 'Up to \$${insurancePolicy!.maxUsd.toStringAsFixed(2)} per rescue'
                    : 'Off — can lapse if missed',
                badgeText: isInsured ? 'Active' : 'Off',
                badgeColor: isInsured ? const Color(0xFF10B981) : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                badgeBg: isInsured
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                showDivider: false,
                onTap: () {
                  HapticHelper.lightTick();
                  SimInsuranceBottomSheet.show(context: context, line: line);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection(
    BuildContext context,
    SimLine line,
    dynamic country,
    bool isPremium,
    String tier,
    bool isVerified,
  ) {
    final isDark = context.isDarkMode;
    final isBasic = tier.toLowerCase() == 'basic';

    Widget buildRow({
      required IconData icon,
      required Color iconColor,
      required Color iconBg,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      bool showDivider = true,
    }) {
      return InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.onSurfaceColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
            if (showDivider)
              Padding(
                padding: const EdgeInsets.only(left: 64, right: 16),
                child: Divider(
                  color: isDark ? const Color(0xFF263348) : const Color(0xFFF8FAFC),
                  height: 1,
                  thickness: 1,
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'QUICK ACTIONS',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF182234) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0),
            ),
            boxShadow: isDark
                ? null
                : [
                    const BoxShadow(
                      color: Color(0x080F172A),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              buildRow(
                icon: Icons.bolt_rounded,
                iconColor: const Color(0xFFF59E0B),
                iconBg: const Color(0xFFFEF3C7),
                title: 'Manual refill',
                subtitle: 'Recharge from wallet',
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ManualRefillBottomSheet(simLine: line),
                  );
                },
              ),
              buildRow(
                icon: Icons.people_rounded,
                iconColor: const Color(0xFF0284C7),
                iconBg: const Color(0xFFE0F2FE),
                title: 'Recharge from friend',
                subtitle: 'Share a recharge request',
                onTap: () => _showP2PRequestDialog(context, line, isBasic),
              ),
              buildRow(
                icon: Icons.sensors_rounded,
                iconColor: const Color(0xFF10B981),
                iconBg: const Color(0xFFD1FAE5),
                title: 'Test SIM activity',
                subtitle: 'Check reachability',
                onTap: () => _handleVerifyLineActivity(context, line),
              ),
              buildRow(
                icon: Icons.description_outlined,
                iconColor: const Color(0xFFEA580C),
                iconBg: const Color(0xFFFFEDD5),
                title: 'Offline refill',
                subtitle: 'Request offline recharge',
                showDivider: false,
                onTap: () {
                  context.pushNamed(
                    'settingsOfflineRecharge',
                    queryParameters: {'simLineId': line.id},
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityActivitySection(
    BuildContext context,
    SimLineDetailState detail,
  ) {
    final isDark = context.isDarkMode;
    final line = detail.simLine;
    final validLogs = detail.activityLogs.where((log) {
      if (log.metadata['is_mock'] == true ||
          log.metadata['is_mock'] == 'true' ||
          (log.description != null &&
              log.description!.toUpperCase().contains('MOCK'))) {
        return false;
      }
      return true;
    }).toList();

    final latestLog = validLogs.isNotEmpty ? validLogs.first : null;
    final logTitle = latestLog != null
        ? latestLog.getLocalizedDescription(context)
        : 'SIM registered in SIM Shield';
    final logDate = latestLog != null
        ? DateFormat(
            'MMM dd, yyyy · HH:mm',
          ).format(latestLog.createdAt.toLocal())
        : (line.createdAt != null
              ? DateFormat(
                  'MMM dd, yyyy · HH:mm',
                ).format(line.createdAt!.toLocal())
              : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SECURITY ACTIVITY',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              GestureDetector(
                onTap: () => _showAllActivityLogsModal(context, detail),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: Color(0xFF0EA5E9),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => _showAllActivityLogsModal(context, detail),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182234) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      const BoxShadow(
                        color: Color(0x080F172A),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.3) : const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        logTitle,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.onSurfaceColor,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        logDate,
                        style: AppTextStyles.caption.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManageSimButton(BuildContext context, SimLine line) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _showMoreOptionsMenu(
          context,
          line,
          ref.read(authControllerProvider).value,
        ),
        icon: const Icon(
          Icons.settings_outlined,
          size: 16,
          color: Color(0xFF0EA5E9),
        ),
        label: const Text(
          'Manage SIM',
          style: TextStyle(
            color: Color(0xFF0EA5E9),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showAllActivityLogsModal(
    BuildContext context,
    SimLineDetailState detail,
  ) {
    final isDark = context.isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF182234) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildTimelineSection(context, detail),
                    const SizedBox(height: 24),
                    _buildExecutionsSection(context, detail),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRechargeOverdueAlertCard(
    BuildContext context,
    SimLine line, {
    required int daysSinceRecharge,
    required int carrierDays,
  }) {
    final isDark = context.isDarkMode;
    final int daysOverdue = daysSinceRecharge - carrierDays;
    final String headline = daysOverdue <= 0
        ? 'Recharge window expired today'
        : 'Recharge overdue by $daysOverdue ${daysOverdue == 1 ? 'day' : 'days'}';

    final String lastRechargeFormatted = line.lastTopupAt != null
        ? DateFormat('MMM dd, yyyy').format(line.lastTopupAt!.toLocal())
        : 'Unknown';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1215) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.healthRed.withValues(alpha: isDark ? 0.6 : 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.healthRed,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  headline,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.healthRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.healthRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.healthRed.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'EXPIRED',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.healthRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Last recharge: $lastRechargeFormatted ($daysSinceRecharge days ago)',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.healthRed.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This line has exceeded the carrier\'s $carrierDays-day inactivity limit. '
            'Your SIM card is at immediate risk of deactivation or number churn. '
            'Recharge immediately to protect your line.',
            style: AppTextStyles.bodySmall.copyWith(
              color: context.onSurfaceColor.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Divider(
            color: isDark ? const Color(0xFF3F1D22) : const Color(0xFFFEE2E2),
            height: 1,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticHelper.lightTick();
                    ManualRechargeDialog.show(context: context, simLine: line);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.onSurfaceColor,
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFFCBD5E1),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Update date',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    HapticHelper.mediumImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ManualRefillBottomSheet(simLine: line),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.healthRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Recharge now',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalRiskAlert(
    BuildContext context,
    SimLineDetailState detail,
    bool isPremium,
    String tier,
    bool isVerified,
    int score,
  ) {
    if (score >= 30) {
      return const SizedBox.shrink();
    }

    final isDark = context.isDarkMode;
    final line = detail.simLine;

    final fallbackRefillSchedule =
        detail.customRefillSchedule ?? detail.miniRefillSchedule;
    final hasProtectionActive = isPremium
        ? (fallbackRefillSchedule != null &&
              fallbackRefillSchedule.status == 'active')
        : (detail.notifySchedule != null &&
              detail.notifySchedule!.status == 'active');

    final recentRefill =
        line.lastTopupAt != null &&
        DateTime.now().difference(line.lastTopupAt!).inDays <= 80;

    final List<String> missingReasons = [];
    if (!isPremium) {
      if (!hasProtectionActive) {
        missingReasons.add(AppLocalizations.of(context)!.missingAlertsDesc);
      }
    } else {
      if (!hasProtectionActive) {
        missingReasons.add(AppLocalizations.of(context)!.missingAutoRefillDesc);
      }
      if (!isVerified) {
        missingReasons.add(
          AppLocalizations.of(context)!.missingVerificationDesc,
        );
      }
      if (!recentRefill) {
        missingReasons.add(
          AppLocalizations.of(context)!.missingRecentRefillDesc,
        );
      }
    }

    if (missingReasons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.criticalRisk,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.simDeactivationRisk,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...missingReasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showP2PRequestDialog(BuildContext context, SimLine line, bool isBasic) {
    final isDark = context.isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.rechargeFromFriendTitle,
              style: AppTextStyles.headlineSmall.copyWith(
                color: context.onSurfaceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.selectPlatformShare,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 20),
            // WhatsApp Button
            if (!isBasic)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await HapticHelper.lightTick();
                    if (!context.mounted) return;
                    final phone = line.phoneNumber;
                    final templateText = AppLocalizations.of(
                      context,
                    )!.rechargeRequestTemplate(phone);
                    final waUrl =
                        'https://wa.me/?text=${Uri.encodeComponent(templateText)}';
                    final uri = Uri.parse(waUrl);
                    _launchUrlHelper(context, uri, 'WhatsApp');
                  },
                  icon: const Icon(
                    Icons.chat_rounded,
                    color: Color(0xFF25D366),
                    size: 18,
                  ),
                  label: Text(
                    AppLocalizations.of(context)!.requestViaWhatsApp,
                    style: const TextStyle(
                      color: Color(0xFF25D366),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF25D366,
                    ).withValues(alpha: 0.12),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: const Color(0xFF25D366).withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
              )
            else
              // Greyed out WhatsApp for basic
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    HapticHelper.mediumImpact();
                    LineUpgradeSheet.show(context: context, simLine: line);
                  },
                  icon: const Icon(
                    Icons.chat_rounded,
                    color: Colors.grey,
                    size: 18,
                  ),
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${AppLocalizations.of(context)!.requestViaWhatsApp} ',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.amber.shade700,
                        size: 14,
                      ),
                    ],
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // Telegram Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await HapticHelper.lightTick();
                  if (!context.mounted) return;
                  final phone = line.phoneNumber;
                  final templateText = AppLocalizations.of(
                    context,
                  )!.rechargeRequestTemplate(phone);
                  final tgAppUri = Uri.parse(
                    'tg://msg?text=${Uri.encodeComponent(templateText)}',
                  );
                  final tgWebUri = Uri.parse(
                    'https://t.me/share/url?url=https://keepsims.com&text=${Uri.encodeComponent(templateText)}',
                  );
                  _launchTelegramHelper(context, tgAppUri, tgWebUri);
                },
                icon: const Icon(
                  Icons.telegram_rounded,
                  color: Color(0xFF0088CC),
                  size: 18,
                ),
                label: Text(
                  AppLocalizations.of(context)!.requestViaTelegram,
                  style: const TextStyle(
                    color: Color(0xFF0088CC),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF0088CC,
                  ).withValues(alpha: 0.12),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: const Color(0xFF0088CC).withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchUrlHelper(
    BuildContext context,
    Uri uri,
    String platformName,
  ) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                )!.couldNotLaunchLink(platformName, e.toString()),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _launchTelegramHelper(
    BuildContext context,
    Uri tgAppUri,
    Uri tgWebUri,
  ) async {
    try {
      final launched = await launchUrl(
        tgAppUri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (!launched) {
        await launchUrl(tgWebUri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(tgWebUri, mode: LaunchMode.platformDefault);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                )!.couldNotLaunchTelegram(e.toString()),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  // ── 4. Refill Executions History ───────────────────────────────────────────
  Widget _buildExecutionsSection(
    BuildContext context,
    SimLineDetailState detail,
  ) {
    final isPremium = detail.simLine.protectionTier.toLowerCase() == 'premium';
    final isDark = context.isDarkMode;

    if (!isPremium) {
      return const SizedBox.shrink();
    }

    final list = detail.executions
        .where((ex) {
          final txId = ex.reloadlyTransactionId;
          if (txId != null && txId.toUpperCase().contains('MOCK')) {
            return false;
          }
          return true;
        })
        .take(5)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.lightPrimary.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPremium
                ? AppLocalizations.of(context)!.refillExecutionsHistory
                : AppLocalizations.of(context)!.renewalExecutionsHistory,
            style: AppTextStyles.titleLarge.copyWith(
              color: context.onSurfaceColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                isPremium
                    ? AppLocalizations.of(context)!.noHistoricalTopup
                    : AppLocalizations.of(context)!.noHistoricalRenewal,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (context, index) => Divider(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                height: 16,
              ),
              itemBuilder: (context, index) {
                final ex = list[index];
                final isSuccess = ex.status == 'success';
                final targetDate = ex.executedAt ?? ex.executionTime ?? ex.createdAt ?? DateTime.now();
                final dateStr = DateFormat(
                  'MMM dd, yyyy HH:mm',
                ).format(targetDate);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isSuccess ? AppColors.success : AppColors.error)
                            .withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSuccess
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
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
                          if (isSuccess && ex.pinCode != null && ex.pinCode!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.amber : Colors.orange).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (isDark ? Colors.amber : Colors.orange).withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.pin_outlined,
                                        color: isDark ? Colors.amberAccent : Colors.orange.shade800,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Recharge PIN Code',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark ? Colors.amberAccent : Colors.orange.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppColors.darkSurface
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                            ),
                                          ),
                                          child: SelectableText(
                                            ex.pinCode!,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton.filledTonal(
                                        icon: const Icon(
                                          Icons.copy_rounded,
                                          size: 18,
                                        ),
                                        tooltip: 'Copy PIN',
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(text: ex.pinCode!),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'PIN copied to clipboard!',
                                              ),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  if (ex.redeemInstructions != null && ex.redeemInstructions!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      ex.redeemInstructions!,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(
                                        Icons.phone_forwarded_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        '1-Tap Dial (*1400*${ex.pinCode}#)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark ? Colors.amber.shade700 : Colors.orange.shade700,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final dialString =
                                            '*1400*${ex.pinCode}#';
                                        final uri = Uri.parse(
                                          'tel:${Uri.encodeComponent(dialString)}',
                                        );
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (ex.status == 'awaiting_approval') ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 16,
                                        color: Colors.amber.shade900,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Price Increase Approval Required',
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                              color: Colors.amber.shade900,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Quoted price \$${ex.amount.toStringAsFixed(2)} exceeds authorized limit of \$${(ex.maxAuthorizedUsd ?? ex.amount).toStringAsFixed(2)}.',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                  if (!_isViewer) ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 28,
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _handleApproveRefill(context, ex),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.amber.shade800,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Review Current Price',
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
                          if (!isSuccess &&
                              ex.status != 'awaiting_approval' &&
                              ex.failureReason != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.error.withValues(
                                    alpha: 0.15,
                                  ),
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
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.retryConnection,
                                          style: const TextStyle(
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
                );
              },
            ),
          if (list.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticHelper.lightTick();
                  context.goNamed(
                    'simLineExecutions',
                    pathParameters: {'id': detail.simLine.id},
                  );
                },
                icon: Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: isDark
                      ? AppColors.primaryLight
                      : AppColors.lightPrimary,
                ),
                label: Text(
                  AppLocalizations.of(context)!.viewAllHistory,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.primaryLight
                        : AppColors.lightPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 5. Activity Logs Timeline UI ───────────────────────────────────────────
  Widget _buildTimelineSection(
    BuildContext context,
    SimLineDetailState detail,
  ) {
    final isDark = context.isDarkMode;
    final list = detail.activityLogs
        .where((log) {
          if (log.metadata['is_mock'] == true ||
              log.metadata['is_mock'] == 'true' ||
              (log.description != null &&
                  log.description!.toUpperCase().contains('MOCK'))) {
            return false;
          }
          return true;
        })
        .take(13)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.lightPrimary.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.securityActivityLogs,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (list.isNotEmpty && !_isViewer)
                TextButton.icon(
                  onPressed: () => _handleCleanMockLogs(context),
                  icon: Icon(
                    Icons.cleaning_services,
                    size: 14,
                    color: isDark
                        ? AppColors.primaryLight
                        : AppColors.lightPrimary,
                  ),
                  label: Text(
                    AppLocalizations.of(context)!.clearLogs,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.primaryLight
                          : AppColors.lightPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                AppLocalizations.of(context)!.noActivityLogsRecorded,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
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

                Color iconColor = isDark
                    ? AppColors.primaryLight
                    : AppColors.lightPrimary;
                IconData iconData = Icons.info_outline;

                if (log.eventType == 'topup_success') {
                  iconColor = AppColors.success;
                  iconData = Icons.check_circle_outline;
                } else if (log.eventType == 'topup_failed') {
                  iconColor = AppColors.error;
                  iconData = Icons.error_outline;
                } else if (log.eventType == 'topup_requested' ||
                    log.eventType == 'topup_retry_queued') {
                  iconColor = AppColors.warning;
                  iconData = Icons.hourglass_top;
                } else if (log.eventType == 'topup_refunded') {
                  iconColor = AppColors.info;
                  iconData = Icons.history;
                } else if (log.eventType == 'topup_cancelled') {
                  iconColor = AppColors.error;
                  iconData = Icons.cancel_outlined;
                } else if (log.eventType == 'health_update') {
                  iconColor = isDark
                      ? AppColors.secondary
                      : AppColors.lightSecondary;
                  iconData = Icons.shield_outlined;
                } else if (log.eventType == 'created') {
                  iconColor = isDark
                      ? AppColors.primaryLight
                      : AppColors.lightPrimary;
                  iconData = Icons.add_box_outlined;
                } else if (log.eventType == 'reminder_sent') {
                  iconColor = AppColors.info;
                  iconData = Icons.notifications_active_outlined;
                }

                final dateStr = DateFormat(
                  'MMM dd, yyyy HH:mm',
                ).format(log.createdAt);

                final isFinancialEvent = log.eventType.startsWith('topup_');

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
                              color: iconColor.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: iconColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Icon(iconData, color: iconColor, size: 16),
                          ),
                          Expanded(
                            child: isLast
                                ? const SizedBox(height: 20)
                                : Container(
                                    width: 2,
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
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
                              log.getLocalizedDescription(context),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: context.onSurfaceColor,
                                height: 1.3,
                              ),
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
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      // Actions (Option A: financial events are immutable)
                      if (!_isViewer && !isFinancialEvent)
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                              size: 18,
                            ),
                            onPressed: () =>
                                _handleDeleteActivityLog(context, log.id),
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
  void _openScheduleSheet(
    BuildContext context,
    SimLine line,
    ScheduledTopup? existingSchedule,
    String configMode,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduledTopupSheet(
        simLineId: line.id,
        simNickname: line.nickname ?? line.phoneNumber,
        simLine: line,
        existingSchedule: existingSchedule,
        configMode: configMode,
      ),
    );
  }

  Future<void> _handleRetryFailedTopup(
    BuildContext context,
    String executionId,
  ) async {
    try {
      final result = await ref
          .read(simLineDetailControllerProvider(widget.id).notifier)
          .retryFailedTopup(executionId);
      if (context.mounted) {
        if (result is Success<void>) {
          // C3b-2: the retry is queued through the real worker pipeline; its
          // outcome streams in via topupExecutionsLiveProvider.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.refillRetryQueued),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (result is Failure<void>) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.retryFailed(result.error.message),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.retryExecutionError(e.toString()),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleApproveRefill(
    BuildContext context,
    TopupExecution ex,
  ) async {
    final repository = ref.read(scheduledTopupRepositoryProvider);
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RefillPriceApprovalDialog(
        loadQuote: () => repository.prepareExecutionApproval(ex.id),
        approveQuote: (quote) => ref
            .read(simLineDetailControllerProvider(widget.id).notifier)
            .approveRefillExecution(
              ex.id,
              quoteId: quote.id,
              newMaxAuthorizedUsd: quote.totalUsd,
            ),
      ),
    );
    if (!context.mounted) return;
    ref.invalidate(topupExecutionsForLineProvider(widget.id));
    ref.invalidate(simLineExecutionsHistoryProvider(widget.id));
    if (approved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Approval accepted. Processing may start immediately; any higher price needs your approval again.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleDeleteActivityLog(
    BuildContext context,
    String logId,
  ) async {
    try {
      await ref
          .read(simLineDetailControllerProvider(widget.id).notifier)
          .deleteActivityLog(logId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.activityLogDeleted),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.failedToDeleteActivityLog(e.toString()),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleCleanMockLogs(BuildContext context) async {
    try {
      await ref
          .read(simLineDetailControllerProvider(widget.id).notifier)
          .clearAllActivityLogs();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.activityLogsCleared),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.failedToClearActivityLogs(e.toString()),
            ),
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

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    SimLine line,
  ) async {
    final isDark = context.isDarkMode;

    // Captured before any await. This used to pop the dialog and *then* call
    // GoRouter.of/ScaffoldMessenger.of on the builder's context, which shadows
    // State.context and is dead once popped.
    final goRouter = GoRouter.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              l10n.removeProtectionTitle,
              style: AppTextStyles.headlineSmall.copyWith(
                color: context.onSurfaceColor,
              ),
            ),
          ],
        ),
        content: Text(
          l10n.confirmRemoveProtectionDesc(line.nickname ?? line.phoneNumber),
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              l10n.cancel,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(
              l10n.deleteButton,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // Deleting a line is irreversible, so it is gated on the owner being
    // present. No grace window: this prompts every time, even seconds after a
    // refill was authenticated.
    final verified = await ref
        .read(destructiveActionGuardProvider)
        .confirmDestructiveAction(
          context,
          reason:
              'Authenticate to delete ${line.nickname ?? line.phoneNumber}',
          confirmationToken: destructiveConfirmationToken(line.phoneNumber),
        );
    if (!verified) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.deletionNotVerified),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Instantly navigate back to the Home Page to prevent this screen
    // from rebuilding with a "SIM Line not found" error when the deletion completes.
    goRouter.go(AppRoutes.home);

    try {
      await ref.read(simLinesControllerProvider.notifier).deleteSimLine(line.id);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.simLineProtectionRemoved),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.failedToDeleteSimLine(e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showEditNicknameDialog(BuildContext context, SimLine line) {
    final isDark = context.isDarkMode;
    final controller = TextEditingController(text: line.nickname ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  color: isDark
                      ? AppColors.primaryLight
                      : AppColors.lightPrimary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.editSimNameTitle,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: context.onSurfaceColor,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.enterNicknameInstruction,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: context.onSurfaceColor, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.nicknameExampleHint,
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurface
                        : const Color(0xFFEAEEF1),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.primary
                            : AppColors.lightPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context)!.cancel,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() {
                          isSaving = true;
                        });
                        try {
                          final updatedLine = line.copyWith(
                            nickname: controller.text.trim().isNotEmpty
                                ? controller.text.trim()
                                : null,
                          );

                          await ref
                              .read(simLinesControllerProvider.notifier)
                              .updateSimLine(updatedLine);

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.simNameUpdatedSuccess,
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setState(() {
                              isSaving = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.failedToUpdateSimName(e.toString()),
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        AppLocalizations.of(context)!.saveButton,
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
