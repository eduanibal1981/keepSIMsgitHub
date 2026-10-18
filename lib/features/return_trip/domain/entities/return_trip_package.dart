/// Return Trip Package Entity
library;

class ReturnTripPackage {
  final String id;
  final String countryId;
  final String? carrierId;
  final String? carrierName;
  final String packageType; // 'esim', 'carrier_ussd', 'physical_voucher'
  final String title;
  final String? description;
  final int dataAllowanceMb;
  final int durationDays;
  final bool isUnlimited;
  final double retailPriceUsd;
  final double effectivePriceUsd;
  final double discountUsd;
  final String? ussdRechargeCode;
  final String? activationInstructions;
  final String? badgeLabel;
  final String accountTier; // 'free', 'standard', 'premium'

  const ReturnTripPackage({
    required this.id,
    required this.countryId,
    this.carrierId,
    this.carrierName,
    required this.packageType,
    required this.title,
    this.description,
    required this.dataAllowanceMb,
    required this.durationDays,
    required this.isUnlimited,
    required this.retailPriceUsd,
    required this.effectivePriceUsd,
    required this.discountUsd,
    this.ussdRechargeCode,
    this.activationInstructions,
    this.badgeLabel,
    this.accountTier = 'free',
  });

  bool get isEsim => packageType == 'esim';
  bool get isCarrierUssd => packageType == 'carrier_ussd';

  String get formattedAllowance {
    if (isUnlimited) return 'Unlimited';
    if (dataAllowanceMb >= 1024) {
      final gb = (dataAllowanceMb / 1024).toStringAsFixed(
        dataAllowanceMb % 1024 == 0 ? 0 : 1,
      );
      return '$gb GB';
    }
    return '$dataAllowanceMb MB';
  }

  String get formattedDuration {
    if (durationDays == 1) return '1 day';
    if (durationDays == 7) return '7 days';
    if (durationDays == 30) return '30 days';
    return '$durationDays days';
  }

  factory ReturnTripPackage.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return ReturnTripPackage(
      id: json['id'] as String? ?? '',
      countryId: json['country_id'] as String? ?? '',
      carrierId: json['carrier_id'] as String?,
      carrierName: json['carrier_name'] as String?,
      packageType: json['package_type'] as String? ?? 'esim',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      dataAllowanceMb: parseInt(json['data_allowance_mb']),
      durationDays: parseInt(json['duration_days']),
      isUnlimited: json['is_unlimited'] as bool? ?? false,
      retailPriceUsd: parseDouble(json['retail_price_usd']),
      effectivePriceUsd: parseDouble(
        json['effective_price_usd'] ?? json['retail_price_usd'],
      ),
      discountUsd: parseDouble(json['discount_usd']),
      ussdRechargeCode: json['ussd_recharge_code'] as String?,
      activationInstructions: json['activation_instructions'] as String?,
      badgeLabel: json['badge_label'] as String?,
      accountTier: json['account_tier'] as String? ?? 'free',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'country_id': countryId,
    'carrier_id': carrierId,
    'carrier_name': carrierName,
    'package_type': packageType,
    'title': title,
    'description': description,
    'data_allowance_mb': dataAllowanceMb,
    'duration_days': durationDays,
    'is_unlimited': isUnlimited,
    'retail_price_usd': retailPriceUsd,
    'effective_price_usd': effectivePriceUsd,
    'discount_usd': discountUsd,
    'ussd_recharge_code': ussdRechargeCode,
    'activation_instructions': activationInstructions,
    'badge_label': badgeLabel,
    'account_tier': accountTier,
  };
}
