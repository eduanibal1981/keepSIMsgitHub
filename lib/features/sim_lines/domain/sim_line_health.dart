import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';

/// Single client-side definition of a line's display health score.
///
/// Active protection 50 + line active 25 + refill within 80 days 25.
/// Free-tier lines are binary (notify schedule on/off).
///
/// A deliberately paused line shows 100 ("nothing to worry about — you paused
/// it"). Since B5 this keys on [SimLine.protectionPaused], not home mode: a
/// resident's always-home line with protection running scores on its real
/// state instead of being masked healthy while it dies.
extension SimLineHealth on SimLine {
  int displayHealthScore({
    required bool isPremium,
    required bool hasProtectionActive,
  }) {
    if (protectionPaused) return 100;
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
