/// Pure date math for refill scheduling, shared by the execute and retry
/// paths in [ScheduledTopupRepository].
///
/// A frequency of 0 days means "test mode": everything advances by one hour.
class RefillScheduleMath {
  RefillScheduleMath._();

  /// Executes a few days before the carrier deadline so a failed attempt can
  /// be retried before the line actually expires.
  static int safetyAdjustedDelayDays(int frequencyDays) {
    switch (frequencyDays) {
      case 90:
        return 85;
      case 30:
        return 28;
      case 14:
        return 13;
      default:
        return frequencyDays;
    }
  }

  /// When the schedule should next run.
  static DateTime nextExecutionAt(DateTime nowUtc, int frequencyDays) =>
      nowUtc.add(
        frequencyDays == 0
            ? const Duration(hours: 1)
            : Duration(days: safetyAdjustedDelayDays(frequencyDays)),
      );

  /// When the SIM line is next due for a top-up (the full carrier window).
  static DateTime nextTopupDue(DateTime nowUtc, int frequencyDays) => nowUtc
      .add(frequencyDays == 0 ? const Duration(hours: 1) : Duration(days: frequencyDays));

  /// Validity end: due date plus a 7-day grace buffer.
  static DateTime validityExpiresAt(DateTime nextTopupDue, int frequencyDays) =>
      nextTopupDue.add(
        frequencyDays == 0 ? const Duration(hours: 1) : const Duration(days: 7),
      );
}
