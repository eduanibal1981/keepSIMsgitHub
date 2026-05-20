// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Wallet _$WalletFromJson(Map<String, dynamic> json) => _Wallet(
  id: json['id'] as String? ?? '',
  userId: json['user_id'] as String? ?? '',
  balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
  currency: json['currency'] as String? ?? 'USD',
  autoFundEnabled: json['auto_fund_enabled'] as bool? ?? false,
  autoFundThreshold: (json['auto_fund_threshold'] as num?)?.toDouble(),
  autoFundAmount: (json['auto_fund_amount'] as num?)?.toDouble(),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$WalletToJson(_Wallet instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'balance': instance.balance,
  'currency': instance.currency,
  'auto_fund_enabled': instance.autoFundEnabled,
  'auto_fund_threshold': instance.autoFundThreshold,
  'auto_fund_amount': instance.autoFundAmount,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

_WalletTransaction _$WalletTransactionFromJson(Map<String, dynamic> json) =>
    _WalletTransaction(
      id: json['id'] as String? ?? '',
      walletId: json['wallet_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balanceBefore: (json['balance_before'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] as String? ?? 'deposit',
      description: json['description'] as String?,
      referenceId: json['reference_id'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$WalletTransactionToJson(_WalletTransaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'wallet_id': instance.walletId,
      'user_id': instance.userId,
      'amount': instance.amount,
      'balance_before': instance.balanceBefore,
      'balance_after': instance.balanceAfter,
      'type': instance.type,
      'description': instance.description,
      'reference_id': instance.referenceId,
      'created_at': instance.createdAt?.toIso8601String(),
    };
