/// KeepSIMs — Call Rate Model
library;

class CallRate {
  final String id;
  final String countryCode;
  final String countryName;
  final String phonePrefix;
  final String destinationType;
  final double costPerMinute;
  final double ratePerMinute;
  final double connectionFee;
  final int billingIncrementSeconds;
  final bool isActive;
  final String? accountTier;

  const CallRate({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.phonePrefix,
    this.destinationType = 'all',
    required this.costPerMinute,
    required this.ratePerMinute,
    this.connectionFee = 0.0,
    this.billingIncrementSeconds = 1,
    this.isActive = true,
    this.accountTier,
  });

  double get ratePerSecond => ratePerMinute / 60.0;

  String get flagEmoji {
    final country = countryCode.toUpperCase();
    if (country.length != 2) return '🌐';
    final int first = country.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int second = country.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  factory CallRate.fromJson(Map<String, dynamic> json) {
    return CallRate(
      id: json['id'] as String? ?? json['rate_id'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? 'GLOBAL',
      countryName: json['country_name'] as String? ?? 'International Destination',
      phonePrefix: json['phone_prefix'] as String? ?? '+',
      destinationType: json['destination_type'] as String? ?? 'all',
      costPerMinute: (json['cost_per_minute_usd'] as num?)?.toDouble() ?? 0.0,
      ratePerMinute: (json['effective_rate_per_minute_usd'] as num?)?.toDouble() ??
          (json['rate_per_minute_usd'] as num?)?.toDouble() ??
          0.15,
      connectionFee: (json['connection_fee_usd'] as num?)?.toDouble() ?? 0.0,
      billingIncrementSeconds: json['billing_increment_seconds'] as int? ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      accountTier: json['account_tier'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'country_code': countryCode,
    'country_name': countryName,
    'phone_prefix': phonePrefix,
    'destination_type': destinationType,
    'cost_per_minute_usd': costPerMinute,
    'rate_per_minute_usd': ratePerMinute,
    'connection_fee_usd': connectionFee,
    'billing_increment_seconds': billingIncrementSeconds,
    'is_active': isActive,
  };
}
