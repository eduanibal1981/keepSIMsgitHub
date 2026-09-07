/// SIM Shield — Payments Repository
///
/// Implements [PaymentsContract] using Supabase.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/payments/model/payment_method_model.dart';
import 'package:keep_sims/features/wallet/model/wallet_model.dart';
import '../contract/payments_contract.dart';

class PaymentsRepository implements PaymentsContract {
  final SupabaseClient _client;

  PaymentsRepository(this._client);

  @override
  Future<Result<List<PaymentMethod>>> getPaymentMethods() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final response = await _client
          .from('payment_methods')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      final methods = (response as List)
          .map((json) => PaymentMethod.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(methods);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<PaymentMethod>> addPaymentMethod({
    required String provider,
    required String lastFour,
    required int expiryMonth,
    required int expiryYear,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      // Direct card token vaulting without a certified gateway is not supported.
      // Card funding is performed securely through PayPal hosted checkout.
      return const Failure(
        AppFailure.validation(
          message:
              'Direct card storage is not supported. Please use PayPal to fund your wallet using a card.',
        ),
      );
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> deletePaymentMethod(String id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      // 1. Fetch details of card to be deleted to check if it was default
      final cardRes = await _client
          .from('payment_methods')
          .select()
          .eq('id', id)
          .single();
      final card = PaymentMethod.fromJson(cardRes);

      // 2. Delete the card
      await _client.from('payment_methods').delete().eq('id', id);

      // 3. If it was default, make the next latest remaining card default
      if (card.isDefault) {
        final remainingRes = await _client
            .from('payment_methods')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        final remainingList = (remainingRes as List);

        if (remainingList.isNotEmpty) {
          final nextDefaultId = remainingList.first['id'];
          await _client
              .from('payment_methods')
              .update({'is_default': true})
              .eq('id', nextDefaultId);
        }
      }

      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> setDefaultPaymentMethod(String id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      // Reset default status on all other user cards
      await _client
          .from('payment_methods')
          .update({'is_default': false})
          .eq('user_id', userId);

      // Set default status on specified card
      await _client
          .from('payment_methods')
          .update({'is_default': true})
          .eq('id', id);

      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<Wallet>> updateAutoFundSettings({
    required bool autoFundEnabled,
    required double autoFundThreshold,
    required double autoFundAmount,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final response = await _client
          .from('wallets')
          .update({
            'auto_fund_enabled': autoFundEnabled,
            'auto_fund_threshold': autoFundThreshold,
            'auto_fund_amount': autoFundAmount,
          })
          .eq('user_id', userId)
          .select()
          .single();

      return Success(Wallet.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }
}
