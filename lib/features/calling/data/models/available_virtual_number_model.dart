/// KeepSIMs — Available Virtual Number Model (Live Telnyx Inventory + App Fee)
library;

class AvailableVirtualNumber {
  final String phoneNumber;
  final String formattedNumber;
  final String countryCode;
  final String? state;
  final String? city;
  final String phoneNumberType;
  final List<String> features;
  final double wholesaleMonthlyUsd;
  final double wholesaleUpfrontUsd;
  final double appFeePercent;
  final double appFeeUsd;
  final double totalMonthlyUsd;
  final String userTier;
  final String currency;

  const AvailableVirtualNumber({
    required this.phoneNumber,
    required this.formattedNumber,
    required this.countryCode,
    this.state,
    this.city,
    required this.phoneNumberType,
    required this.features,
    required this.wholesaleMonthlyUsd,
    required this.wholesaleUpfrontUsd,
    required this.appFeePercent,
    required this.appFeeUsd,
    required this.totalMonthlyUsd,
    required this.userTier,
    required this.currency,
  });

  String get locationDisplay {
    final parts = [city, state].where((p) => p != null && p.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return countryCode;
  }

  String get flagEmoji {
    final code = countryCode.toUpperCase();
    if (code.length != 2) return '🌐';
    final int first = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int second = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  factory AvailableVirtualNumber.fromJson(Map<String, dynamic> json) {
    return AvailableVirtualNumber(
      phoneNumber: json['phone_number'] as String,
      formattedNumber: json['formatted_number'] as String? ?? json['phone_number'] as String,
      countryCode: json['country_code'] as String? ?? 'US',
      state: json['state'] as String?,
      city: json['city'] as String?,
      phoneNumberType: json['phone_number_type'] as String? ?? 'local',
      features: (json['features'] as List?)?.map((e) => e.toString()).toList() ?? [],
      wholesaleMonthlyUsd: ((json['wholesale_monthly_usd'] ?? 1.0) as num).toDouble(),
      wholesaleUpfrontUsd: ((json['wholesale_upfront_usd'] ?? 0.0) as num).toDouble(),
      appFeePercent: ((json['app_fee_percent'] ?? 15.0) as num).toDouble(),
      appFeeUsd: ((json['app_fee_usd'] ?? 0.15) as num).toDouble(),
      totalMonthlyUsd: ((json['total_monthly_usd'] ?? 1.15) as num).toDouble(),
      userTier: json['user_tier'] as String? ?? 'free',
      currency: json['currency'] as String? ?? 'USD',
    );
  }
}
