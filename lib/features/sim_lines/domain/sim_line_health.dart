import 'package:flutter/material.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';

enum HealthScorePillarType {
  realLiveVerification,
  autoNotify,
  recentRecharge,
}

/// Represents one of the 3 key protection pillars contributing to the SIM line's
/// overall health score (max 100 points):
/// 1. Real Live Verification: 25 points
/// 2. Auto-Notify Alerts: 25 points
/// 3. Active Recharge Window: 50 points
class HealthScorePillar {
  final HealthScorePillarType type;
  final String title;
  final String description;
  final int earnedPoints;
  final int maxPoints;
  final bool isAchieved;
  final IconData icon;
  final String actionLabel;

  const HealthScorePillar({
    required this.type,
    required this.title,
    required this.description,
    required this.earnedPoints,
    this.maxPoints = 25,
    required this.isAchieved,
    required this.icon,
    required this.actionLabel,
  });
}

/// Single client-side definition of a line's display health score (0 - 100).
///
/// Scored across 3 core pillars (100 points total):
/// 1. Real Live Verification (25 pts): ONLY through real live notify (SMS DLR or Missed Call ring).
///    Format checks during line onboarding do NOT grant points.
/// 2. Auto-Notify Alerts (25 pts): Automated reminder schedule active before carrier cutoff.
/// 3. Active Recharge Window (50 pts): Last refill date is the ground truth.
///    - No recharge recorded: 0 pts
///    - Last recharge older than carrier rule days: 0 pts
///    - Last recharge within carrier rule limit: 50 pts
extension SimLineHealth on SimLine {
  /// Returns the breakdown of the 3 health pillars with their earned vs max points,
  /// achievement status, descriptions, and action labels.
  List<HealthScorePillar> healthScoreBreakdown({
    bool isRealLiveVerified = false,
    bool hasNotificationSchedule = false,
    int? carrierExpirationDays,
    // Optional legacy parameters for backwards compatibility
    bool hasRefillSchedule = false,
    bool? isVerified,
    bool? isPremium,
    bool? hasProtectionActive,
  }) {
    // 1. Real Live Verification (25 pts)
    // ONLY awarded if real live verification has succeeded (SMS DLR / missed call).
    // Format check or status == 'active' during onboarding does NOT grant points.
    final bool verified = isRealLiveVerified;

    // 2. Auto-Notify alerts configured & active (25 pts)
    final bool notifyActive = hasNotificationSchedule;

    // 3. Last refill date within carrier rule window (50 pts)
    // - No recharge recorded (lastTopupAt == null) => 0 pts
    // - Last recharge older than carrier rule days => 0 pts
    // - Last recharge within carrier rule days => 50 pts
    final int expirationDays = carrierExpirationDays ?? 90;
    final bool recentRefill = lastTopupAt != null &&
        DateTime.now().difference(lastTopupAt!).inDays < expirationDays;

    return [
      HealthScorePillar(
        type: HealthScorePillarType.realLiveVerification,
        title: 'Real Live Verification',
        description: verified
            ? 'SIM is live-verified on the mobile network via telecom signaling'
            : 'Live verification test required to confirm SIM is active & reachable',
        earnedPoints: verified ? 25 : 0,
        maxPoints: 25,
        isAchieved: verified,
        icon: Icons.cell_tower_rounded,
        actionLabel: 'Verify Line',
      ),
      HealthScorePillar(
        type: HealthScorePillarType.autoNotify,
        title: 'Auto-Notify Alerts',
        description: notifyActive
            ? 'Automated reminder alerts are active before inactivity cutoffs'
            : 'No notification schedule configured to warn before deactivation',
        earnedPoints: notifyActive ? 25 : 0,
        maxPoints: 25,
        isAchieved: notifyActive,
        icon: Icons.notifications_active_outlined,
        actionLabel: 'Set Auto-Notify',
      ),
      HealthScorePillar(
        type: HealthScorePillarType.recentRecharge,
        title: 'Active Recharge Window',
        description: recentRefill
            ? 'Recharge recorded within carrier rule ($expirationDays days limit)'
            : (lastTopupAt == null
                ? 'No recharge recorded yet. Update your last recharge date'
                : 'Last recharge exceeds carrier limit of $expirationDays days (0 pts)'),
        earnedPoints: recentRefill ? 50 : 0,
        maxPoints: 50,
        isAchieved: recentRefill,
        icon: Icons.calendar_today_outlined,
        actionLabel: 'Update Recharge',
      ),
    ];
  }

  /// Calculates the total integer health score (0 - 100) by summing all
  /// earned points from [healthScoreBreakdown].
  int displayHealthScore({
    bool isRealLiveVerified = false,
    bool hasNotificationSchedule = false,
    int? carrierExpirationDays,
    // Optional legacy parameters for backwards compatibility
    bool hasRefillSchedule = false,
    bool? isVerified,
    bool? isPremium,
    bool? hasProtectionActive,
  }) {
    final pillars = healthScoreBreakdown(
      isRealLiveVerified: isRealLiveVerified,
      hasNotificationSchedule: hasNotificationSchedule,
      carrierExpirationDays: carrierExpirationDays,
      hasRefillSchedule: hasRefillSchedule,
      isVerified: isVerified,
      isPremium: isPremium,
      hasProtectionActive: hasProtectionActive,
    );

    int score = 0;
    for (final p in pillars) {
      score += p.earnedPoints;
    }
    return score.clamp(0, 100);
  }
}
