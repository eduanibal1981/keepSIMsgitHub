/// SIM Shield — Wallet Models
///
/// Maps to `wallets` and `wallet_transactions` tables in Supabase.
/// Uses Freezed v3 with snake_case serialization.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_model.freezed.dart';
part 'wallet_model.g.dart';

@freezed
abstract class Wallet with _$Wallet {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Wallet({
    @Default('') String id,
    @Default('') String userId,
    @Default(0.0) double balance,
    @Default('USD') String currency,
    @Default(false) bool autoFundEnabled,
    double? autoFundThreshold,
    double? autoFundAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Wallet;

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);
}

@freezed
abstract class WalletTransaction with _$WalletTransaction {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory WalletTransaction({
    @Default('') String id,
    @Default('') String walletId,
    @Default('') String userId,
    @Default(0.0) double amount,
    @Default(0.0) double balanceBefore,
    @Default(0.0) double balanceAfter,
    @Default('deposit') String type, // 'deposit', 'topup_debit', 'referral_credit'
    String? description,
    String? referenceId,
    DateTime? createdAt,
  }) = _WalletTransaction;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      _$WalletTransactionFromJson(json);
}
