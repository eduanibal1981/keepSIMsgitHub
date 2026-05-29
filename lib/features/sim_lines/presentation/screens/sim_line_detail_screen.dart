import 'package:collection/collection.dart';
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
import 'package:keep_sims/features/sim_lines/presentation/widgets/manual_refill_bottom_sheet.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class SimLineDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const SimLineDetailScreen({super.key, required this.id});

  @override
  ConsumerState<SimLineDetailScreen> createState() =>
      _SimLineDetailScreenState();
}

class _SimLineDetailScreenState extends ConsumerState<SimLineDetailScreen> {
  bool _isToggling = false;
  late bool _isShared;
  late bool _isViewer;
  dynamic _membership;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(simLineDetailControllerProvider(widget.id));
    final countriesState = ref.watch(supportedCountriesProvider);
    final user = ref.watch(authControllerProvider).valueOrNull;
    final simLine = detailAsync.valueOrNull?.simLine;
    final householdState = ref.watch(householdControllerProvider).valueOrNull;

    _isShared = simLine != null && simLine.userId != user?.id;
    _membership = _isShared
        ? householdState?.memberships.firstWhereOrNull((m) => m.ownerId == simLine!.userId)
        : null;
    _isViewer = _isShared && (_membership == null || _membership.role == 'viewer');

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimaryDark,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Protection Console',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimaryDark,
          ),
        ),
        actions: [
          if (simLine != null && simLine.userId == user?.id)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              tooltip: 'Delete Protection',
              onPressed: () async {
                await HapticHelper.mediumImpact();
                if (context.mounted) {
                  _showDeleteConfirmation(context, simLine);
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondaryDark),
            tooltip: 'Refresh',
            onPressed: () async {
              await HapticHelper.lightTick();
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
              : countries.firstWhere(
                  (c) => c.id == detailState.simLine.countryId,
                  orElse: () => countries.first,
                );

          bool isHomeCountry = false;
          if (user?.homeCountryCode != null && country != null) {
            isHomeCountry = user!.homeCountryCode!.toUpperCase() == country.isoCode.toUpperCase();
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Line Header Card
                _buildHeaderCard(context, detailState.simLine, country),
                const SizedBox(height: 20),

                // Back Home Plan Card
                if (isHomeCountry) ...[
                  _buildBackHomeCard(context, detailState.simLine, country),
                  const SizedBox(height: 20),
                ],

                // 2. Health & Optimization Ring Panel
                _buildHealthScoreSection(context, detailState),
                const SizedBox(height: 20),

                // Peer-to-Peer Free WhatsApp Recharge Request
                _buildP2PRechargeRequestCard(context, detailState.simLine),
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
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 54,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load details',
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
                  child: const Text(
                    'Retry Connection',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
                if (_isShared) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        color: AppColors.primaryLight,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Shared by: ${_membership?.ownerName ?? 'Family Member'} (${_isViewer ? 'Viewer' : 'Manager'})',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!_isViewer) ...[
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _handleVerifyLineActivity(context, line),
                  icon: const Icon(Icons.radar, size: 20),
                  tooltip: line.verificationStatus == 'unverified' ? 'Verify' : 'Reverify',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ManualRefillBottomSheet(simLine: line),
                    );
                  },
                  icon: const Icon(Icons.attach_money_rounded, size: 22),
                  tooltip: 'Manual Refill',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
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

  // ── Back Home Plan Card UI ────────────────────────────────────────────────
  Widget _buildBackHomeCard(BuildContext context, SimLine line, dynamic country) {
    bool isPremium = line.protectionTier.toLowerCase() == 'premium';

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
            children: [
              const Icon(Icons.flight_land, color: AppColors.primaryLight, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Back to ${country?.name ?? 'Home'}',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            line.isHomeMode 
              ? 'Your SIM is currently in Home Mode. When you travel abroad again, return to Travel Mode to resume protection.'
              : 'Prepare your SIM for your return. renewal(pause) - prepare a data/call plan before you arrive (premium).',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isViewer
                      ? null
                      : () {
                          ref
                              .read(simLinesControllerProvider.notifier)
                              .toggleHomeMode(line.id, !line.isHomeMode);
                        },
                  icon: Icon(line.isHomeMode ? Icons.flight_takeoff : Icons.pause_circle_outline, size: 18),
                  label: Text(line.isHomeMode ? 'Return to Travel Mode' : 'Activate Home Mode'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: line.isHomeMode ? Colors.lightBlue : AppColors.warning,
                    side: BorderSide(color: line.isHomeMode ? Colors.lightBlue : AppColors.warning),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isPremium && !line.isHomeMode) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Prepare Baqa Plan logic
                },
                icon: const Icon(Icons.card_giftcard, size: 18, color: Colors.white),
                label: const Text(
                  'Prepare "Baqa" Plan (100 Min / 1GB)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else if (!line.isHomeMode) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.textTertiaryDark, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Upgrade to Premium to pre-book a "Baqa" plan (calls & internet).',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 2. Health & Circular score UI ──────────────────────────────────────────
  Widget _buildHealthScoreSection(
    BuildContext context,
    SimLineDetailState detail,
  ) {
    bool hasAutoRefill =
        detail.scheduledTopup != null &&
        detail.scheduledTopup!.status == 'active';
    bool isVerified = detail.simLine.status == 'active';
    bool recentRefill =
        detail.simLine.lastTopupAt != null &&
        DateTime.now().difference(detail.simLine.lastTopupAt!).inDays <= 80;

    int dynamicScore =
        (hasAutoRefill ? 50 : 0) +
        (isVerified ? 25 : 0) +
        (recentRefill ? 25 : 0);
    
    // Override score if in Home Mode
    if (detail.simLine.isHomeMode) {
      dynamicScore = 100;
    }
    final score = dynamicScore;

    List<String> missingReasons = [];
    if (!detail.simLine.isHomeMode) {
      if (!hasAutoRefill)
        missingReasons.add("Missing 50%: Configure an Auto-Refill schedule.");
      if (!isVerified)
        missingReasons.add("Missing 25%: Verify your line activity.");
      if (!recentRefill)
        missingReasons.add("Missing 25%: Last refill was more than 80 days ago.");
    }

    Color scoreColor = AppColors.healthGreen;
    String rating = 'SECURE';
    String description =
        'Your SIM card has active automated refill protection configured.';

    if (detail.simLine.isHomeMode) {
      scoreColor = Colors.lightBlue;
      rating = 'HOME MODE';
      description = 'Auto-renewal is paused while you are in your home country. Your line remains secure.';
    } else if (score < 50) {
      scoreColor = AppColors.healthRed;
      rating = 'CRITICAL RISK';
      description =
          'Multiple protection layers missing. Secure your line immediately to prevent deactivation.';
    } else if (score < 100) {
      scoreColor = AppColors.healthAmber;
      rating = 'WARNING';
      description =
          'Your line is partially protected. Address the missing criteria to reach 100%.';
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
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 4,
                      backgroundColor: AppColors.darkCard,
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                    Text(
                      '$score',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: scoreColor,
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
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiaryDark,
                      ),
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
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    if (missingReasons.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...missingReasons.map(
                        (reason) => Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 14,
                                color: AppColors.healthAmber,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.healthAmber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  // ── 3. Auto-Refill Schedule UI ─────────────────────────────────────────────
  Widget _buildAutoRefillSection(
    BuildContext context,
    SimLineDetailState detail,
  ) {
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
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.healthRed,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Auto-Refill: Disabled',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your SIM card has no active automatic renewal schedule. SIM card will expire and get permanently deactivated if not recharged on time.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 16),
            if (_isViewer)
              Text(
                'Please ask the household owner to configure auto-renewal.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryDark,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () => _openScheduleSheet(
                  context,
                  detail.simLine,
                  detail.scheduledTopup,
                ),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text(
                  'Configure Auto-Renewal',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                style: AppTextStyles.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (schedule.isActive
                                  ? AppColors.secondary
                                  : AppColors.warning)
                              .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            (schedule.isActive
                                    ? AppColors.secondary
                                    : AppColors.warning)
                                .withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      schedule.isActive ? 'ACTIVE' : 'PAUSED',
                      style: TextStyle(
                        color: schedule.isActive
                            ? AppColors.secondary
                            : AppColors.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: schedule.isActive,
                    activeColor: AppColors.secondary,
                    onChanged: _isViewer || _isToggling
                        ? null
                        : (val) =>
                              _handleToggleSchedule(context, schedule.id, val),
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
            schedule.frequencyDays == 0
                ? 'Every 1 hour'
                : 'Every ${schedule.frequencyDays} days',
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
          if (!_isViewer) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14.0),
              child: Divider(color: AppColors.darkBorder, height: 1),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openScheduleSheet(
                      context,
                      detail.simLine,
                      detail.scheduledTopup,
                    ),
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.textPrimaryDark,
                    ),
                    label: const Text(
                      'Edit Schedule',
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: AppColors.darkBorder),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () =>
                      _showDeleteScheduleConfirmation(context, schedule.id),
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
        ],
      ),
    );
  }

  Widget _buildScheduleRowItem(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiaryDark),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
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
  Widget _buildExecutionsSection(
    BuildContext context,
    SimLineDetailState detail,
  ) {
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
            style: AppTextStyles.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'No historical top-up executions recorded for this line yet.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: AppColors.darkBorder, height: 16),
              itemBuilder: (context, index) {
                final ex = list[index];
                final isSuccess = ex.status == 'success';
                final dateStr = DateFormat(
                  'MMM dd, yyyy HH:mm',
                ).format(ex.executedAt);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isSuccess ? AppColors.success : AppColors.error)
                            .withOpacity(0.08),
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
                                  color: Colors.white,
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
                                          .withOpacity(0.12),
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
                              color: AppColors.textTertiaryDark,
                            ),
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
                                border: Border.all(
                                  color: AppColors.error.withOpacity(0.15),
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
                                        onPressed: () => _handleRetryFailedTopup(
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
                    // Actions
                    if (!_isViewer)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.textTertiaryDark,
                          size: 20,
                        ),
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
  Widget _buildTimelineSection(
    BuildContext context,
    SimLineDetailState detail,
  ) {
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
                style: AppTextStyles.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (list.isNotEmpty && !_isViewer)
                TextButton.icon(
                  onPressed: () => _handleCleanMockLogs(context),
                  icon: const Icon(
                    Icons.cleaning_services,
                    size: 14,
                    color: AppColors.primaryLight,
                  ),
                  label: const Text(
                    'Clean the Activity logs',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primaryLight,
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
                'No activity logs recorded for this line yet.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondaryDark,
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

                final dateStr = DateFormat(
                  'MMM dd, yyyy HH:mm',
                ).format(log.createdAt);

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
                              border: Border.all(
                                color: iconColor.withOpacity(0.2),
                              ),
                            ),
                            child: Icon(iconData, color: iconColor, size: 16),
                          ),
                          Expanded(
                            child: isLast
                                ? const SizedBox(height: 20)
                                : Container(
                                    width: 2,
                                    color: AppColors.darkBorder,
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
                              log.description ?? '',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiaryDark,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      // Actions
                      if (!_isViewer)
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.textTertiaryDark,
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
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduledTopupSheet(
        simLineId: line.id,
        simNickname: line.nickname ?? line.phoneNumber,
        existingSchedule: existingSchedule,
      ),
    );
  }

  Future<void> _handleToggleSchedule(
    BuildContext context,
    String scheduleId,
    bool isActive,
  ) async {
    setState(() {
      _isToggling = true;
    });

    try {
      final result = await ref
          .read(scheduledTopupControllerProvider.notifier)
          .toggleActive(scheduleId, isActive);
      if (result is Success<ScheduledTopup>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Auto-Renewal successfully ${isActive ? 'enabled' : 'paused'}.',
              ),
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

  void _showDeleteScheduleConfirmation(
    BuildContext context,
    String scheduleId,
  ) {
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
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Remove Schedule',
              style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this auto-refill schedule? Your SIM health score will drop significantly, risking deactivation.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final result = await ref
                    .read(scheduledTopupControllerProvider.notifier)
                    .removeSchedule(scheduleId);
                if (result is Success<void>) {
                  ref.invalidate(simLineDetailControllerProvider(widget.id));
                  ref.invalidate(simLinesControllerProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Auto-renewal schedule removed successfully.',
                        ),
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


  Future<void> _handleRetryFailedTopup(
    BuildContext context,
    String executionId,
  ) async {
    try {
      final result = await ref
          .read(simLineDetailControllerProvider(widget.id).notifier)
          .retryFailedTopup(executionId);
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
              content: Text(
                'Retry failed: ${(result as Failure<void>).error.message}',
              ),
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

  Future<void> _handleDeleteExecution(
    BuildContext context,
    String executionId,
  ) async {
    try {
      await ref
          .read(simLineDetailControllerProvider(widget.id).notifier)
          .deleteExecution(executionId);
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

  Future<void> _handleDeleteActivityLog(
    BuildContext context,
    String logId,
  ) async {
    try {
      await ref
          .read(simLineDetailControllerProvider(widget.id).notifier)
          .deleteActivityLog(logId);
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
      await ref
          .read(simLineDetailControllerProvider(widget.id).notifier)
          .cleanMockLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity logs cleaned successfully.'),
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

  void _showDeleteConfirmation(BuildContext context, SimLine line) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.darkBorder),
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
              'Remove Protection',
              style: AppTextStyles.headlineSmall.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to stop keeping ${line.nickname ?? line.phoneNumber} protected? Scheduled top-ups for this SIM line will be permanently cancelled.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Dismiss the confirm dialog
              
              final goRouter = GoRouter.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              // Instantly navigate back to the Home Page to prevent this screen
              // from rebuilding with a "SIM Line not found" error when the deletion completes.
              goRouter.go(AppRoutes.home);
              
              try {
                await ref
                    .read(simLinesControllerProvider.notifier)
                    .deleteSimLine(line.id);
                
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'SIM line protection removed successfully.',
                    ),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildP2PRechargeRequestCard(BuildContext context, SimLine line) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6366F1), // Indigo
            Color(0xFF8B5CF6), // Purple
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.ios_share_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Recharge from a Friend',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Running low or need help extending validity? Share a secure payment link directly on WhatsApp and ask a friend or family member to recharge this card for you.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await HapticHelper.lightTick();
                final phone = line.phoneNumber;
                final templateText = 'Hi! My KeepSIMs card ($phone) is expiring soon. Could you please recharge it for me here? https://keep-sims.com/recharge?phone=$phone';
                final waUrl = 'https://wa.me/?text=${Uri.encodeComponent(templateText)}';
                final uri = Uri.parse(waUrl);
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
                          content: Text('Could not launch WhatsApp link: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.chat_rounded, color: Color(0xFF6366F1), size: 18),
              label: const Text(
                'Request via WhatsApp',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
