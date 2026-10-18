/// SIM Shield — Wallet Controller
///
/// Reactively aggregates wallet balances and transaction history logs.
/// Enforces clean invalidations and automatic dashboard updates.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import '../model/wallet_model.dart';
import '../model/gift_transfer_model.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';

part 'wallet_controller.g.dart';

/// Aggregated state for the Wallet sub-system.
class WalletState {
  final Wallet wallet;
  final List<WalletTransaction> transactions;
  final bool isSubmitting;
  final Map<String, dynamic>? summary;

  const WalletState({
    required this.wallet,
    required this.transactions,
    this.isSubmitting = false,
    this.summary,
  });

  WalletState copyWith({
    Wallet? wallet,
    List<WalletTransaction>? transactions,
    bool? isSubmitting,
    Map<String, dynamic>? summary,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      summary: summary ?? this.summary,
    );
  }
}

@Riverpod(keepAlive: true)
class WalletController extends _$WalletController {
  @override
  FutureOr<WalletState> build() async {
    // 1. Reactively watch authentication changes to rebuild wallet data
    final authProfile = ref.watch(authControllerProvider);

    final profile = authProfile.value;
    if (profile == null) {
      throw Exception('User is not authenticated');
    }

    final repo = ref.watch(walletRepositoryProvider);

    // 2. Fetch Wallet + Transaction Ledger + Summary in parallel
    final walletFuture = repo.getWallet();
    final txsFuture = repo.getTransactions();
    final summaryFuture = repo.getWalletSummary();

    final (walletResult, txsResult, summaryResult) = await (
      walletFuture,
      txsFuture,
      summaryFuture,
    ).wait;

    // 3. Pattern match sealed clean architecture results
    switch ((walletResult, txsResult)) {
      case (Success(data: final wallet), Success(data: final txs)):
        Map<String, dynamic>? summary;
        if (summaryResult case Success(data: final s)) {
          summary = s;
        }
        return WalletState(wallet: wallet, transactions: txs, summary: summary);
      case (Failure(error: final f), _):
        throw Exception(f.message);
      case (_, Failure(error: final f)):
        throw Exception(f.message);
    }
  }

  /// Waits for the server-side PayPal webhook to credit a captured order,
  /// then invalidates related screens. The client never credits itself.
  Future<bool> awaitPayPalCredit(String orderId) async {
    final current = state.value;
    if (current == null) return false;

    // Set submitting status
    state = AsyncData(current.copyWith(isSubmitting: true));

    final repo = ref.read(walletRepositoryProvider);
    final result = await repo.awaitPayPalCredit(orderId: orderId);

    switch (result) {
      case Success():
        // Refresh this wallet query in the background
        ref.invalidateSelf();
        return true;
      case Failure(error: final f):
        state = AsyncError(Exception(f.message), StackTrace.current);
        return false;
    }
  }

  /// Pays a yearly plan from the wallet (priced server-side).
  ///
  /// Returns false — without charging anything — when the balance cannot
  /// cover the fee, so the caller can fall back to a PayPal charge. Any other
  /// failure throws.
  ///
  /// [plan] is `'standard'` or `'premium'`; [carrierRuleId] prices a Premium
  /// year for a line that does not exist yet (J8).
  Future<bool> payPlanFee({
    String? simLineId,
    String? referenceId,
    String plan = 'standard',
    String? carrierRuleId,
    double? expectedAmount,
  }) async {
    // Only used to drive the submitting spinner, so a state that has not
    // loaded yet must not decide whether the fee gets charged. This used to
    // `return false` on a null value, which the caller reads as "the wallet
    // cannot cover it" — an unloaded provider silently cancelled the charge.
    final current = state.value;

    final authGuard = ref.read(paymentAuthGuardProvider);
    final authResult = await authGuard.confirmPayment(
      reason: 'Authenticate to confirm plan fee payment',
    );
    if (authResult == BiometricResult.cancelled ||
        authResult == BiometricResult.failed ||
        authResult == BiometricResult.lockedOut) {
      return false;
    }

    if (current != null) {
      state = AsyncData(current.copyWith(isSubmitting: true));
    }

    final repo = ref.read(walletRepositoryProvider);
    final result = await repo.payPlanFee(
      simLineId: simLineId,
      referenceId: referenceId,
      plan: plan,
      carrierRuleId: carrierRuleId,
      expectedAmount: expectedAmount,
    );

    switch (result) {
      case Success():
        ref.invalidateSelf();
        return true;
      case Failure(error: final f):
        if (current != null) {
          state = AsyncData(current.copyWith(isSubmitting: false));
        }
        if (f is ValidationFailure ||
            f.message.contains('Insufficient funds')) {
          return false;
        }
        throw Exception(f.message);
    }
  }

  /// Sends wallet credit to another KeepSIMs account.
  ///
  /// Gated behind the same biometric confirm as a deposit — this moves real
  /// money out of the wallet and, unlike a top-up, it moves it to someone else.
  /// Returns null when the user backs out of that prompt, so the caller can
  /// distinguish "cancelled" from "refused".
  ///
  /// A refusal comes back as a [GiftTransferResult] with `success == false` and
  /// a message written to be shown as-is; only a failure to reach the server
  /// throws.
  Future<GiftTransferResult?> sendGift({
    required String recipientEmail,
    required double amount,
    String? note,
  }) async {
    final current = state.value;
    if (current == null) return null;

    final authGuard = ref.read(paymentAuthGuardProvider);
    final authResult = await authGuard.confirmPayment(
      reason: 'Authenticate to send wallet credit',
    );
    if (authResult != BiometricResult.success) {
      return null;
    }

    state = AsyncData(current.copyWith(isSubmitting: true));

    final repo = ref.read(walletRepositoryProvider);
    final result = await repo.sendGift(
      recipientEmail: recipientEmail,
      amount: amount,
      note: note,
    );

    switch (result) {
      case Success(data: final transfer):
        if (transfer.success) {
          // Both balances and both ledgers changed; re-read rather than patch.
          ref.invalidateSelf();
        } else {
          state = AsyncData(current.copyWith(isSubmitting: false));
        }
        return transfer;
      case Failure(error: final f):
        state = AsyncData(current.copyWith(isSubmitting: false));
        throw Exception(f.message);
    }
  }

  /// Triggers a debit deduction and invalidates related screens.
  Future<bool> deduct(
    double amount, {
    String? description,
    String? referenceId,
  }) async {
    final current = state.value;
    if (current == null) return false;

    // Set submitting status
    state = AsyncData(current.copyWith(isSubmitting: true));

    final repo = ref.read(walletRepositoryProvider);
    final result = await repo.deduct(
      amount: amount,
      description: description ?? 'Manual SIM Refill',
      referenceId: referenceId,
      type: 'topup_debit',
    );

    switch (result) {
      case Success():
        // Refresh this wallet query in the background
        ref.invalidateSelf();
        return true;
      case Failure(error: final f):
        // Revert submitting state
        state = AsyncData(current.copyWith(isSubmitting: false));
        // We throw so UI can catch and show snackbar for validation errors like insufficient funds
        throw Exception(f.message);
    }
  }

  /// Quotes the eligible unused paid deposit refund to the original payment source.
  Future<Map<String, dynamic>> quoteRefund() async {
    final repo = ref.read(walletRepositoryProvider);
    final result = await repo.quoteRefund();
    switch (result) {
      case Success(data: final quote):
        return quote;
      case Failure(error: final f):
        throw Exception(f.message);
    }
  }

  /// Requests a refund of eligible unused paid funds.
  Future<Map<String, dynamic>> requestRefund({
    required double amount,
    String? reason,
  }) async {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(isSubmitting: true));
    }

    final repo = ref.read(walletRepositoryProvider);
    final result = await repo.requestRefund(amount: amount, reason: reason);

    switch (result) {
      case Success(data: final res):
        ref.invalidateSelf();
        return res;
      case Failure(error: final f):
        if (current != null) {
          state = AsyncData(current.copyWith(isSubmitting: false));
        }
        throw Exception(f.message);
    }
  }
}
