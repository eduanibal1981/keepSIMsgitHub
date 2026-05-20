/// SIM Shield — Payments Contract Interface
///
/// Interface defining standard billing card management operations and wallet auto-fund updates.

import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/payments/model/payment_method_model.dart';
import 'package:keep_sims/features/wallet/model/wallet_model.dart';

abstract class PaymentsContract {
  /// Fetches a list of payment methods for the current user.
  Future<Result<List<PaymentMethod>>> getPaymentMethods();

  /// Adds a new payment method for the current user.
  Future<Result<PaymentMethod>> addPaymentMethod({
    required String provider,
    required String lastFour,
    required int expiryMonth,
    required int expiryYear,
  });

  /// Deletes a payment method by its unique identifier.
  Future<Result<void>> deletePaymentMethod(String id);

  /// Sets a payment method as the default payment method.
  Future<Result<void>> setDefaultPaymentMethod(String id);

  /// Updates the auto-fund configurations in the wallets table.
  Future<Result<Wallet>> updateAutoFundSettings({
    required bool autoFundEnabled,
    required double autoFundThreshold,
    required double autoFundAmount,
  });
}
