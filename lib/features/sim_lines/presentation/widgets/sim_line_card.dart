import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/profile/presentation/widgets/subscription_upsell_sheet.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/core/widgets/glass_card.dart';



class SimLineCard extends ConsumerWidget {
  final SimLine line;
  final Country? country;
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
    final resolvedCountry =
        country ??
        ref
            .watch(supportedCountriesProvider)
            .valueOrNull
            ?.firstWhereOrNull((c) => c.id == line.countryId);

    final notifySchedule = ref.watch(scheduledNotifyForLineProvider(line.id));
    final refillSchedule = ref.watch(scheduledRefillForLineProvider(line.id));
    final user = ref.watch(authControllerProvider).valueOrNull;
    bool isPremium = line.protectionTier.toLowerCase() == 'premium' ||
        (user != null && user.subscriptionTier.toLowerCase() == 'premium');
    bool hasProtectionActive = isPremium
        ? (refillSchedule != null && refillSchedule.status == 'active')
        : (notifySchedule != null && notifySchedule.status == 'active');
    bool isVerified = line.status == 'active';
    bool recentRefill =
        line.lastTopupAt != null &&
        DateTime.now().difference(line.lastTopupAt!).inDays <= 80;
    int computedHealthScore = line.isHomeMode ? 100 :
        (!isPremium
            ? (hasProtectionActive ? 100 : 0)
            : ((hasProtectionActive ? 50 : 0) +
               (isVerified ? 25 : 0) +
               (recentRefill ? 25 : 0)));

    final bool isAlternate = index != null && index! % 2 == 1;
    final backgroundColor = isSelected
        ? context.cardColor.withBlue(35).withGreen(10)
        : (isAlternate 
            ? (context.isDarkMode 
                ? const Color(0xFF1A1000) // Elegant deep royal plum/violet for dark mode
                : const Color.fromARGB(255, 246, 250, 215)) // Gentle, soft lavender-plum tint for light mode
            : context.cardColor);

    Color glowColor = AppColors.healthGreen;
    if (isSelected) {
      glowColor = AppColors.primary;
    } else if (line.isHomeMode) {
      glowColor = Colors.lightBlue;
    } else if (computedHealthScore < 30) {
      glowColor = AppColors.healthRed;
    } else if (computedHealthScore < 60) {
      glowColor = AppColors.healthAmber;
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.zero,
      isActive: true,
      activeColor: glowColor,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: isShared
              ? null
              : () async {
                  if (onLongPress != null) {
                    onLongPress!();
                  }
                },
          onTap: () async {
            await HapticHelper.lightTick();
            if (onTap != null) {
              onTap!();
            } else {
              context.push('/sim-lines/detail/${line.id}');
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSelectMode) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 12, top: 12),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected
                            ? AppColors.primary
                            : context.onSurfaceColor.withOpacity(0.6),
                        size: 24,
                      ),
                    ),
                  ],
                  _buildAvatar(context, line, resolvedCountry),

                  const SizedBox(width: 16),

                  // Nickname & Phone Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.nickname ?? 'My SIM Card',
                          style: AppTextStyles.headlineSmall.copyWith(
                            color: context.onSurfaceColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          line.phoneNumber,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: context.onSurfaceColor.withOpacity(0.9),
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (resolvedCountry != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            resolvedCountry.name,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ],
                        if (isShared) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.people_outline,
                                color: AppColors.primaryLight,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Shared by: ${householdState?.memberships.firstWhereOrNull((m) => m.ownerId == line.userId)?.ownerName ?? 'Family Member'}',
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

                  // Open Console Button
                  if (!isShared)
                    IconButton(
                      icon: Icon(
                        Icons.settings,
                        color: context.onSurfaceColor.withOpacity(0.6),
                      ),
                      onPressed: () {
                        if (onTap != null) {
                          onTap!();
                        } else {
                          context.push('/sim-lines/detail/${line.id}');
                        }
                      },
                      tooltip: 'Open Protection Console',
                    ),

                  // Action menu
                  if (!isShared && showActions)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: context.onSurfaceColor.withOpacity(0.6),
                      ),
                      color: context.surfaceColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          context.push('/sim-lines/edit/${line.id}');
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(context, ref, line);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit,
                                color: context.onSurfaceColor.withOpacity(0.6),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Edit Details',
                                style: TextStyle(color: context.onSurfaceColor),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete Protection',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(color: Colors.grey, height: 1),
              ),
              _buildDetailsRow(context, line, computedHealthScore),
              _buildScheduledTopupPanel(context, ref, line),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildAvatar(BuildContext context, SimLine line, Country? country) {
    String flag = '🌐';
    if (country != null) {
      flag = country.flagEmoji;
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
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.dividerColor),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            getIcon(line.avatarIcon),
            color: AppColors.primaryLight,
            size: 22,
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Text(flag, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }



  Widget _buildHealthScoreRing(BuildContext context, int score, bool isHomeMode) {
    Color color = AppColors.healthGreen;
    if (isHomeMode) {
      color = Colors.lightBlue;
    } else if (score < 30) {
      color = AppColors.healthRed;
    } else if (score < 60) {
      color = AppColors.healthAmber;
    }

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 4,
            backgroundColor: context.surfaceColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            '$score',
            style: AppTextStyles.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsRow(BuildContext context, SimLine line, int computedHealthScore) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    String getLastRefillStr() {
      if (line.lastTopupAt == null) return 'No refill yet';
      return dateFormat.format(line.lastTopupAt!);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildInfoColumn(
          context,
          'Last Refill',
          getLastRefillStr(),
          Icons.history,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  size: 12,
                  color: context.onSurfaceColor.withOpacity(0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  'Health Score',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: context.onSurfaceColor.withOpacity(0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildHealthScoreRing(context, computedHealthScore, line.isHomeMode),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoColumn(
  BuildContext context,
  String label,
  String value,
  IconData icon,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: context.onSurfaceColor.withOpacity(0.4),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: context.onSurfaceColor.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodySmall.copyWith(
          color: context.onSurfaceColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    SimLine line,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          'Are you sure you want to stop keeping ${line.nickname ?? line.phoneNumber} protected? Scheduled top-ups for this SIM line will be permanently cancelled.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.onSurfaceColor.withOpacity(0.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.onSurfaceColor.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(simLinesControllerProvider.notifier)
                    .deleteSimLine(line.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'SIM line protection removed successfully.',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(
              'Delete',
              style: TextStyle(color: context.onSurfaceColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledTopupPanel(
    BuildContext context,
    WidgetRef ref,
    SimLine line,
  ) {
    final notifySchedule = ref.watch(scheduledNotifyForLineProvider(line.id));
    final refillSchedule = ref.watch(scheduledRefillForLineProvider(line.id));
    final user = ref.watch(authControllerProvider).valueOrNull;
    final bool isPremium = line.protectionTier.toLowerCase() == 'premium' ||
        (user != null && user.subscriptionTier.toLowerCase() == 'premium');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Divider(color: context.dividerColor, height: 1),
        ),
        // 1. Auto-Notify Section (for all tiers)
        _buildAutoNotifySection(context, ref, line, notifySchedule),
        const SizedBox(height: 12),
        // 2. Auto-Refill Section (Premium active, Free/Standard locked)
        _buildAutoRefillSection(context, ref, line, refillSchedule, isPremium),
      ],
    );
  }

  Widget _buildAutoNotifySection(
    BuildContext context,
    WidgetRef ref,
    SimLine line,
    ScheduledTopup? schedule,
  ) {
    final bool isConfigured = schedule != null;
    final bool isPaused = schedule != null && !schedule.isActive;
    final dateFormat = DateFormat('MMM dd, yyyy');

    final cardColor = !isConfigured
        ? AppColors.healthRed
        : (isPaused ? AppColors.warning : AppColors.success);
    final statusIcon = !isConfigured
        ? Icons.warning_amber_rounded
        : (isPaused ? Icons.pause_circle_outline_rounded : Icons.notifications_active_rounded);

    final statusText = !isConfigured
        ? 'Auto-Notify: Disabled'
        : (isPaused ? 'Auto-Notify: Paused' : 'Auto-Notify: Active');

    final subtitleText = !isConfigured
        ? 'Critical risk of missing deactivation alerts.'
        : (isPaused
            ? 'Alert notifications are temporarily suspended'
            : (schedule.frequencyDays == 0
                ? 'Validity check & alert reminders every 1 hour'
                : 'Validity check & alert reminders every ${schedule.frequencyDays} days'));

    return GlassCard(
      padding: const EdgeInsets.all(12),
      isActive: false,
      activeColor: cardColor,
      child: Column(
        children: [
          Row(
            children: [
              Icon(statusIcon, color: cardColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: AppTextStyles.caption.copyWith(
                        color: context.onSurfaceColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isConfigured ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ScheduledTopupSheet(
                      simLineId: line.id,
                      simNickname: line.nickname ?? line.phoneNumber,
                      existingSchedule: schedule,
                      configMode: 'notify',
                    ),
                  );
                },
                tooltip: isConfigured ? 'Edit Auto-Notify' : 'Configure Auto-Notify',
              ),
            ],
          ),
          if (isConfigured && !isPaused) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next Alert Check:',
                        style: AppTextStyles.caption.copyWith(
                          color: context.onSurfaceColor.withOpacity(0.4),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateFormat.format(schedule.nextExecutionAt),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.onSurfaceColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAutoRefillSection(
    BuildContext context,
    WidgetRef ref,
    SimLine line,
    ScheduledTopup? schedule,
    bool isPremium,
  ) {
    if (!isPremium) {
      // Locked for Free/Standard
      return GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: context.isDarkMode ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-Refill: Locked 🔒',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.onSurfaceColor.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Available on Premium Plan. Automatically buy credit before expiration.',
                    style: AppTextStyles.caption.copyWith(
                      color: context.onSurfaceColor.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                await HapticHelper.mediumImpact();
                SubscriptionUpsellSheet.show(
                  context: context,
                  title: 'Auto-Refill Locked 🔒',
                  description: 'Auto-Refill executes automatically with secure top-up and is exclusive to Premium users. Upgrade now to fully automate SIM renewal!',
                  requiredPlan: 'Premium Plan',
                  highlights: [
                    'Unlimited high-speed SIM protection lines',
                    'Zero-click Automated Auto-Refill executing balance updates',
                    'Direct balance API synchronization & validation',
                  ],
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Unlock',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent),
              ),
            ),
          ],
        ),
      );
    }

    // Configured or Unconfigured for Premium
    final bool isConfigured = schedule != null && schedule.amount > 0.0;
    final bool isPaused = schedule != null && !schedule.isActive;
    final dateFormat = DateFormat('MMM dd, yyyy');

    final cardColor = !isConfigured
        ? AppColors.healthRed
        : (isPaused ? AppColors.warning : AppColors.secondary);
    final statusIcon = !isConfigured
        ? Icons.warning_amber_rounded
        : (isPaused ? Icons.pause_circle_outline_rounded : Icons.verified_user);

    final statusText = !isConfigured
        ? 'Auto-Refill: Unconfigured'
        : (isPaused ? 'Auto-Refill: Paused' : 'Auto-Refill: Active');

    final subtitleText = !isConfigured
        ? 'Configure automatic balance refills to keep SIM alive.'
        : (isPaused
            ? 'Automatic refills are suspended'
            : (schedule.frequencyDays == 0
                ? '\$${schedule.amount.toStringAsFixed(2)} USD refill every 1 hour'
                : '\$${schedule.amount.toStringAsFixed(2)} USD refill every ${schedule.frequencyDays} days'));

    return GlassCard(
      padding: const EdgeInsets.all(12),
      isActive: false,
      activeColor: cardColor,
      child: Column(
        children: [
          Row(
            children: [
              Icon(statusIcon, color: cardColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: AppTextStyles.caption.copyWith(
                        color: context.onSurfaceColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isConfigured ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ScheduledTopupSheet(
                      simLineId: line.id,
                      simNickname: line.nickname ?? line.phoneNumber,
                      existingSchedule: schedule,
                      configMode: 'refill',
                    ),
                  );
                },
                tooltip: isConfigured ? 'Edit Auto-Refill' : 'Configure Auto-Refill',
              ),
            ],
          ),
          if (isConfigured) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPaused ? 'Resume renewal to enable' : 'Next Auto-Refill:',
                        style: AppTextStyles.caption.copyWith(
                          color: context.onSurfaceColor.withOpacity(0.4),
                          fontSize: 10,
                        ),
                      ),
                      if (!isPaused) ...[
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(schedule.nextExecutionAt),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: context.onSurfaceColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
 }
}