import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';

/// Single client-side definition of a line's display health score.
///
/// Mirrors the DB's `calculate_health_score(uuid, text, timestamptz)`:
/// active protection 50 + line active 25 + refill within 80 days 25.
/// Free-tier lines are binary (notify schedule on/off). Home-mode forces 100
/// until REQUEST F decouples home-mode from protection.
extension SimLineHealth on SimLine {
  int displayHealthScore({
    required bool isPremium,
    required bool hasProtectionActive,
  }) {
    if (isHomeMode) return 100;
    if (!isPremium) return hasProtectionActive ? 100 : 0;

    final bool isVerified = status == 'active';
    final bool recentRefill =
        lastTopupAt != null &&
        DateTime.now().difference(lastTopupAt!).inDays <= 80;

    return (hasProtectionActive ? 50 : 0) +
        (isVerified ? 25 : 0) +
        (recentRefill ? 25 : 0);
  }
}
