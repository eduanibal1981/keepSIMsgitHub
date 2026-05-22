/// SIM Shield — Wallet Controller
///
/// Reactively aggregates wallet balances and transaction history logs.
/// Enforces clean invalidations and automatic dashboard updates.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/dashboard/presentation/controller/dashboard_controller.dart';
import '../model/wallet_model.dart';

part 'wallet_controller.g.dart';

/// Aggregated state for the Wallet sub-system.
class WalletState {
  final Wallet wallet;
  final List<WalletTransaction> transactions;
  final bool isSubmitting;

  const WalletState({
    required this.wallet,
    required this.transactions,
    this.isSubmitting = false,
  });

  WalletState copyWith({
    Wallet? wallet,
    List<WalletTransaction>? transactions,
    bool? isSubmitting,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

@riverpod
class WalletController extends _$WalletController {
  @override
  FutureOr<WalletState> build() async {
    // 1. Reactively watch authentication changes to rebuild wallet data
    final authProfile = ref.watch(authControllerProvider);

    final profile = authProfile.valueOrNull;
    if (profile == null) {
      throw Exception('User is not authenticated');
    }

    final repo = ref.watch(walletRepositoryProvider);

    // 2. Fetch Wallet + Transaction Ledger parallelly
    final walletResult = await repo.getWallet();
    final txsResult = await repo.getTransactions();

    // 3. Pattern match sealed clean architecture results
    switch ((walletResult, txsResult)) {
      case (Success(data: final wallet), Success(data: final txs)):
        return WalletState(wallet: wallet, transactions: txs);
      case (Failure(error: final f), _):
        throw Exception(f.message);
      case (_, Failure(error: final f)):
        throw Exception(f.message);
    }
  }

  /// Triggers a deposit credit and invalidates related screens.
  Future<bool> deposit(double amount, {String? description}) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    // Set submitting status
    state = AsyncData(current.copyWith(isSubmitting: true));

    final repo = ref.read(walletRepositoryProvider);
    final result = await repo.deposit(
      amount: amount,
      description: description ?? 'Funds added via Visa Card',
      referenceId: 'visa_${DateTime.now().millisecondsSinceEpoch}',
    );

    switch (result) {
      case Success():
        // Automatically sync home dashboard metrics immediately!
        ref.invalidate(dashboardControllerProvider);

        // Refresh this wallet query in the background
        ref.invalidateSelf();
        return true;
      case Failure(error: final f):
        state = AsyncError(Exception(f.message), StackTrace.current);
        return false;
    }
  }
}
