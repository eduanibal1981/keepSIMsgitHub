import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_activity_log_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_line_detail_controller.dart';
import 'package:keep_sims/core/widgets/glass_card.dart';
import 'package:keep_sims/core/widgets/glass_toggle_switch.dart';
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
import 'package:keep_sims/features/profile/presentation/widgets/subscription_upsell_sheet.dart';
import 'package:keep_sims/features/offline_recharge/controller/offline_refill_controller.dart';
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
        ? householdState?.memberships.firstWhereOrNull(
            (m) => m.ownerId == simLine!.userId,
          )
        : null;
    _isViewer =
        _isShared && (_membership == null || _membership.role == 'viewer');

    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: context.onSurfaceColor,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Protection Console',
          style: AppTextStyles.headlineMedium.copyWith(
            color: context.onSurfaceColor,
          ),
        ),
        actions: [
          if (simLine != null && simLine.userId == user?.id)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              tooltip: 'Delete Protection',
              onPressed: () async {
                await HapticHelper.mediumImpact();
                if (context.mounted) {
                  _showDeleteConfirmation(context, simLine);
                }
              },
            ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            tooltip: 'Refresh',
            onPressed: () async {
              await HapticHelper.lightTick();
              ref.invalidate(simLineDetailControllerProvider(widget.id));
            },
          ),
        ],
      ),
      body: () {
        final detailState = detailAsync.valueOrNull;
        if (detailState != null) {
          final countries = countriesState.valueOrNull ?? [];
          final country = countries.isEmpty
              ? null
              : countries.firstWhere(
                  (c) => c.id == detailState.simLine.countryId,
                  orElse: () => countries.first,
                );

          bool isHomeCountry = false;
          if (user?.homeCountryCode != null && country != null) {
            isHomeCountry =
                user!.homeCountryCode!.toUpperCase() ==
                country.isoCode.toUpperCase();
          }

          final isPremium =
              detailState.simLine.protectionTier.toLowerCase() == 'premium' ||
              (user != null &&
                  user.subscriptionTier.toLowerCase() == 'premium');

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

                // Manual Refill Section
                if (!_isViewer && isPremium) ...[
                  _buildManualRefillSection(context, detailState.simLine, isPremium),
                  const SizedBox(height: 20),
                ],

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
        );
      }(),
    );
  }

  // ── 1. Header Card UI ──────────────────────────────────────────────────────
  Widget _buildHeaderCard(BuildContext context, SimLine line, dynamic country) {
    final userProfile = ref.read(authControllerProvider).valueOrNull;
    final bool isPremium =
        line.protectionTier.toLowerCase() == 'premium' ||
        (userProfile != null &&
            userProfile.subscriptionTier.toLowerCase() == 'premium');
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
          return Icons.sim_card;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.darkCardGradient
            : LinearGradient(
                colors: [Colors.white, context.scaffoldBackgroundColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.primary : AppColors.lightPrimary).withOpacity(0.05),
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
                  color: isDark ? AppColors.darkSurface : const Color(0xFFEAEEF1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Icon(
                  getIcon(line.avatarIcon),
                  color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                  size: 28,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
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
                          color: context.onSurfaceColor,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTierBadge(
                      isPremium ? 'premium' : line.protectionTier,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  line.phoneNumber,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (country != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    country.name as String,
                    style: AppTextStyles.caption.copyWith(
                      color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                    ),
                  ),
                ],
                if (_isShared) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Shared by: ${_membership?.ownerName ?? 'Family Member'} (${_isViewer ? 'Viewer' : 'Manager'})',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualRefillSection(
    BuildContext context,
    SimLine line,
    bool isPremium,
  ) {
    if (_isViewer || !isPremium) {
      return const SizedBox.shrink();
    }
    final isDark = context.isDarkMode;
    final accentColor = isDark ? AppColors.secondary : AppColors.lightSecondary;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.attach_money_rounded,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manual Refill',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Deduct amount directly from your wallet to instantly recharge this SIM card manually.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) =>
                      ManualRefillBottomSheet(simLine: line),
                );
              },
              icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Instant Manual Refill',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
                shadowColor: accentColor.withOpacity(0.3),
              ),
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

  // ── Back Home Plan Card UI ────────────────────────────────────────────────
  Widget _buildBackHomeCard(
    BuildContext context,
    SimLine line,
    dynamic country,
  ) {
    final userProfile = ref.read(authControllerProvider).valueOrNull;
    final bool isPremium =
        line.protectionTier.toLowerCase() == 'premium' ||
        (userProfile != null &&
            userProfile.subscriptionTier.toLowerCase() == 'premium');
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flight_land,
                color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Back to ${country?.name ?? 'Home'}',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch.adaptive(
                value: line.isHomeMode,
                activeColor: isDark ? AppColors.secondary : AppColors.lightSecondary,
                onChanged: _isViewer
                    ? null
                    : (val) {
                        ref
                            .read(simLinesControllerProvider.notifier)
                            .toggleHomeMode(line.id, val);
                      },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            line.isHomeMode
                ? 'Your SIM is currently in Home Mode. When you travel abroad again, turn off Home Mode to resume protection.'
                : 'Switch on to pause auto-renewal while in your home country. Feel free to get Baqa plan for uninterrupted calls & internet.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),

          if (isPremium && !line.isHomeMode) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Prepare Baqa Plan logic
                },
                icon: const Icon(
                  Icons.card_giftcard,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Prepare "Baqa" Plan (100 Min / 1GB)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.primary : AppColors.lightPrimary,
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
                color: isDark ? AppColors.darkCard : const Color(0xFFEAEEF1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Upgrade to Premium to pre-book a "Baqa" plan (calls & internet).',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
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
    final userProfile = ref.read(authControllerProvider).valueOrNull;
    final isPremium =
        detail.simLine.protectionTier.toLowerCase() == 'premium' ||
        (userProfile != null &&
            userProfile.subscriptionTier.toLowerCase() == 'premium');
    final line = detail.simLine;
    final hasProtectionActive = isPremium
        ? (detail.refillSchedule != null &&
              detail.refillSchedule!.status == 'active')
        : (detail.notifySchedule != null &&
              detail.notifySchedule!.status == 'active');
    final isVerified = line.status == 'active';
    final recentRefill =
        line.lastTopupAt != null &&
        DateTime.now().difference(line.lastTopupAt!).inDays <= 80;

    final score = line.isHomeMode
        ? 100
        : (!isPremium
              ? (hasProtectionActive ? 100 : 0)
              : ((hasProtectionActive ? 50 : 0) +
                    (isVerified ? 25 : 0) +
                    (recentRefill ? 25 : 0)));

    List<String> missingReasons = [];
    if (!detail.simLine.isHomeMode) {
      if (!isPremium) {
        if (!hasProtectionActive) {
          missingReasons.add(
            "Missing 100%: Configure alert notifications (Auto-Notify).",
          );
        }
      } else {
        if (!hasProtectionActive) {
          missingReasons.add("Missing 50%: Configure an Auto-Refill schedule.");
        }
        if (!isVerified) {
          missingReasons.add("Missing 25%: Verify your line activity.");
        }
        if (!recentRefill) {
          missingReasons.add(
            "Missing 25%: Last refill was more than 80 days ago.",
          );
        }
      }
    }

    Color scoreColor = AppColors.healthGreen;
    String rating = 'SECURE';
    String description = isPremium
        ? 'SIM in Full protection'
        : 'Your SIM card has automated alert notifications';

    if (detail.simLine.isHomeMode) {
      scoreColor = Colors.lightBlue;
      rating = 'HOME MODE';
      description =
          'Auto-renewal is paused while you are in your home country.';
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

    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.lightPrimary.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
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
                      backgroundColor: isDark ? AppColors.darkCard : const Color(0xFFEAEEF1),
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
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
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
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
          if (!_isViewer) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1),
            ),
            _buildVerificationPanel(context, line),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationPanel(BuildContext context, SimLine line) {
    final userProfile = ref.read(authControllerProvider).valueOrNull;
    final String tier =
        (userProfile != null &&
            userProfile.subscriptionTier.toLowerCase() == 'premium')
        ? 'premium'
        : line.protectionTier.toLowerCase();
    final bool isVerified = line.status == 'active';
    final isDark = context.isDarkMode;

    if (tier == 'basic') {
      // Free Tier: Disabled completely
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : const Color(0xFFEAEEF1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Icon(
              Icons.lock_outline,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Line Verification Locked',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Line verification is only available on Starter and Premium plans.',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (tier == 'standard') {
      // Standard Tier: 1x only. If already verified, hide or show "Line Verified (1x Check Completed)"
      if (isVerified) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SIM Line Verified',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your Starter Plan 1x secure line check is completed and recorded.',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        // Standard not yet verified
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify SIM Activity',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Starter plan includes 1x secure line verification check to confirm status.',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _handleVerifyLineActivity(context, line),
                icon: const Icon(Icons.radar, size: 14),
                label: const Text('Verify'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    // Premium Tier: Always available, unlimited verifications
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isVerified
            ? AppColors.success.withOpacity(0.05)
            : AppColors.warning.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified
              ? AppColors.success.withOpacity(0.15)
              : AppColors.warning.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isVerified ? 'Test SIM Activity' : 'Test SIM Activity',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isVerified ? AppColors.success : context.onSurfaceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _handleVerifyLineActivity(context, line),
            icon: const Icon(Icons.radar, size: 14),
            label: Text(isVerified ? 'Reverify' : 'Verify'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Auto-Refill Schedule UI ─────────────────────────────────────────────
  // ── 3. Auto-Notify & Auto-Refill Configuration Panels ──────────────────────
  Widget _buildAutoRefillSection(
    BuildContext context,
    SimLineDetailState detail,
  ) {
    final line = detail.simLine;
    final userProfile = ref.read(authControllerProvider).valueOrNull;
    final isPremium =
        line.protectionTier.toLowerCase() == 'premium' ||
        (userProfile != null &&
            userProfile.subscriptionTier.toLowerCase() == 'premium');

    return Column(
      children: [
        _buildAutoNotifyDetailPanel(context, line, detail.notifySchedule),
        const SizedBox(height: 20),
        _buildAutoRefillDetailPanel(
          context,
          line,
          detail.refillSchedule,
          isPremium,
        ),
      ],
    );
  }

  Widget _buildAutoNotifyDetailPanel(
    BuildContext context,
    SimLine line,
    ScheduledTopup? schedule,
  ) {
    final isConfigured = schedule != null;
    final isPaused = schedule != null && !schedule.isActive;
    final isDark = context.isDarkMode;

    if (!isConfigured) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        isActive: false,
        activeColor: AppColors.healthRed,
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
                  'Auto-Notify: Disabled',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your SIM card has no active alert notification schedule. You will not receive automatic reminders or deactivation alerts.',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            if (_isViewer)
              Text(
                'Please ask the household owner to configure alerts.',
                style: AppTextStyles.caption.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () =>
                    _openScheduleSheet(context, line, null, 'notify'),
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Configure Auto-Notify',
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
    final isPausedByHome = line.isHomeMode;
    final displayActive = schedule.isActive && !isPausedByHome;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      isActive: displayActive,
      activeColor: AppColors.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Auto-Notify Schedule',
                style: AppTextStyles.titleLarge.copyWith(
                  color: context.onSurfaceColor,
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
                          (displayActive
                                  ? AppColors.secondary
                                  : AppColors.warning)
                              .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            (displayActive
                                    ? AppColors.secondary
                                    : AppColors.warning)
                                .withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      displayActive
                          ? 'ACTIVE'
                          : (isPausedByHome ? 'PAUSED (HOME MODE)' : 'PAUSED'),
                      style: TextStyle(
                        color: displayActive
                            ? AppColors.secondary
                            : AppColors.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassToggleSwitch(
                    value: displayActive,
                    activeColor: AppColors.secondary,
                    onChanged: _isViewer || _isToggling || isPausedByHome
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
            context,
            'Renewal Check Interval',
            schedule.frequencyDays == 0
                ? 'Every 1 hour'
                : 'Every ${schedule.frequencyDays} days',
            Icons.repeat,
          ),
          const SizedBox(height: 12),
          _buildScheduleRowItem(
            context,
            'Next Alert Check',
            isPausedByHome
                ? 'Paused (Home Mode)'
                : dateFormat.format(schedule.nextExecutionAt),
            Icons.date_range,
            valueColor: isPausedByHome ? AppColors.warning : null,
          ),
          if (!_isViewer) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14.0),
              child: Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _openScheduleSheet(context, line, schedule, 'notify'),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: context.onSurfaceColor,
                    ),
                    label: Text(
                      'Edit Notification Config',
                      style: TextStyle(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  onPressed: () => _showDeleteScheduleConfirmation(
                    context,
                    schedule.id,
                    false,
                  ),
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

  Widget _buildAutoRefillDetailPanel(
    BuildContext context,
    SimLine line,
    ScheduledTopup? schedule,
    bool isPremium,
  ) {
    final isDark = context.isDarkMode;
    if (!isPremium) {
      // Locked for Free/Standard
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Auto-Refill: Locked 🔒',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.onSurfaceColor.withOpacity(0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Auto-Refill automatically purchases credit to top-up your balance and extend validity before expiration. This feature is exclusive to Premium Plan subscribers.',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await HapticHelper.mediumImpact();
                  SubscriptionUpsellSheet.show(
                    context: context,
                    title: 'Auto-Refill Locked 🔒',
                    description:
                        'Auto-Refill executes automatically with secure top-up and is exclusive to Premium users. Upgrade now to fully automate SIM renewal!',
                    requiredPlan: 'Premium Plan',
                    highlights: [
                      'Unlimited high-speed SIM protection lines',
                      'Zero-click Automated Auto-Refill executing balance updates',
                      'Direct balance API synchronization & validation',
                    ],
                  );
                },
                icon: const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: Colors.black,
                ),
                label: const Text(
                  'Unlock Auto-Refill with Premium',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isConfigured = schedule != null && schedule.amount > 0.0;
    final isPaused = schedule != null && !schedule.isActive;

    if (!isConfigured) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        isActive: false,
        activeColor: AppColors.healthRed,
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
                  'Auto-Refill: Unconfigured',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Premium tier features automated top-ups. Set your refill amount and frequency interval to ensure your SIM is protected.',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            if (_isViewer)
              Text(
                'Please ask the household owner to configure Auto-Refill.',
                style: AppTextStyles.caption.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () =>
                    _openScheduleSheet(context, line, null, 'refill'),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text(
                  'Configure Auto-Refill',
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
    final isPausedByHome = line.isHomeMode;
    final displayActive = schedule.isActive && !isPausedByHome;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      isActive: displayActive,
      activeColor: AppColors.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Auto-Refill Schedule',
                style: AppTextStyles.titleLarge.copyWith(
                  color: context.onSurfaceColor,
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
                          (displayActive
                                  ? AppColors.secondary
                                  : AppColors.warning)
                              .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            (displayActive
                                    ? AppColors.secondary
                                    : AppColors.warning)
                                .withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      displayActive
                          ? 'ACTIVE'
                          : (isPausedByHome ? 'PAUSED (HOME MODE)' : 'PAUSED'),
                      style: TextStyle(
                        color: displayActive
                            ? AppColors.secondary
                            : AppColors.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassToggleSwitch(
                    value: displayActive,
                    activeColor: AppColors.secondary,
                    onChanged: _isViewer || _isToggling || isPausedByHome
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
            context,
            'Recharge Amount',
            '\$${schedule.amount.toStringAsFixed(2)} ${schedule.currency}',
            Icons.monetization_on_outlined,
          ),
          const SizedBox(height: 12),
          _buildScheduleRowItem(
            context,
            'Refill Interval',
            schedule.frequencyDays == 0
                ? 'Every 1 hour'
                : 'Every ${schedule.frequencyDays} days',
            Icons.repeat,
          ),
          const SizedBox(height: 12),
          _buildScheduleRowItem(
            context,
            'Next Refill Due',
            isPausedByHome
                ? 'Paused (Home Mode)'
                : dateFormat.format(schedule.nextExecutionAt),
            Icons.date_range,
            valueColor: isPausedByHome ? AppColors.warning : null,
          ),
          if (schedule.retryCount > 0) ...[
            const SizedBox(height: 12),
            _buildScheduleRowItem(
              context,
              'Failed Refill Attempts',
              '${schedule.retryCount} / 4 retries',
              Icons.warning_amber_rounded,
              valueColor: AppColors.healthRed,
            ),
          ],
          if (!_isViewer) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14.0),
              child: Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 1),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _openScheduleSheet(context, line, schedule, 'refill'),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: context.onSurfaceColor,
                    ),
                    label: Text(
                      'Edit Refill Amount',
                      style: TextStyle(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  onPressed: () => _showDeleteScheduleConfirmation(
                    context,
                    schedule.id,
                    true,
                  ),
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
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    final isDark = context.isDarkMode;
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: valueColor ?? context.onSurfaceColor,
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
    final userProfile = ref.read(authControllerProvider).valueOrNull;
    final isPremium =
        detail.simLine.protectionTier.toLowerCase() == 'premium' ||
        (userProfile != null &&
            userProfile.subscriptionTier.toLowerCase() == 'premium');
    final isDark = context.isDarkMode;

    if (!isPremium) {
      return const SizedBox.shrink();
    }

    final list = detail.executions.where((ex) {
      final txId = ex.reloadlyTransactionId;
      if (txId != null && txId.toUpperCase().contains('MOCK')) {
        return false;
      }
      return true;
    }).take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.lightPrimary.withOpacity(0.04),
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
                ? 'Refill Executions History'
                : 'Renewal Executions History',
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
                    ? 'No historical top-up executions recorded for this line yet.'
                    : 'No historical renewal executions recorded for this line yet.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (context, index) =>
                  Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 16),
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
                              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                            ),
                          ),
                          if (ex.reloadlyTransactionId != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Tx ID: ${ex.reloadlyTransactionId}',
                              style: AppTextStyles.caption.copyWith(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
                  color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                ),
                label: Text(
                  'View All History',
                  style: TextStyle(
                    color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
    final list = detail.activityLogs.where((log) {
      if (log.metadata['is_mock'] == true ||
          log.metadata['is_mock'] == 'true' ||
          (log.description != null &&
              log.description!.toUpperCase().contains('MOCK'))) {
        return false;
      }
      return true;
    }).take(13).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.lightPrimary.withOpacity(0.04),
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
                  'Security Activity Logs',
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
                    color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                  ),
                  label: Text(
                    'Clear Logs',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
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
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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

                Color iconColor = isDark ? AppColors.primaryLight : AppColors.lightPrimary;
                IconData iconData = Icons.info_outline;

                if (log.eventType == 'topup_success') {
                  iconColor = AppColors.success;
                  iconData = Icons.check_circle_outline;
                } else if (log.eventType == 'topup_failed') {
                  iconColor = AppColors.error;
                  iconData = Icons.error_outline;
                } else if (log.eventType == 'health_update') {
                  iconColor = isDark ? AppColors.secondary : AppColors.lightSecondary;
                  iconData = Icons.shield_outlined;
                } else if (log.eventType == 'created') {
                  iconColor = isDark ? AppColors.primaryLight : AppColors.lightPrimary;
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
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
                                color: context.onSurfaceColor,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: AppTextStyles.caption.copyWith(
                                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
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
                            icon: Icon(
                              Icons.delete_outline,
                              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
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
        existingSchedule: existingSchedule,
        configMode: configMode,
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
        if (context.mounted) {
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
        throw Exception(result.error.message);
      }
    } catch (e) {
      if (context.mounted) {
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
    bool isPremium,
  ) {
    final isDark = context.isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
              style: AppTextStyles.headlineSmall.copyWith(color: context.onSurfaceColor),
            ),
          ],
        ),
        content: Text(
          isPremium
              ? 'Are you sure you want to delete this auto-refill schedule? Your SIM health score will drop significantly, risking deactivation.'
              : 'Are you sure you want to delete this auto-renewal schedule? Your SIM health score will drop significantly, risking deactivation.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Since they are now two completely separate database records,
                // deleting either Auto-Notify or Auto-Refill simply removes its specific record completely!
                final result = await ref
                    .read(scheduledTopupControllerProvider.notifier)
                    .removeSchedule(scheduleId);
                if (result is Success<void>) {
                  ref.invalidate(simLineDetailControllerProvider(widget.id));
                  ref.invalidate(simLinesControllerProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isPremium
                              ? 'Auto-refill schedule removed successfully.'
                              : 'Auto-renewal schedule removed successfully.',
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } else if (result is Failure<void>) {
                  throw Exception(result.error.message);
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
      if (context.mounted) {
        if (result is Success<void>) {
          final detailState = ref
              .read(simLineDetailControllerProvider(widget.id))
              .valueOrNull;
          final userProfile = ref.read(authControllerProvider).valueOrNull;
          final isPremium =
              detailState?.simLine.protectionTier.toLowerCase() == 'premium' ||
              (userProfile != null &&
                  userProfile.subscriptionTier.toLowerCase() == 'premium');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isPremium
                    ? 'Refill retry completed successfully!'
                    : 'Renewal retry completed successfully!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (result is Failure<void>) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Retry failed: ${result.error.message}',
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
            content: Text('Retry execution error: $e'),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity log entry deleted.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
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
          .clearAllActivityLogs();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity logs cleared successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear activity logs: $e'),
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
    final isDark = context.isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
              style: AppTextStyles.headlineSmall.copyWith(color: context.onSurfaceColor),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to stop keeping ${line.nickname ?? line.phoneNumber} protected? Scheduled top-ups for this SIM line will be permanently cancelled.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
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
                    content: Text('SIM line protection removed successfully.'),
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
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildP2PRechargeRequestCard(BuildContext context, SimLine line) {
    final userProfile = ref.read(authControllerProvider).valueOrNull;
    final isDark = context.isDarkMode;
    final bool isBasic =
        line.protectionTier.toLowerCase() == 'basic' &&
        (userProfile == null ||
            (userProfile.subscriptionTier.toLowerCase() != 'premium' &&
                userProfile.subscriptionTier.toLowerCase() != 'standard'));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.lightPrimary.withOpacity(0.04),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.primary : AppColors.lightPrimary).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.ios_share_rounded,
                  color: isDark ? AppColors.primaryLight : AppColors.lightPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Recharge from a Friend',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isBasic
                ? 'Running low or need help extending validity? Request a recharge directly on Telegram and ask a friend or family member to recharge this card for you.'
                : 'Running low or need help extending validity? Request a recharge directly on WhatsApp or Telegram and ask a friend or family member to recharge this card for you.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          if (!isBasic) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await HapticHelper.lightTick();
                  final phone = line.phoneNumber;
                  final templateText =
                      'Hi! My KeepSIMs card ($phone) is expiring soon. Could you please recharge it for me?. Thank you!';
                  final waUrl =
                      'https://wa.me/?text=${Uri.encodeComponent(templateText)}';
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
                icon: const Icon(
                  Icons.chat_rounded,
                  color: Color(0xFF25D366),
                  size: 18,
                ),
                label: const Text(
                  'Request via WhatsApp',
                  style: TextStyle(
                    color: Color(0xFF25D366),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366).withOpacity(0.12),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: const Color(0xFF25D366).withOpacity(0.2),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await HapticHelper.lightTick();
                final phone = line.phoneNumber;
                final templateText =
                    'Hi! My KeepSIMs card ($phone) is expiring soon. Could you please recharge it for me?. Thank you!';
                final tgAppUri = Uri.parse(
                  'tg://msg?text=${Uri.encodeComponent(templateText)}',
                );
                final tgWebUri = Uri.parse(
                  'https://t.me/share/url?url=https://keepsims.com&text=${Uri.encodeComponent(templateText)}',
                );
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
                          content: Text('Could not launch Telegram link: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(
                Icons.telegram_rounded,
                color: Color(0xFF0088CC),
                size: 18,
              ),
              label: const Text(
                'Request via Telegram',
                style: TextStyle(
                  color: Color(0xFF0088CC),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0088CC).withOpacity(0.12),
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: const Color(0xFF0088CC).withOpacity(0.2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
