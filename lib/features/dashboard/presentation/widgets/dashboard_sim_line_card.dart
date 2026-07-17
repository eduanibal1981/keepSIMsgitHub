import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/widgets/glass_card.dart';
import 'package:keep_sims/core/widgets/glass_toggle_switch.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/manual_refill_bottom_sheet.dart';
import 'package:keep_sims/features/sim_lines/domain/sim_line_health.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

import '../../../sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart';

class DashboardSimLineCard extends ConsumerWidget {
  final SimLine line;

  const DashboardSimLineCard({super.key, required this.line});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifySchedule = ref.watch(scheduledNotifyForLineProvider(line.id));
    final miniSchedule = ref.watch(scheduledMiniRefillForLineProvider(line.id));
    final customSchedule = ref.watch(
      scheduledCustomRefillForLineProvider(line.id),
    );
    final refillSchedule = customSchedule ?? miniSchedule;
    final user = ref.watch(authControllerProvider).value;
    final isLight = Theme.of(context).brightness == Brightness.light;

    bool isPremium = line.protectionTier.toLowerCase() == 'premium';

    bool isNotifyActive =
        notifySchedule != null && notifySchedule.status == 'active';
    bool isRefillActive =
        (miniSchedule != null && miniSchedule.status == 'active') ||
        (customSchedule != null && customSchedule.status == 'active');

    bool hasProtectionActive = isPremium ? isRefillActive : isNotifyActive;

    final int computedHealthScore = line.displayHealthScore(
      isPremium: isPremium,
      hasProtectionActive: hasProtectionActive,
    );

    Color glowColor = AppColors.healthGreen;
    if (line.protectionPaused) {
      glowColor = Colors.lightBlue;
    } else if (computedHealthScore < 30) {
      glowColor = AppColors.healthRed;
    } else if (computedHealthScore < 60) {
      glowColor = AppColors.healthAmber;
    }

    return GestureDetector(
      onTap: () async {
        await HapticHelper.lightTick();
        if (context.mounted) {
          context.push('/sim-lines/detail/${line.id}');
        }
      },
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        isActive: true,
        activeColor: glowColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Options and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasProtectionActive
                            ? AppColors.success
                            : AppColors.healthRed,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (hasProtectionActive
                                        ? AppColors.success
                                        : AppColors.healthRed)
                                    .withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasProtectionActive
                          ? AppLocalizations.of(context)!.active
                          : 'Inactive',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: hasProtectionActive
                            ? AppColors.success
                            : AppColors.healthRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    popupMenuTheme: PopupMenuThemeData(
                      color: isLight ? AppColors.lightCard : AppColors.darkCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isLight
                              ? AppColors.lightBorder
                              : AppColors.darkBorder,
                        ),
                      ),
                    ),
                  ),
                  child: SizedBox(
                    height: 24, // Keep it compact to match the label size
                    width: 24,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: isLight
                            ? AppColors.textSecondaryLight
                            : AppColors.textSecondaryDark,
                        size: 20,
                      ),
                      onSelected: (value) async {
                        if (value == 'config') {
                          context.push('/sim-lines/detail/${line.id}');
                        } else if (value == 'delete') {
                          final bool confirm =
                              await showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    backgroundColor: isLight
                                        ? AppColors.lightCard
                                        : AppColors.darkCard,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isLight
                                            ? AppColors.lightBorder
                                            : AppColors.darkBorder,
                                      ),
                                    ),
                                    title: Text(
                                      'Delete SIM Line?',
                                      style: AppTextStyles.titleLarge.copyWith(
                                        color: isLight
                                            ? AppColors.textPrimaryLight
                                            : Colors.white,
                                      ),
                                    ),
                                    content: Text(
                                      'Are you sure you want to delete ${line.nickname ?? line.phoneNumber}? This action cannot be undone.',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: isLight
                                            ? AppColors.textSecondaryLight
                                            : AppColors.textSecondaryDark,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text(
                                          'Cancel',
                                          style: AppTextStyles.labelLarge
                                              .copyWith(
                                                color: isLight
                                                    ? AppColors.lightPrimary
                                                    : AppColors.primary,
                                              ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text(
                                          'Delete',
                                          style: AppTextStyles.labelLarge
                                              .copyWith(
                                                color: AppColors.healthRed,
                                              ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ) ??
                              false;

                          if (confirm) {
                            await ref
                                .read(simLinesControllerProvider.notifier)
                                .deleteSimLine(line.id);
                          }
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem(
                          value: 'config',
                          child: Row(
                            children: [
                              Icon(
                                Icons.settings_outlined,
                                color: isLight
                                    ? AppColors.textPrimaryLight
                                    : Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Configuration',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isLight
                                      ? AppColors.textPrimaryLight
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_outline,
                                color: AppColors.healthRed,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Delete',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.healthRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // SIM Nickname
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.nickname ?? 'SIM Line',
                    style: AppTextStyles.headlineMedium.copyWith(
                      // color: glowColor,
                      color: isLight
                          ? AppColors.textPrimaryLight
                          : Colors.white,
                      fontWeight: FontWeight.w800,
                      shadows: isLight
                          ? null
                          : [
                              Shadow(
                                color: glowColor.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: line.planType == 'premium'
                        ? const Color(0xFFFFF3E0) // Light orange background
                        : line.planType == 'standard'
                        ? const Color(0xFFE1F5FE) // Light blue background
                        : const Color(0xFFF5F5F5), // Light grey background
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: line.planType == 'premium'
                          ? const Color(0xFFFFB74D) // Orange border
                          : line.planType == 'standard'
                          ? const Color(0xFF4FC3F7) // Blue border
                          : Colors.grey.shade400, // Grey border
                    ),
                  ),
                  child: Text(
                    line.planType.toLowerCase() == 'standard'
                        ? AppLocalizations.of(context)!.standard
                        : line.planType.toUpperCase(),
                    style: AppTextStyles.caption.copyWith(
                      color: line.planType == 'premium'
                          ? const Color(0xFFE65100) // Dark orange text
                          : line.planType == 'standard'
                          ? const Color(0xFF0277BD) // Dark blue text
                          : Colors.grey.shade700, // Dark grey text
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (line.planType != 'premium') ...[
                  const SizedBox(width: 8),
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
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amberAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.rocket_launch_rounded,
                            size: 10,
                            color: Colors.orangeAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppLocalizations.of(context)!.upgrade,
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),

            // Phone Number
            Text(
              line.phoneNumber,
              style: AppTextStyles.titleMedium.copyWith(
                color: isLight
                    ? AppColors.lightPrimary
                    : glowColor.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 20),

            // Divider
            Divider(
              color: isLight ? AppColors.lightBorder : AppColors.darkBorder,
              thickness: 1,
              height: 1,
            ),
            const SizedBox(height: 16),

            // Auto-Notify Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.autoNotify,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isLight
                          ? AppColors.textPrimaryLight
                          : Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                notifySchedule != null
                    ? GlassToggleSwitch(
                        value: isNotifyActive,
                        activeColor: AppColors.success,
                        onChanged: (val) async {
                          await HapticHelper.lightTick();
                          await ref
                              .read(scheduledTopupControllerProvider.notifier)
                              .toggleActive(notifySchedule.id, val);
                        },
                      )
                    : GestureDetector(
                        onTap: () async {
                          await HapticHelper.lightTick();
                          if (context.mounted) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => ScheduledTopupSheet(
                                simLineId: line.id,
                                simNickname: line.nickname ?? line.phoneNumber,
                                existingSchedule: notifySchedule,
                                configMode: 'notify',
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isLight
                                        ? AppColors.lightPrimary
                                        : AppColors.primary)
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  (isLight
                                          ? AppColors.lightPrimary
                                          : AppColors.primary)
                                      .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.configure,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: isLight
                                  ? AppColors.lightPrimary
                                  : AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 12),

            // Auto-Refill Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context)!.autoRefill,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isLight
                                ? AppColors.textPrimaryLight
                                : Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isPremium) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF59E0B),
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Opacity(
                  opacity: 1.0,
                  child: refillSchedule != null
                      ? GlassToggleSwitch(
                          value: isPremium ? isRefillActive : false,
                          activeColor: AppColors.success,
                          onChanged: (val) async {
                            await HapticHelper.lightTick();
                            if (!isPremium) {
                              LineUpgradeSheet.show(
                                context: context,
                                simLine: line,
                              );
                              return;
                            }
                            await ref
                                .read(scheduledTopupControllerProvider.notifier)
                                .toggleActive(refillSchedule.id, val);
                          },
                        )
                      : GestureDetector(
                          onTap: () async {
                            await HapticHelper.lightTick();
                            if (!isPremium) {
                              LineUpgradeSheet.show(
                                context: context,
                                simLine: line,
                              );
                              return;
                            }
                            if (context.mounted) {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => ScheduledTopupSheet(
                                  simLineId: line.id,
                                  simNickname:
                                      line.nickname ?? line.phoneNumber,
                                  existingSchedule: refillSchedule,
                                  configMode: 'refill',
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (isLight
                                          ? AppColors.lightPrimary
                                          : AppColors.primary)
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    (isLight
                                            ? AppColors.lightPrimary
                                            : AppColors.primary)
                                        .withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.configure,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: isLight
                                    ? AppColors.lightPrimary
                                    : AppColors.primaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),

            // Recharge Now (C3) — the same instant-refill sheet the line detail
            // screen opens, surfaced one tap from the dashboard.
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                await HapticHelper.lightTick();
                if (!context.mounted) return;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ManualRefillBottomSheet(simLine: line),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)!.rechargeNow,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isLight
                            ? const Color(0xFFB45309)
                            : Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
