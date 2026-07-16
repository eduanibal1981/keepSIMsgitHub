/// SIM Shield — Wallet Repository
///
/// Implements [WalletContract] using Supabase.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import '../contract/wallet_contract.dart';
import '../model/wallet_model.dart';

class WalletRepository implements WalletContract {
  final SupabaseClient _client;
  final LocalCacheService _cache;
  final ConnectivityService _connectivity;

  WalletRepository(this._client, this._cache, this._connectivity);

  /// All wallet mutations go through the `wallet_transact` Edge Function;
  /// clients have no INSERT/UPDATE grants on wallets or wallet_transactions.
  Future<Map<String, dynamic>> _walletTransact(
    Map<String, dynamic> body,
  ) async {
    final response = await _client.functions.invoke(
      'wallet_transact',
      body: body,
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const FormatException('Unexpected response from wallet service');
  }

  @override
  Future<Result<Wallet>> getWallet() async {
    if (_connectivity.isOffline) {
      final cached = _cache.readJson('cached_wallet');
      if (cached != null) {
        return Success(Wallet.fromJson(cached as Map<String, dynamic>));
      }
      return const Failure(
        AppFailure.server(
          message: 'No internet connection and no cached wallet found.',
        ),
      );
    }

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      // Try fetching active wallet
      try {
        final response = await _client
            .from('wallets')
            .select()
            .eq('user_id', userId)
            .single();

        await _cache.writeJson('cached_wallet', response);
        return Success(Wallet.fromJson(response));
      } on PostgrestException catch (e) {
        // If not found (PGRST116), have the server create the starting wallet
        if (e.code == 'PGRST116') {
          final data = await _walletTransact({'action': 'ensure'});
          final walletJson = data['wallet'];
          if (data['success'] == true && walletJson is Map<String, dynamic>) {
            await _cache.writeJson('cached_wallet', walletJson);
            return Success(Wallet.fromJson(walletJson));
          }
          return Failure(
            AppFailure.server(
              message:
                  data['errorMessage']?.toString() ??
                  'Failed to create wallet.',
            ),
          );
        }
        return Failure(AppFailure.server(message: e.message));
      }
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<List<WalletTransaction>>> getTransactions() async {
    if (_connectivity.isOffline) {
      final cached = _cache.readJson('cached_wallet_transactions');
      if (cached is List) {
        return Success(
          cached
              .map(
                (json) =>
                    WalletTransaction.fromJson(json as Map<String, dynamic>),
              )
              .toList(),
        );
      }
      return const Success([]);
    }

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      // 1. Fetch from Supabase
      final response = await _client
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      await _cache.writeJson('cached_wallet_transactions', response);

      final dbList = (response as List)
          .map(
            (json) => WalletTransaction.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      if (dbList.isNotEmpty) {
        return Success(dbList);
      }

      // 2. If ledger is completely empty, have the server seed the welcome
      // transactions, then re-fetch.
      final ensured = await _walletTransact({'action': 'ensure'});
      if (ensured['success'] == true) {
        final seeded = await _client
            .from('wallet_transactions')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        await _cache.writeJson('cached_wallet_transactions', seeded);

        return Success(
          (seeded as List)
              .map(
                (json) =>
                    WalletTransaction.fromJson(json as Map<String, dynamic>),
              )
              .toList(),
        );
      }

      return const Success([]);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<Wallet>> awaitPayPalCredit({
    required String orderId,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (_connectivity.isOffline) {
      return const Failure(
        AppFailure.server(
          message: 'Wallet deposits require an active internet connection.',
        ),
      );
    }

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      // The paypal-webhook Edge Function writes the deposit row with the
      // PayPal order id in its receipt metadata; poll our own ledger (RLS
      // read-own) until it lands.
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        final rows = await _client
            .from('wallet_transactions')
            .select('id')
            .eq('user_id', userId)
            .eq('type', 'deposit')
            .filter('metadata->>paypal_order_id', 'eq', orderId)
            .limit(1);

        if ((rows as List).isNotEmpty) {
          return getWallet();
        }
        await Future.delayed(const Duration(seconds: 3));
      }

      return const Failure(
        AppFailure.server(
          message:
              'Payment approved — crediting is taking longer than usual. '
              'Your balance will update automatically once PayPal confirms.',
        ),
      );
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<Wallet>> deduct({
    required double amount,
    String? description,
    String? referenceId,
    String type = 'topup_debit',
  }) async {
    if (_connectivity.isOffline) {
      return const Failure(
        AppFailure.server(
          message: 'Wallet operations require an active internet connection.',
        ),
      );
    }

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      // Debited server-side (atomic balance check + update + ledger insert).
      final data = await _walletTransact({
        'action': 'deduct',
        'amount': amount,
        'description': description ?? 'Manual SIM Refill',
      });

      final walletJson = data['wallet'];
      if (data['success'] == true && walletJson is Map<String, dynamic>) {
        await _cache.writeJson('cached_wallet', walletJson);
        return Success(Wallet.fromJson(walletJson));
      }

      if (data['code'] == 'insufficient_funds') {
        return const Failure(
          AppFailure.validation(
            message: 'Insufficient funds for this transaction.',
          ),
        );
      }

      return Failure(
        AppFailure.server(
          message: data['errorMessage']?.toString() ?? 'Deduction failed.',
        ),
      );
    } on FunctionException catch (e) {
      return Failure(
        AppFailure.server(message: 'Deduction failed: ${e.reasonPhrase}'),
      );
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }
}
