/// A server-priced retail quote for a second number.
library;

class AvailableVirtualNumber {
  final String phoneNumber;
  final String formattedNumber;
  final String countryCode;
  final String? state;
  final String? city;
  final String phoneNumberType;
  final List<String> features;
  final double setupFeeUsd;
  final double totalMonthlyUsd;
  final String currency;
  final String? quoteId;
  final DateTime? quoteExpiresAt;
  final String usageTerms;
  final int billingPeriodDays;

  const AvailableVirtualNumber({
    required this.phoneNumber,
    required this.formattedNumber,
    required this.countryCode,
    this.state,
    this.city,
    required this.phoneNumberType,
    required this.features,
    required this.setupFeeUsd,
    required this.totalMonthlyUsd,
    required this.currency,
    this.quoteId,
    this.quoteExpiresAt,
    this.usageTerms = '',
    this.billingPeriodDays = 30,
  });

  String get locationDisplay {
    final parts = [
      city,
      state,
    ].where((p) => p != null && p.isNotEmpty).toList();
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
      formattedNumber:
          json['formatted_number'] as String? ?? json['phone_number'] as String,
      countryCode: json['country_code'] as String? ?? 'US',
      state: json['state'] as String?,
      city: json['city'] as String?,
      phoneNumberType: json['phone_number_type'] as String? ?? 'local',
      features:
          (json['features'] as List?)?.map((e) => e.toString()).toList() ?? [],
      setupFeeUsd: (json['setup_fee_usd'] as num).toDouble(),
      totalMonthlyUsd: (json['total_monthly_usd'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      quoteId: json['quote_id'] as String?,
      quoteExpiresAt: DateTime.tryParse(
        json['quote_expires_at'] as String? ?? '',
      ),
      usageTerms: json['usage_terms'] as String? ?? '',
      billingPeriodDays: (json['billing_period_days'] as num?)?.toInt() ?? 30,
    );
  }
}
