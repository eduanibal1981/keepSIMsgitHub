/// SIM Shield — a plan fee that has been paid but not yet consumed.
///
/// The plan fee is debited *before* the SIM line row exists, and the two are
/// separate round-trips with no shared transaction. Anything that fails in
/// between — a duplicate phone number, an offline queue, an RLS refusal, a
/// stalled socket, the app being killed while it is backgrounded for PayPal —
/// used to leave the user charged with nothing to show, and the next attempt
/// charged them again. Three orphaned $2.50 debits accumulated that way in one
/// evening of testing.
///
/// `pay_plan_fee_from_wallet` is idempotent on `reference_id`: replaying one
/// returns `already_paid: true` and debits nothing. Persisting the reference id
/// before the charge, and reusing it until a line is actually created, turns
/// every one of those failures into a free retry instead of a second bill.
library;

/// A plan fee that was charged but whose SIM line was never created.
class PendingPlanFee {
  final String referenceId;
  final double amount;
  final DateTime chargedAt;

  const PendingPlanFee({
    required this.referenceId,
    required this.amount,
    required this.chargedAt,
  });

  /// Beyond this the reference is dropped rather than replayed. A stale id
  /// would otherwise let a fee bought weeks ago silently pay for a new line.
  static const Duration maxAge = Duration(hours: 24);

  bool get isExpired => DateTime.now().difference(chargedAt) > maxAge;

  Map<String, dynamic> toJson() => {
    'reference_id': referenceId,
    'amount': amount,
    'charged_at': chargedAt.toIso8601String(),
  };

  /// Returns null for anything unreadable or outside [maxAge] — a reference we
  /// cannot trust is safer discarded, since the cost of dropping one is a
  /// single re-charge while the cost of replaying a bad one is a free line.
  static PendingPlanFee? fromJson(Object? json) {
    if (json is! Map) return null;
    final reference = json['reference_id'];
    final chargedAt = DateTime.tryParse('${json['charged_at']}');
    if (reference is! String || reference.isEmpty || chargedAt == null) {
      return null;
    }
    final rawAmount = json['amount'];
    final fee = PendingPlanFee(
      referenceId: reference,
      amount: rawAmount is num
          ? rawAmount.toDouble()
          : (double.tryParse('$rawAmount') ?? 0),
      chargedAt: chargedAt,
    );
    return fee.isExpired ? null : fee;
  }
}
