/// SIM Shield — Wallet Contract interface
library;

import '../model/wallet_model.dart';
import '../model/gift_transfer_model.dart';
import '../../../core/result.dart';

abstract interface class WalletContract {
  /// Fetches the user's active wallet balance.
  Future<Result<Wallet>> getWallet();

  /// Fetches the full ledger history for deposit credit/debit charges.
  Future<Result<List<WalletTransaction>>> getTransactions();

  /// Waits for the server-side PayPal webhook to credit a captured order.
  ///
  /// Deposits are credited exclusively by the `paypal-webhook` Edge Function
  /// once PayPal confirms the capture; the client never credits itself. This
  /// polls the user's own ledger until the deposit for [orderId] appears.
  Future<Result<Wallet>> awaitPayPalCredit({
    required String orderId,
    Duration timeout = const Duration(seconds: 60),
  });

  /// Deducts funds from the wallet and adds a debit transaction to the ledger.
  Future<Result<Wallet>> deduct({
    required double amount,
    String? description,
    String? referenceId,
    String type = 'topup_debit',
  });

  /// Pays the yearly plan service fee from the wallet.
  ///
  /// The amount is priced server-side by `pay_plan_fee_from_wallet` from
  /// `system_configs.BASE_SERVICE_FEE_USD` — the client never states it.
  Future<Result<Wallet>> payPlanFee({String? simLineId});

  /// Sends wallet credit to the KeepSIMs account owning [recipientEmail].
  ///
  /// One `transfer_wallet_credit` call does the debit and the credit in a
  /// single transaction. Every rule — minimum, maximum, daily cap, which part
  /// of the balance is transferable, whether the recipient can receive — is
  /// enforced server-side; the client states an address, an amount and an
  /// optional note, and renders whatever comes back.
  ///
  /// [referenceId] makes a network retry of this exact attempt adopt the
  /// original transfer instead of sending twice. Supplying it is the whole
  /// point, so the repository generates one when the caller does not.
  ///
  /// Returns [Success] for a refusal too — a refused transfer is a normal
  /// outcome carrying a message for the user, not an error. [Failure] is
  /// reserved for not reaching the server at all.
  Future<Result<GiftTransferResult>> sendGift({
    required String recipientEmail,
    required double amount,
    String? note,
    String? referenceId,
  });
}
