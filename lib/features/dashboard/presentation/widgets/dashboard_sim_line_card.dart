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

import '../../../sim_lines/presentation/controllers/sim_lines_controller.dart';

class DashboardSimLineCard extends ConsumerWidget {
  final SimLine line;

  const DashboardSimLineCard({
    super.key,
    required this.line,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifySchedule = ref.watch(scheduledNotifyForLineProvider(line.id));
    final refillSchedule = ref.watch(scheduledRefillForLineProvider(line.id));
    final user = ref.watch(authControllerProvider).valueOrNull;
    final isLight = Theme.of(context).brightness == Brightness.light;

    bool isPremium = line.protectionTier.toLowerCase() == 'premium' ||
        (user != null && user.subscriptionTier.toLowerCase() == 'premium');

    bool isNotifyActive = notifySchedule != null && notifySchedule.status == 'active';
    bool isRefillActive = refillSchedule != null && refillSchedule.status == 'active';

    bool hasProtectionActive = isPremium ? isRefillActive : isNotifyActive;

    bool isVerified = line.status == 'active';
    bool recentRefill =
        line.lastTopupAt != null &&
        DateTime.now().difference(line.lastTopupAt!).inDays <= 80;

    int computedHealthScore = line.isHomeMode
        ? 100
        : (!isPremium
            ? (hasProtectionActive ? 100 : 0)
            : ((hasProtectionActive ? 50 : 0) +
                (isVerified ? 25 : 0) +
                (recentRefill ? 25 : 0)));

    Color glowColor = AppColors.healthGreen;
    if (line.isHomeMode) {
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
                            color: (hasProtectionActive
                                    ? AppColors.success
                                    : AppColors.healthRed)
                                .withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasProtectionActive ? 'Active' : 'Inactive',
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
                        side: BorderSide(color: isLight ? AppColors.lightBorder : AppColors.darkBorder),
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
                        color: isLight ? AppColors.textSecondaryLight : AppColors.textSecondaryDark,
                        size: 20,
                      ),
                      onSelected: (value) async {
                        if (value == 'config') {
                          context.push('/sim-lines/detail/${line.id}');
                        } else if (value == 'delete') {
                          final bool confirm = await showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    backgroundColor: isLight ? AppColors.lightCard : AppColors.darkCard,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(color: isLight ? AppColors.lightBorder : AppColors.darkBorder),
                                    ),
                                    title: Text(
                                      'Delete SIM Line?',
                                      style: AppTextStyles.titleLarge.copyWith(color: isLight ? AppColors.textPrimaryLight : Colors.white),
                                    ),
                                    content: Text(
                                      'Are you sure you want to delete ${line.nickname ?? line.phoneNumber}? This action cannot be undone.',
                                      style: AppTextStyles.bodyMedium.copyWith(color: isLight ? AppColors.textSecondaryLight : AppColors.textSecondaryDark),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: Text(
                                          'Cancel',
                                          style: AppTextStyles.labelLarge.copyWith(color: isLight ? AppColors.lightPrimary : AppColors.primary),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: Text(
                                          'Delete',
                                          style: AppTextStyles.labelLarge.copyWith(color: AppColors.healthRed),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ) ??
                              false;

                          if (confirm) {
                            await ref.read(simLinesControllerProvider.notifier).deleteSimLine(line.id);
                          }
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem(
                          value: 'config',
                          child: Row(
                            children: [
                              Icon(Icons.settings_outlined, color: isLight ? AppColors.textPrimaryLight : Colors.white, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'Configuration',
                                style: AppTextStyles.bodyMedium.copyWith(color: isLight ? AppColors.textPrimaryLight : Colors.white),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline, color: AppColors.healthRed, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'Delete',
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.healthRed),
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
            Text(
              line.nickname ?? 'SIM Line',
              style: AppTextStyles.headlineMedium.copyWith(
               // color: glowColor,
                color: isLight ? AppColors.textPrimaryLight : Colors.white,
                fontWeight: FontWeight.w800,
                shadows: isLight ? null : [
                  Shadow(
                    color: glowColor.withOpacity(0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Phone Number
            Text(
              line.phoneNumber,
              style: AppTextStyles.titleMedium.copyWith(
                color: isLight ? AppColors.lightPrimary : glowColor.withOpacity(0.9),
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
                Text(
                  'Auto-Notify',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isLight ? AppColors.textPrimaryLight : Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                notifySchedule != null
                    ? GlassToggleSwitch(
                        value: isNotifyActive,
                        activeColor: AppColors.success,
                        onChanged: (val) async {
                          await HapticHelper.lightTick();
                          await ref.read(scheduledTopupControllerProvider.notifier).toggleActive(notifySchedule.id, val);
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isLight ? AppColors.lightPrimary : AppColors.primary).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (isLight ? AppColors.lightPrimary : AppColors.primary).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Configure',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: isLight ? AppColors.lightPrimary : AppColors.primaryLight,
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
                Row(
                  children: [
                    Text(
                      'Auto-Refill',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isPremium
                            ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                            : (isLight ? AppColors.textTertiaryLight : AppColors.textTertiaryDark),
                        fontWeight: FontWeight.w500,
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
                Opacity(
                  opacity: isPremium ? 1.0 : 0.5,
                  child: refillSchedule != null
                      ? GlassToggleSwitch(
                          value: isPremium ? isRefillActive : false,
                          activeColor: AppColors.success,
                          onChanged: !isPremium
                              ? null
                              : (val) async {
                                  await HapticHelper.lightTick();
                                  await ref.read(scheduledTopupControllerProvider.notifier).toggleActive(refillSchedule.id, val);
                                },
                        )
                      : GestureDetector(
                          onTap: !isPremium
                              ? null
                              : () async {
                                  await HapticHelper.lightTick();
                                  if (context.mounted) {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => ScheduledTopupSheet(
                                        simLineId: line.id,
                                        simNickname: line.nickname ?? line.phoneNumber,
                                        existingSchedule: refillSchedule,
                                        configMode: 'refill',
                                      ),
                                    );
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: (isLight ? AppColors.lightPrimary : AppColors.primary).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (isLight ? AppColors.lightPrimary : AppColors.primary).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Configure',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: isLight ? AppColors.lightPrimary : AppColors.primaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
