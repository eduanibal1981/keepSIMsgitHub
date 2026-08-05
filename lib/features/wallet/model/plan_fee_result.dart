/// SIM Shield — Plan fee envelope.
///
/// `pay_plan_fee_from_wallet` returns a jsonb envelope, and only *some* of its
/// refusals raise. An insufficient balance raises (and arrives as a
/// `PostgrestException`); UNAUTHORIZED, a suspended account and a DEVICE_BLOCKED
/// verdict all return HTTP 200 with `success: false` and no debit.
///
/// That distinction is the whole reason this class exists: a caller that treats
/// "the RPC did not throw" as "the fee is paid" will create a paid SIM line for
/// free every time the guard refuses. Same failure mode the gift path has a
/// model for — see [GiftTransferResult].
library;

/// Why a plan fee was refused. The server owns these strings.
abstract final class PlanFeeErrorCode {
  /// G10: the device risk model refused this debit. Only reachable once
  /// `device_risk_config().enforce` is true — while it is false every
  /// assessment is logged and none is enforced.
  static const String deviceBlocked = 'DEVICE_BLOCKED';

  static const String unauthorized = 'UNAUTHORIZED';
}

/// The parsed result of one `pay_plan_fee_from_wallet` call.
class PlanFeeResult {
  final bool success;

  /// True when this reference id had already been debited. The fee was charged
  /// exactly once, so the caller must treat it as paid — retrying a timed-out
  /// call must not bill a second year.
  final bool alreadyPaid;

  final String? code;
  final String? error;
  final double? amount;
  final String? referenceId;

  const PlanFeeResult({
    required this.success,
    this.alreadyPaid = false,
    this.code,
    this.error,
    this.amount,
    this.referenceId,
  });

  /// Parses whatever the RPC handed back.
  ///
  /// A non-map body is treated as a refusal rather than a success: the function
  /// always returns an object, so anything else means the call did not reach it
  /// and no debit can be assumed.
  factory PlanFeeResult.fromRpc(Object? body) {
    if (body is! Map) {
      return const PlanFeeResult(
        success: false,
        error: 'The plan fee service returned an unreadable response.',
      );
    }
    final json = body.cast<String, dynamic>();
    final rawAmount = json['amount'];
    return PlanFeeResult(
      success: json['success'] == true,
      alreadyPaid: json['already_paid'] == true,
      code: json['code'] as String?,
      error: (json['error'] ?? json['reason'])?.toString(),
      amount: rawAmount == null
          ? null
          : (rawAmount is num
                ? rawAmount.toDouble()
                : double.tryParse('$rawAmount')),
      referenceId: json['reference_id'] as String?,
    );
  }

  /// True only when the fee is genuinely covered — the one question the callers
  /// that create a paid line are asking.
  bool get isPaid => success;

  bool get isDeviceBlocked => code == PlanFeeErrorCode.deviceBlocked;

  /// The sentence to show. The server writes these to be user-facing; this only
  /// covers a refusal that carried no message at all.
  String get message =>
      error ?? (success ? 'Plan fee paid.' : 'The plan fee could not be charged.');
}
