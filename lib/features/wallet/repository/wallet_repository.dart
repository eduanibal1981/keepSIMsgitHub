/// SIM Shield — Wallet Repository
///
/// Implements [WalletContract] using Supabase.
library;

import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/auth_session_manager.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/device_identity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import '../contract/wallet_contract.dart';
import '../model/wallet_model.dart';
import '../model/gift_transfer_model.dart';
import '../model/plan_fee_result.dart';

class WalletRepository implements WalletContract {
  final SupabaseClient _client;
  final LocalCacheService _cache;
  final ConnectivityService _connectivity;
  final Map<String, String> _refundRequestKeys = {};

  /// G10 device binding.
  final DeviceIdentityService _deviceIdentity;

  WalletRepository(
    this._client,
    this._cache,
    this._connectivity, [
    DeviceIdentityService? deviceIdentity,
  ]) : _deviceIdentity =
           deviceIdentity ?? DeviceIdentityService(supabase: _client);

  /// All wallet mutations go through the `wallet_transact` Edge Function;
  /// clients have no INSERT/UPDATE grants on wallets or wallet_transactions.
  Future<Map<String, dynamic>> _walletTransact(
    Map<String, dynamic> body,
  ) async {
    final response = await AuthSessionManager.withAuthRecovery(
      _client,
      () => _client.functions.invoke('wallet_transact', body: body),
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
        final response = await AuthSessionManager.withAuthRecovery(
          _client,
          () => _client.from('wallets').select().eq('user_id', userId).single(),
        );

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
        final cached = _cache.readJson('cached_wallet');
        if (cached != null) {
          return Success(Wallet.fromJson(cached as Map<String, dynamic>));
        }
        return Failure(AppFailure.server(message: e.message));
      }
    } catch (e) {
      final cached = _cache.readJson('cached_wallet');
      if (cached != null) {
        return Success(Wallet.fromJson(cached as Map<String, dynamic>));
      }
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
      final response = await AuthSessionManager.withAuthRecovery(
        _client,
        () => _client
            .from('wallet_transactions')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false),
      );

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
        final seeded = await AuthSessionManager.withAuthRecovery(
          _client,
          () => _client
              .from('wallet_transactions')
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false),
        );

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
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
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
          return await getWallet();
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

  @override
  Future<Result<Wallet>> payPlanFee({
    String? simLineId,
    String? referenceId,
    String plan = 'standard',
    String? carrierRuleId,
    double? expectedAmount,
  }) async {
    if (_connectivity.isOffline) {
      return const Failure(
        AppFailure.server(
          message: 'Plan payments require an active internet connection.',
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

      // Priced and debited server-side; the reference id makes a retry of this
      // exact attempt adopt the original debit instead of paying twice. The
      // caller supplies it when it is resuming a fee it already paid for but
      // could not spend — see [PendingPlanFee].
      final reference =
          referenceId ??
          'planfee_${userId.substring(0, 8)}_${DateTime.now().microsecondsSinceEpoch}';
      final response = await _client.rpc(
        'pay_quoted_plan_fee_from_wallet',
        params: {
          'p_reference_id': reference,
          'p_expected_amount': expectedAmount,
          'p_sim_line_id': simLineId,
          // The device rides along for the same reason it does on a gift:
          // without it `guard_money_action` scores every plan fee
          // `missing_device_id`, which is the risk signal it exists to avoid.
          'p_device_id': await _deviceIdentity.deviceId(),
          // J8. The plan names WHAT is being bought; the price still comes from
          // the server. A Premium purchase for a line that does not exist yet
          // is priced from the carrier rule the form already picked.
          'p_plan': plan,
          'p_carrier_rule_id': carrierRuleId,
        },
      );

      // Only *some* refusals raise. UNAUTHORIZED, a suspended account and a
      // DEVICE_BLOCKED verdict all come back as a 200 with success:false and
      // no debit — read as a paid fee if the body is ignored, which is how a
      // paid line could be created for free.
      //
      // Reported as a server failure, never a validation one: the controller
      // reads a validation failure as "insufficient, fall back to PayPal", and
      // a suspended or device-blocked account must surface rather than quietly
      // reroute to a card. Insufficient balance is not in this branch at all —
      // the function RAISEs for that, caught below.
      final result = PlanFeeResult.fromRpc(response);
      if (!result.isPaid) {
        return Failure(AppFailure.server(message: result.message));
      }

      return await getWallet();
    } on PostgrestException catch (e) {
      if (e.message.contains('Insufficient wallet balance')) {
        return const Failure(
          AppFailure.validation(
            message: 'Insufficient funds for this transaction.',
          ),
        );
      }
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<GiftTransferResult>> sendGift({
    required String recipientEmail,
    required double amount,
    String? note,
    String? referenceId,
  }) async {
    if (_connectivity.isOffline) {
      return const Failure(
        AppFailure.server(
          message: 'Sending credit requires an active internet connection.',
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

      // Stable per attempt: if the response is lost to a dropped connection and
      // the user taps Send again, the server recognises this id and reports the
      // original transfer instead of making a second one. Same shape as
      // payPlanFee's `planfee_` reference.
      final reference =
          referenceId ??
          'gift_${userId.substring(0, 8)}_${DateTime.now().microsecondsSinceEpoch}';

      final response = await _client.rpc(
        'transfer_wallet_credit',
        params: {
          'p_recipient_email': recipientEmail,
          'p_amount': amount,
          'p_reference_id': reference,
          'p_note': note,
          'p_device_id': await _deviceIdentity.deviceId(),
        },
      );

      if (response is! Map<String, dynamic>) {
        return const Failure(
          AppFailure.server(
            message: 'Unexpected response from wallet service.',
          ),
        );
      }

      final result = GiftTransferResult.fromJson(response);

      // A completed transfer changes both the balance and the ledger the
      // offline cache is holding.
      if (result.success) {
        await _cache.remove('cached_wallet');
        await _cache.remove('cached_wallet_transactions');
      }

      return Success(result);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> getWalletSummary() async {
    if (_connectivity.isOffline) {
      final cached = _cache.readJson('cached_wallet_summary');
      if (cached is Map<String, dynamic>) {
        return Success(cached);
      }
      return const Failure(
        AppFailure.server(
          message: 'No internet connection and no cached summary.',
        ),
      );
    }
    try {
      final res = await _walletTransact({'action': 'summary'});
      if (res['success'] == true && res['summary'] is Map<String, dynamic>) {
        final summary = res['summary'] as Map<String, dynamic>;
        await _cache.writeJson('cached_wallet_summary', summary);
        return Success(summary);
      }
      return Failure(
        AppFailure.server(
          message:
              res['errorMessage']?.toString() ??
              'Failed to fetch wallet summary.',
        ),
      );
    } catch (e) {
      final cached = _cache.readJson('cached_wallet_summary');
      if (cached is Map<String, dynamic>) {
        return Success(cached);
      }
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> quoteRefund() async {
    if (_connectivity.isOffline) {
      return const Failure(
        AppFailure.network(
          message: 'Internet connection required to quote refund.',
        ),
      );
    }
    try {
      final res = await _walletTransact({'action': 'quote_refund'});
      if (res['success'] == true && res['quote'] is Map<String, dynamic>) {
        return Success(res['quote'] as Map<String, dynamic>);
      }
      return Failure(
        AppFailure.server(
          message: res['errorMessage']?.toString() ?? 'Failed to quote refund.',
        ),
      );
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> requestRefund({
    required double amount,
    String? reason,
  }) async {
    if (_connectivity.isOffline) {
      return const Failure(
        AppFailure.network(
          message: 'Internet connection required to request refund.',
        ),
      );
    }
    if (!amount.isFinite ||
        amount <= 0 ||
        amount > 99999999.99 ||
        (amount * 100 - (amount * 100).round()).abs() > 0.0000001) {
      return const Failure(
        AppFailure.validation(message: 'Enter a valid refund amount.'),
      );
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Failure(AppFailure.auth());
    final cacheKey = 'pending_refund_${userId}_${(amount * 100).round()}';
    try {
      // Keep the same identity across timeout, restart and token-recovery retry.
      // Never expire an uncertain refund intent into a second withdrawal.
      final cached = _cache.readJson(cacheKey);
      final cachedKey = cached is Map ? cached['request_key'] : null;
      final requestKey = _refundRequestKeys.putIfAbsent(cacheKey, () {
        if (cachedKey is String &&
            RegExp(r'^refund_[a-f0-9]{32}$').hasMatch(cachedKey)) {
          return cachedKey;
        }
        final random = Random.secure();
        return 'refund_${List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join()}';
      });
      if (!await _cache.writeJson(cacheKey, {'request_key': requestKey})) {
        return const Failure(
          AppFailure.server(
            message:
                'Refund retry information could not be saved. Please try again.',
          ),
        );
      }
      final res = await _walletTransact({
        'action': 'request_refund',
        'expected_user_id': userId,
        'amount': amount,
        'description': reason ?? 'Customer requested refund',
        'refund_request_key': requestKey,
      });
      final result = res['result'];
      if (res['success'] == true &&
          result is Map<String, dynamic> &&
          result['refund_request_id'] is String &&
          RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(result['refund_request_id'] as String)) {
        await _cache.remove(cacheKey);
        _refundRequestKeys.remove(cacheKey);
        await _cache.remove('cached_wallet');
        await _cache.remove('cached_wallet_transactions');
        await _cache.remove('cached_wallet_summary');
        return Success(result);
      }
      return Failure(
        AppFailure.server(
          message:
              res['errorMessage']?.toString() ??
              'Failed to submit refund request.',
        ),
      );
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }
}
