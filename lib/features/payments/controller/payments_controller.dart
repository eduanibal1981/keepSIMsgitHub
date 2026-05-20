/// SIM Shield — Payments Controller
///
/// Manages reactive state for card lists and wallet auto-funding rules.
/// Reactively aggregates authentication and wallet information, and invalidates subsystems upon save.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/features/wallet/model/wallet_model.dart';
import 'package:keep_sims/features/payments/model/payment_method_model.dart';

part 'payments_controller.g.dart';

/// Aggregated state for the Payments feature.
class PaymentsState {
  final List<PaymentMethod> paymentMethods;
  final Wallet? wallet;
  final bool isSubmitting;

  const PaymentsState({
    required this.paymentMethods,
    this.wallet,
    this.isSubmitting = false,
  });

  PaymentsState copyWith({
    List<PaymentMethod>? paymentMethods,
    Wallet? wallet,
    bool? isSubmitting,
  }) {
    return PaymentsState(
      paymentMethods: paymentMethods ?? this.paymentMethods,
      wallet: wallet ?? this.wallet,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

@riverpod
class PaymentsController extends _$PaymentsController {
  @override
  FutureOr<PaymentsState> build() async {
    // 1. Watch auth state
    final authProfile = ref.watch(authControllerProvider);
    final profile = authProfile.valueOrNull;
    if (profile == null) {
      throw Exception('User is not authenticated');
    }

    // 2. Watch wallet state reactively
    final walletState = ref.watch(walletControllerProvider).valueOrNull;
    final wallet = walletState?.wallet;

    final repo = ref.watch(paymentsRepositoryProvider);

    // 3. Fetch payment methods
    final result = await repo.getPaymentMethods();

    switch (result) {
      case Success(data: final methods):
        return PaymentsState(
          paymentMethods: methods,
          wallet: wallet,
        );
      case Failure(error: final f):
        throw Exception(f.message);
    }
  }

  /// Adds a new mock payment card. Returns error string if it fails, null on success.
  Future<String?> addPaymentMethod({
    required String provider,
    required String lastFour,
    required int expiryMonth,
    required int expiryYear,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return 'Session expired. Please sign in again.';

    state = AsyncData(current.copyWith(isSubmitting: true));

    final repo = ref.read(paymentsRepositoryProvider);
    final result = await repo.addPaymentMethod(
      provider: provider,
      lastFour: lastFour,
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
    );

    switch (result) {
      case Success():
        ref.invalidateSelf();
        return null;
      case Failure(error: final f):
        state = AsyncData(current.copyWith(isSubmitting: false));
        return f.message;
    }
  }

  /// Deletes a payment method. Returns error string if it fails, null on success.
  Future<String?> deletePaymentMethod(String id) async {
    final current = state.valueOrNull;
    if (current == null) return 'Session expired. Please sign in again.';

    state = AsyncData(current.copyWith(isSubmitting: true));

    final repo = ref.read(paymentsRepositoryProvider);
    final result = await repo.deletePaymentMethod(id);

    switch (result) {
      case Success():
        ref.invalidateSelf();
        return null;
      case Failure(error: final f):
        state = AsyncData(current.copyWith(isSubmitting: false));
        return f.message;
    }
  }

  /// Sets a payment card as default. Returns error string if it fails, null on success.
  Future<String?> setDefaultPaymentMethod(String id) async {
    final current = state.valueOrNull;
    if (current == null) return 'Session expired. Please sign in again.';

    state = AsyncData(current.copyWith(isSubmitting: true));

    final repo = ref.read(paymentsRepositoryProvider);
    final result = await repo.setDefaultPaymentMethod(id);

    switch (result) {
      case Success():
        ref.invalidateSelf();
        return null;
      case Failure(error: final f):
        state = AsyncData(current.copyWith(isSubmitting: false));
        return f.message;
    }
  }

  /// Updates wallet auto-funding preferences. Returns error string if it fails, null on success.
  Future<String?> updateAutoFundSettings({
    required bool autoFundEnabled,
    required double autoFundThreshold,
    required double autoFundAmount,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return 'Session expired. Please sign in again.';

    state = AsyncData(current.copyWith(isSubmitting: true));

    final repo = ref.read(paymentsRepositoryProvider);
    final result = await repo.updateAutoFundSettings(
      autoFundEnabled: autoFundEnabled,
      autoFundThreshold: autoFundThreshold,
      autoFundAmount: autoFundAmount,
    );

    switch (result) {
      case Success():
        // Invalidate wallet controller to sync the low-balance threshold immediately!
        ref.invalidate(walletControllerProvider);
        ref.invalidateSelf();
        return null;
      case Failure(error: final f):
        state = AsyncData(current.copyWith(isSubmitting: false));
        return f.message;
    }
  }
}
