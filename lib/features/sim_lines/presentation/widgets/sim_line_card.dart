import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:keep_sims/core/services/destructive_action_guard.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/domain/sim_line_health.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';

class SimLineCard extends ConsumerWidget {
  final SimLine line;
  final Country? country;
  final Carrier? carrier;
  final bool isShared;
  final bool isSelected;
  final bool isSelectMode;
  final HouseholdState? householdState;
  final bool showActions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final int? index;

  const SimLineCard({
    super.key,
    required this.line,
    this.country,
    this.carrier,
    this.isShared = false,
    this.isSelected = false,
    this.isSelectMode = false,
    this.householdState,
    this.showActions = true,
    this.onTap,
    this.onLongPress,
    this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Resolve country ──────────────────────────────────────────
    final resolvedCountry =
        country ??
        ref
            .watch(supportedCountriesProvider)
            .value
            ?.firstWhereOrNull((c) => c.id == line.countryId);

    // ── Schedule state ───────────────────────────────────────────
    final notifySchedule = ref.watch(scheduledNotifyForLineProvider(line.id));
    final miniSchedule = ref.watch(scheduledMiniRefillForLineProvider(line.id));
    final customSchedule = ref.watch(
      scheduledCustomRefillForLineProvider(line.id),
    );
    final user = ref.watch(authControllerProvider).value;

    final bool isPremium =
        line.protectionTier.toLowerCase() == 'premium' ||
        (user != null && user.isPowerUser);

    final bool isNotifyActive =
        notifySchedule != null && notifySchedule.isActive;
    final bool isMiniActive = miniSchedule != null && miniSchedule.isActive;
    final bool isCustomActive =
        customSchedule != null && customSchedule.isActive;

    // ── Health / glow ────────────────────────────────────────────
    final bool isRefillActive = isMiniActive || isCustomActive;
    final bool isVerified = line.status == 'active' ||
        line.isCarrierVerified ||
        line.carrierVerifiedAt != null ||
        line.verificationStatus == 'verified';

    final int computedHealthScore = line.displayHealthScore(
      hasRefillSchedule: isRefillActive,
      hasNotificationSchedule: isNotifyActive,
      isVerified: isVerified,
    );

    Color glowColor = AppColors.healthGreen;
    if (isSelected) {
      glowColor = AppColors.primary;
    } else if (computedHealthScore < 30) {
      glowColor = AppColors.healthRed;
    } else if (computedHealthScore < 60) {
      glowColor = AppColors.healthAmber;
    }

    final bool hasError = computedHealthScore < 30;
    final isDark = context.isDarkMode;

    // ── Card background ──────────────────────────────────────────
    final cardBg = isSelected
        ? (isDark ? const Color(0xFF0D1F33) : const Color(0xFFE8F4FD))
        : (isDark ? const Color(0xFF192029) : Colors.white);

    final cardBorderColor = isSelected
        ? glowColor.withValues(alpha: 0.6)
        : hasError
        ? AppColors.healthRed.withValues(alpha: isDark ? 0.4 : 0.35)
        : (isDark
              ? AppColors.darkBorder
              : AppColors.lightBorder.withValues(alpha: 0.5));

    return GestureDetector(
      onLongPress: isShared
          ? null
          : () async {
              await HapticHelper.mediumImpact();
              if (onLongPress != null) onLongPress!();
            },
      onTap: () async {
        await HapticHelper.lightTick();
        if (onTap != null) {
          onTap!();
        } else {
          if (context.mounted) {
            context.push('/sim-lines/detail/${line.id}');
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: isDark ? 0.12 : 0.06),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left accent bar ─────────────────────────────
                Container(width: 4, color: glowColor),

                // ── Card content ────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header row ───────────────────────────
                        _buildHeader(
                          context,
                          ref,
                          resolvedCountry,
                          glowColor,
                          isPremium,
                          notifySchedule,
                          miniSchedule,
                        ),

                        // ── Shared-by label ──────────────────────
                        if (isShared) ...[
                          const SizedBox(height: 6),
                          _buildSharedByLabel(context),
                        ],

                        const SizedBox(height: 12),

                        // ── Divider ──────────────────────────────
                        Divider(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder.withValues(alpha: 0.5),
                          height: 1,
                        ),
                        const SizedBox(height: 10),

                        // ── Info grid row ────────────────────────
                        _buildInfoGrid(
                          context,
                          hasError,
                          notifySchedule,
                          isDark,
                        ),

                        const SizedBox(height: 10),

                        // ── Divider ──────────────────────────────
                        Divider(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder.withValues(alpha: 0.5),
                          height: 1,
                        ),
                        const SizedBox(height: 10),

                        // ── Protection chips ─────────────────────
                        _buildProtectionChips(
                          context,
                          isNotifyActive,
                          isMiniActive,
                          isCustomActive,
                          isPremium,
                          isDark,
                        ),
                      ],
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

  // ── HEADER ───────────────────────────────────────────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    Country? resolvedCountry,
    Color glowColor,
    bool isPremium,
    ScheduledTopup? notifySchedule,
    ScheduledTopup? miniSchedule,
  ) {
    final isDark = context.isDarkMode;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Select checkbox
        if (isSelectMode) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 10, top: 8),
            child: Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? AppColors.primary
                  : context.onSurfaceColor.withValues(alpha: 0.5),
              size: 22,
            ),
          ),
        ],

        // Avatar with status dot
        _buildAvatar(context, resolvedCountry, glowColor),
        const SizedBox(width: 12),

        // Info column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nickname + plan badge row
              Row(
                children: [
                  Flexible(
                    child: Text(
                      line.nickname ?? 'My SIM Card',
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: isDark
                            ? Colors.white
                            : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildPlanBadge(context, line.protectionTier),
                ],
              ),
              const SizedBox(height: 3),

              // Phone number
              Text(
                line.phoneNumber,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.primaryLight
                      : AppColors.lightPrimary,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),

              // Country + carrier chip row
              Row(
                children: [
                  if (resolvedCountry != null) ...[
                    Text(
                      resolvedCountry.name,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                    if (carrier != null)
                      Text(
                        ' · ',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      ),
                  ],
                  if (carrier != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0x1A4CD7F6)
                              : const Color(0x1500647C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          carrier!.name,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.primaryLight
                                : AppColors.lightPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                ],
              ),

              // Upgrade button (non-premium only)
              if (!isPremium) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    await HapticHelper.mediumImpact();
                    if (context.mounted) {
                      LineUpgradeSheet.show(context: context, simLine: line);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.amberAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.rocket_launch_rounded,
                          size: 10,
                          color: Colors.orangeAccent,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'UPGRADE',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
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

        // Action buttons (own cards only)
        if (!isShared) ...[
          GestureDetector(
            onTap: () {
              if (onTap != null) {
                onTap!();
              } else {
                context.push('/sim-lines/detail/${line.id}');
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.settings_outlined,
                size: 18,
                color: context.onSurfaceColor.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 2),

          if (showActions)
            SizedBox(
              width: 28,
              height: 28,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: context.onSurfaceColor.withValues(alpha: 0.5),
                ),
                color: isDark ? AppColors.darkCard : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                onSelected: (value) {
                  if (value == 'delete') {
                    _showDeleteConfirmation(context, ref, line);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Delete Protection',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  // ── AVATAR ───────────────────────────────────────────────────────────────────
  Widget _buildAvatar(
    BuildContext context,
    Country? country,
    Color statusColor,
  ) {
    final String flag = country?.flagEmoji ?? '🌐';
    final isDark = context.isDarkMode;

    IconData getIcon() {
      switch (line.avatarIcon) {
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF232A34) : AppColors.lightBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder.withValues(alpha: 0.6),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(getIcon(), color: AppColors.primaryLight, size: 22),
              Positioned(
                bottom: 2,
                right: 2,
                child: Text(flag, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        // Status dot badge
        Positioned(
          top: -3,
          right: -3,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? const Color(0xFF192029) : Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── PLAN BADGE ───────────────────────────────────────────────────────────────
  Widget _buildPlanBadge(BuildContext context, String tier) {
    final normalized = tier.toLowerCase();
    final isDark = context.isDarkMode;

    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (normalized) {
      case 'premium':
        bgColor = isDark ? const Color(0x33FFD700) : const Color(0x1A2E7D32);
        textColor = isDark ? const Color(0xFFFFD700) : const Color(0xFF2E7D32);
        label = 'Premium';
        icon = Icons.workspace_premium;
      case 'standard':
        bgColor = isDark ? const Color(0x222196F3) : const Color(0x151565C0);
        textColor = isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
        label = 'Standard';
        icon = Icons.verified_outlined;
      default:
        bgColor = isDark ? const Color(0x22888888) : const Color(0x12616161);
        textColor = isDark ? const Color(0xFFBDBDBD) : const Color(0xFF616161);
        label = 'Free';
        icon = Icons.local_offer_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── INFO GRID ────────────────────────────────────────────────────────────────
  Widget _buildInfoGrid(
    BuildContext context,
    bool hasError,
    ScheduledTopup? notifySchedule,
    bool isDark,
  ) {
    final dateFormat = DateFormat('MMM dd');
    final labelStyle = AppTextStyles.caption.copyWith(
      color: hasError
          ? AppColors.healthRed.withValues(alpha: 0.8)
          : context.onSurfaceColor.withValues(alpha: 0.45),
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );
    final valueStyle = AppTextStyles.bodySmall.copyWith(
      color: hasError ? AppColors.healthRed : context.onSurfaceColor,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    );

    final String lastRefillStr = line.lastTopupAt == null
        ? AppLocalizations.of(context)!.noRefillYet
        : dateFormat.format(line.lastTopupAt!);

    final gridBg = hasError
        ? AppColors.healthRed.withValues(alpha: isDark ? 0.08 : 0.06)
        : (isDark ? const Color(0x0CFFFFFF) : const Color(0x06000000));

    final gridBorder = hasError
        ? AppColors.healthRed.withValues(alpha: 0.2)
        : (isDark
              ? AppColors.darkBorder
              : AppColors.lightBorder.withValues(alpha: 0.4));

    // Left cell
    final Widget leftCell;
    if (hasError) {
      leftCell = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.actionRequiredLabel,
            style: labelStyle,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: AppColors.healthRed,
              ),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context)!.protectionOffLabel,
                style: valueStyle,
              ),
            ],
          ),
        ],
      );
    } else {
      final String nextAlertStr = notifySchedule == null
          ? AppLocalizations.of(context)!.notSet
          : dateFormat.format(notifySchedule.nextExecutionAt);
      leftCell = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 10,
                color: context.onSurfaceColor.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context)!.nextAlertLabel,
                style: labelStyle,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(nextAlertStr, style: valueStyle),
        ],
      );
    }

    final rightCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history,
              size: 10,
              color: context.onSurfaceColor.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context)!.lastRefillLabel,
              style: labelStyle,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(lastRefillStr, style: valueStyle),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: gridBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gridBorder, width: 1),
      ),
      child: Row(
        children: [
          Expanded(child: leftCell),
          Container(
            width: 1,
            height: 32,
            color: gridBorder,
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),
          Expanded(child: rightCell),
        ],
      ),
    );
  }

  // ── PROTECTION CHIPS ─────────────────────────────────────────────────────────
  Widget _buildProtectionChips(
    BuildContext context,
    bool isNotifyActive,
    bool isMiniActive,
    bool isCustomActive,
    bool isPremium,
    bool isDark,
  ) {
    final labelStyle = AppTextStyles.caption.copyWith(
      color: context.onSurfaceColor.withValues(alpha: 0.45),
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    );

    Widget chip(String label, bool active, Color activeColor) {
      final chipBg = active
          ? activeColor.withValues(alpha: isDark ? 0.18 : 0.12)
          : (isDark ? const Color(0x0CFFFFFF) : const Color(0x08000000));
      final chipBorder = active
          ? activeColor.withValues(alpha: isDark ? 0.4 : 0.3)
          : (isDark
                ? AppColors.darkBorder
                : AppColors.lightBorder.withValues(alpha: 0.4));
      final chipText = active
          ? activeColor
          : context.onSurfaceColor.withValues(alpha: 0.35);
      final dotColor = active
          ? activeColor
          : context.onSurfaceColor.withValues(alpha: 0.3);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chipBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: chipText,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Text(
          '${AppLocalizations.of(context)!.protectionLabel}: ',
          style: labelStyle,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip(
                  AppLocalizations.of(context)!.autoNotify,
                  isNotifyActive,
                  AppColors.success,
                ),
                const SizedBox(width: 6),
                chip(
                  AppLocalizations.of(context)!.autoRefill,
                  isPremium && (isMiniActive || isCustomActive),
                  AppColors.primary,
                ),
                if (isCustomActive) ...[
                  const SizedBox(width: 6),
                  chip('Custom Refill', true, AppColors.secondary),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── SHARED-BY LABEL ──────────────────────────────────────────────────────────
  Widget _buildSharedByLabel(BuildContext context) {
    final ownerName =
        householdState?.memberships
            .firstWhereOrNull((m) => m.ownerId == line.userId)
            ?.ownerName ??
        'Family Member';
    return Row(
      children: [
        const Icon(
          Icons.people_outline,
          color: AppColors.primaryLight,
          size: 12,
        ),
        const SizedBox(width: 4),
        Text(
          'Shared by: $ownerName',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.primaryLight,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ── DELETE DIALOG ────────────────────────────────────────────────────────────
  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    SimLine line,
  ) async {
    // Captured before any await; the builder's context is dead once popped.
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: context.dividerColor),
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
                color: context.onSurfaceColor,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to stop keeping '
          '${line.nickname ?? line.phoneNumber} protected? '
          'Scheduled top-ups for this SIM line will be permanently cancelled.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.onSurfaceColor.withValues(alpha: 0.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: context.onSurfaceColor.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(
              'Delete',
              style: TextStyle(color: context.onSurfaceColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // Deleting a line is irreversible, so it is gated on the owner being
    // present. No grace window: this prompts every time.
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

    try {
      await ref.read(simLinesControllerProvider.notifier).deleteSimLine(line.id);
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
  }
}
