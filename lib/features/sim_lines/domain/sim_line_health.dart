import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';

/// Single client-side definition of a line's display health score (0 - 100).
///
/// Scored across 4 pillars (25 points each, max 100):
/// 1. Any refill schedule configured & active: 25 points
/// 2. Any verification (network attached / active): 25 points
/// 3. Any notification schedule configured & active: 25 points
/// 4. Last refill date within carrier rule expiration window (< 90 days default): 25 points
///
extension SimLineHealth on SimLine {
  int displayHealthScore({
    bool hasRefillSchedule = false,
    bool hasNotificationSchedule = false,
    bool? isVerified,
    int? carrierExpirationDays,
    // Optional legacy parameters for backwards compatibility
    bool? isPremium,
    bool? hasProtectionActive,
  }) {
    // 1. Any refill schedule (25 pts)
    final bool refillActive = hasRefillSchedule ||
        (isPremium == true && (hasProtectionActive ?? false));

    // 2. Any verification (25 pts)
    final bool verified = isVerified ??
        (status == 'active' ||
            isCarrierVerified ||
            carrierVerifiedAt != null ||
            verificationStatus == 'verified');

    // 3. Any notification set (25 pts)
    final bool notifyActive = hasNotificationSchedule ||
        (isPremium == false && (hasProtectionActive ?? false));

    // 4. Last refill date < carrier rule expiration days (default 90) (25 pts)
    final int expirationDays = carrierExpirationDays ?? 90;
    final bool recentRefill = lastTopupAt != null &&
        DateTime.now().difference(lastTopupAt!).inDays < expirationDays;

    int score = 0;
    if (refillActive) score += 25;
    if (verified) score += 25;
    if (notifyActive) score += 25;
    if (recentRefill) score += 25;

    return score.clamp(0, 100);
  }
}
