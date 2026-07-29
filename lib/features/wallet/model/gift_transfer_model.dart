/// SIM Shield — Gift transfer models (G3)
///
/// Feature suggestion #3 in doc/PRODUCTION_PLAN_REVIEW.md § 6.
///
/// `transfer_wallet_credit` returns a jsonb envelope rather than a table row,
/// so these are plain immutable classes with a `fromJson` — the same shape
/// `WalletState` already uses — instead of Freezed. Nothing here is generated.
library;

import 'wallet_model.dart';

/// Why a transfer was refused. The server owns these strings; the client only
/// decides which ones are worth a special affordance.
///
/// Anything not listed here is still surfaced — [GiftTransferResult.error]
/// always carries the server's own sentence, and it is written to be shown to
/// the user verbatim. Adding a code here is only necessary when the UI needs to
/// *do* something different, not merely to say something different.
abstract final class GiftErrorCode {
  static const String unauthorized = 'UNAUTHORIZED';
  static const String invalidAmount = 'INVALID_AMOUNT';
  static const String invalidEmail = 'INVALID_EMAIL';
  static const String belowMinimum = 'BELOW_MINIMUM';
  static const String aboveMaximum = 'ABOVE_MAXIMUM';
  static const String senderSuspended = 'SENDER_SUSPENDED';
  static const String senderClosing = 'SENDER_CLOSING';
  static const String recipientNotFound = 'RECIPIENT_NOT_FOUND';
  static const String cannotGiftSelf = 'CANNOT_GIFT_SELF';
  static const String recipientUnavailable = 'RECIPIENT_UNAVAILABLE';
  static const String dailyLimit = 'DAILY_LIMIT';
  static const String insufficientFunds = 'INSUFFICIENT_FUNDS';

  /// The balance is there, but it is promotional credit. The server sends back
  /// how much *is* transferable, so the sheet can offer that number.
  static const String notGiftable = 'NOT_GIFTABLE';

  /// Too many recipient lookups in the last hour.
  static const String rateLimited = 'KS429';
}

/// The parsed result of one `transfer_wallet_credit` call.
class GiftTransferResult {
  final bool success;

  /// True when this reference id had already been transferred. The money moved
  /// exactly once; the caller should treat it as a success, not a retry.
  final bool alreadySent;

  final String? code;
  final String? error;

  final String? referenceId;
  final double? amount;
  final String? recipientEmail;
  final String? recipientName;
  final double? balanceAfter;

  /// Present on `NOT_GIFTABLE` — how much of the balance can actually be sent.
  final double? giftable;

  /// Present on `DAILY_LIMIT`.
  final double? dailyMax;
  final double? sentToday;

  const GiftTransferResult({
    required this.success,
    this.alreadySent = false,
    this.code,
    this.error,
    this.referenceId,
    this.amount,
    this.recipientEmail,
    this.recipientName,
    this.balanceAfter,
    this.giftable,
    this.dailyMax,
    this.sentToday,
  });

  factory GiftTransferResult.fromJson(Map<String, dynamic> json) {
    double? num_(Object? v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

    return GiftTransferResult(
      success: json['success'] == true,
      alreadySent: json['already_sent'] == true,
      code: json['code'] as String?,
      error: json['error'] as String?,
      referenceId: json['reference_id'] as String?,
      amount: num_(json['amount']),
      recipientEmail: json['recipient_email'] as String?,
      recipientName: json['recipient_name'] as String?,
      balanceAfter: num_(json['balance_after']),
      giftable: num_(json['giftable']),
      dailyMax: num_(json['daily_max']),
      sentToday: num_(json['sent_today']),
    );
  }

  /// What to call the recipient in a confirmation. Falls back to the address
  /// the sender typed when the recipient has no display name set.
  String get recipientLabel =>
      (recipientName != null && recipientName!.isNotEmpty)
      ? recipientName!
      : (recipientEmail ?? 'them');

  /// The sentence to show. The server writes these to be user-facing; this only
  /// covers the case where something returned no message at all.
  String get message =>
      error ?? (success ? 'Credit sent.' : 'The transfer could not be completed.');
}

/// Reads the `metadata.gift` block that `transfer_wallet_credit` writes onto
/// both halves of a transfer.
///
/// This is an extension rather than fields on [WalletTransaction] because that
/// model is Freezed-generated and adding methods to it would mean regenerating
/// every `.freezed.dart` in the repo for four getters.
extension WalletTransactionGift on WalletTransaction {
  bool get isGiftSent => type == 'gift_sent';
  bool get isGiftReceived => type == 'gift_received';
  bool get isGift => isGiftSent || isGiftReceived;

  Map<String, dynamic>? get _gift {
    final block = metadata?['gift'];
    return block is Map<String, dynamic> ? block : null;
  }

  String? get giftCounterpartyEmail => _gift?['counterparty_email'] as String?;
  String? get giftCounterpartyName => _gift?['counterparty_name'] as String?;
  String? get giftNote => _gift?['note'] as String?;

  /// Display name when the counterparty set one, otherwise their address.
  String? get giftCounterpartyLabel {
    final name = giftCounterpartyName;
    if (name != null && name.isNotEmpty) return name;
    return giftCounterpartyEmail;
  }
}

/// How much of a balance may be sent on.
///
/// This mirrors `transfer_wallet_credit`'s server-side rule exactly:
///
///   giftable = min(balance, deposits + gifts_received - gifts_sent)
///
/// It is computed here **only to label the sheet before the user commits** —
/// the server recomputes it from the ledger and is the sole authority. Keeping
/// the two in step matters: a sheet that offers more than the server will send
/// produces a rejection the user cannot act on.
///
/// One known divergence, stated rather than hidden: the server also requires
/// `status = 'completed'`, and [WalletTransaction] does not carry `status`, so
/// this counts every row it is given. Every one of the 165 ledger rows on the
/// live database is `completed`, so the two agree today; if a `pending` credit
/// ever appears, this over-estimates and the server refuses with the real
/// figure, which the sheet then shows. It never under-estimates, so it can
/// never block a transfer the server would have allowed.
double giftableBalance({
  required double balance,
  required List<WalletTransaction> transactions,
}) {
  double inflow = 0.0;
  double outflow = 0.0;

  for (final tx in transactions) {
    if (tx.type == 'deposit' || tx.type == 'gift_received') {
      inflow += tx.amount;
    } else if (tx.type == 'gift_sent') {
      outflow += tx.amount;
    }
  }

  final transferable = inflow - outflow;
  if (transferable <= 0) return 0.0;
  return transferable < balance ? transferable : balance;
}
