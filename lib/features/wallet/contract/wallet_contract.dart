/// SIM Shield — Wallet Contract interface
library;

import '../model/wallet_model.dart';
import '../../../core/result.dart';

abstract interface class WalletContract {
  /// Fetches the user's active wallet balance.
  Future<Result<Wallet>> getWallet();

  /// Fetches the full ledger history for deposit credit/debit charges.
  Future<Result<List<WalletTransaction>>> getTransactions();

  /// Performs a visual deposit to add mock funds to the wallet ledger.
  Future<Result<Wallet>> deposit({
    required double amount,
    String? description,
    String? referenceId,
  });

  /// Deducts funds from the wallet and adds a debit transaction to the ledger.
  Future<Result<Wallet>> deduct({
    required double amount,
    String? description,
    String? referenceId,
    String type = 'topup_debit',
  });
}
