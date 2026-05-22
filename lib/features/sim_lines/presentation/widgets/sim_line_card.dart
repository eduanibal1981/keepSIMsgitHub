import 'package:keep_sims/core/utils/build_context_extension.dart';
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
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';

class SimLineCard extends ConsumerWidget {
  final SimLine line;
  final Country? country;
  final bool isShared;
  final bool isSelected;
  final bool isSelectMode;
  final dynamic householdState;
  final bool showActions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedCountry = country ??
        ref.watch(supportedCountriesProvider).valueOrNull?.firstWhereOrNull((c) => c.id == line.countryId);

    final schedule = ref.watch(scheduledTopupForLineProvider(line.id));
    bool hasAutoRefill = schedule != null && schedule.status == 'active';
    bool isVerified = line.status == 'active';
    bool recentRefill = line.lastTopupAt != null && DateTime.now().difference(line.lastTopupAt!).inDays <= 80;
    int computedHealthScore = (hasAutoRefill ? 50 : 0) + (isVerified ? 25 : 0) + (recentRefill ? 25 : 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isSelected ? context.cardColor.withBlue(35).withGreen(10) : context.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : context.dividerColor.withOpacity(0.5),
          width: isSelected ? 1.5 : 1,
        ),
      ),
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
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                        color: isSelected ? AppColors.primary : context.onSurfaceColor.withOpacity(0.6),
                        size: 24,
                      ),
                    ),
                  ],
                  _buildFlagAvatar(line, resolvedCountry),

                  const SizedBox(width: 16),

                  // Nickname & Phone Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              line.nickname ?? 'My SIM Card',
                              style: AppTextStyles.headlineSmall.copyWith(
                                color: context.onSurfaceColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildTierBadge(line.protectionTier),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          line.phoneNumber,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: context.onSurfaceColor.withOpacity(0.6),
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (resolvedCountry != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            resolvedCountry.name,
                            style: AppTextStyles.caption.copyWith(color: AppColors.primaryLight),
                          ),
                        ],
                        if (isShared) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.people_outline, color: AppColors.primaryLight, size: 12),
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

                  // Health Score Indicator Ring
                  _buildHealthScoreRing(context, computedHealthScore),

                  // Action menu
                  if (!isShared && showActions)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: context.onSurfaceColor.withOpacity(0.6)),
                      color: context.surfaceColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                              Icon(Icons.edit, color: context.onSurfaceColor.withOpacity(0.6), size: 20),
                              SizedBox(width: 8),
                              Text('Edit Details', style: TextStyle(color: context.onSurfaceColor)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                              SizedBox(width: 8),
                              Text('Delete Protection', style: TextStyle(color: AppColors.error)),
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
              _buildDetailsRow(context, line),
              _buildScheduledTopupPanel(context, ref, line),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlagAvatar(SimLine line, Country? country) {
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
          Icon(getIcon(line.avatarIcon), color: AppColors.primaryLight, size: 22),
          Positioned(
            bottom: 2,
            right: 2,
            child: Text(flag, style: const TextStyle(fontSize: 12)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: getTierColor().withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
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

  Widget _buildHealthScoreRing(BuildContext context, int score) {
    Color color = AppColors.healthGreen;
    if (score < 30) {
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

  Widget _buildDetailsRow(BuildContext context, SimLine line) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    String getLastRefillStr() {
      if (line.lastTopupAt == null) return 'No refill yet';
      return dateFormat.format(line.lastTopupAt!);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildInfoColumn(context, 'Last Refill', getLastRefillStr(), Icons.history),
        _buildInfoColumn(context, 'Protection Status', line.status.toUpperCase(), Icons.security),
      ],
    );
  }

  Widget _buildInfoColumn(BuildContext context, String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: context.onSurfaceColor.withOpacity(0.4)),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: context.onSurfaceColor.withOpacity(0.4)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            color: context.onSurfaceColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, SimLine line) {
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
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Text(
              'Remove Protection',
              style: AppTextStyles.headlineSmall.copyWith(color: context.onSurfaceColor),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to stop keeping ${line.nickname ?? line.phoneNumber} protected? Scheduled top-ups for this SIM line will be permanently cancelled.',
          style: AppTextStyles.bodyMedium.copyWith(color: context.onSurfaceColor.withOpacity(0.6)),
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
                await ref.read(simLinesControllerProvider.notifier).deleteSimLine(line.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('SIM line protection removed successfully.'),
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
            child: Text('Delete', style: TextStyle(color: context.onSurfaceColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledTopupPanel(BuildContext context, WidgetRef ref, SimLine line) {
    final schedule = ref.watch(scheduledTopupForLineProvider(line.id));

    if (schedule == null) {
      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(color: context.dividerColor, height: 1),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.healthRed.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.healthRed.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.healthRed, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Refill: Disabled',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.onSurfaceColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Critical risk of SIM deactivation.',
                        style: AppTextStyles.caption.copyWith(color: context.onSurfaceColor.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ScheduledTopupSheet(
                        simLineId: line.id,
                        simNickname: line.nickname ?? line.phoneNumber,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: context.onSurfaceColor,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Configure', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final dateFormat = DateFormat('MMM dd, yyyy');
    final isPaused = !schedule.isActive;
    final cardColor = isPaused ? AppColors.warning : AppColors.secondary;
    final statusIcon = isPaused ? Icons.pause_circle_outline_rounded : Icons.verified_user;
    final statusText = isPaused ? 'Auto-Refill: Paused' : 'Auto-Refill: Active';

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          child: Divider(color: context.dividerColor, height: 1),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardColor.withOpacity(0.15)),
          ),
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
                          isPaused
                              ? 'Schedule is currently suspended'
                              : '\$${schedule.amount.toStringAsFixed(2)} USD every ${schedule.frequencyDays} days',
                          style: AppTextStyles.caption.copyWith(color: context.onSurfaceColor.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: AppColors.primaryLight, size: 20),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => ScheduledTopupSheet(
                          simLineId: line.id,
                          simNickname: line.nickname ?? line.phoneNumber,
                          existingSchedule: schedule,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPaused ? 'Resume renewal to enable' : 'Next Auto-Refill:',
                          style: AppTextStyles.caption.copyWith(color: context.onSurfaceColor.withOpacity(0.4), fontSize: 10),
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
                  const SizedBox(width: 8),
                  if (!isPaused)
                    _SimulateRefillButton(scheduleId: schedule.id),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SimulateRefillButton extends ConsumerStatefulWidget {
  final String scheduleId;

  const _SimulateRefillButton({required this.scheduleId});

  @override
  ConsumerState<_SimulateRefillButton> createState() => _SimulateRefillButtonState();
}

class _SimulateRefillButtonState extends ConsumerState<_SimulateRefillButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _simulate,
      icon: _isLoading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.onSurfaceColor,
              ),
            )
          : Icon(Icons.flash_on_rounded, size: 14, color: context.onSurfaceColor),
      label: Text(
        'Simulate Refill',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.onSurfaceColor),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondaryDark,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _simulate() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref
          .read(scheduledTopupControllerProvider.notifier)
          .executeMockTopup(widget.scheduleId);

      if (mounted) {
        switch (result) {
          case Success():
            ref.invalidate(simLinesControllerProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: context.onSurfaceColor),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Auto-refill execution simulated! Balance deducted & validity extended.'),
                    ),
                  ],
                ),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 4),
              ),
            );
          case Failure(error: final err):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(err.message),
                backgroundColor: AppColors.error,
              ),
            );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Simulated execution failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
