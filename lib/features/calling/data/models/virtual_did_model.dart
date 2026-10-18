/// KeepSIMs — Virtual DID Number Model
library;

class VirtualDidNumber {
  final String id;
  final String phoneNumber;
  final String countryCode;
  final String countryName;
  final String status;
  final double monthlyFeeUsd;
  final String forwardMode; // 'app', 'pstn', 'voicemail', 'sim_roaming'
  final String? forwardDestination;
  final DateTime renewsAt;
  final DateTime createdAt;
  final String numberType;
  final bool supportsSms;
  final bool supportsVoice;
  final bool autoRenew;
  final String kycStatus;
  final int unreadSmsCount;
  final int billingPeriodDays;
  final DateTime? graceExpiresAt;
  final bool lifecycleManaged;

  const VirtualDidNumber({
    required this.id,
    required this.phoneNumber,
    required this.countryCode,
    required this.countryName,
    required this.status,
    required this.monthlyFeeUsd,
    required this.forwardMode,
    this.forwardDestination,
    required this.renewsAt,
    required this.createdAt,
    this.numberType = 'unknown',
    this.supportsSms = false,
    this.supportsVoice = false,
    this.autoRenew = false,
    this.kycStatus = 'unknown',
    this.unreadSmsCount = 0,
    this.billingPeriodDays = 30,
    this.graceExpiresAt,
    this.lifecycleManaged = false,
  });

  factory VirtualDidNumber.fromJson(Map<String, dynamic> json) {
    return VirtualDidNumber(
      id: json['id'] as String,
      phoneNumber: json['phone_number'] as String,
      countryCode: json['country_code'] as String? ?? 'US',
      countryName: json['country_name'] as String? ?? 'United States',
      status: json['status'] as String? ?? 'active',
      monthlyFeeUsd: (json['monthly_fee_usd'] as num).toDouble(),
      forwardMode: json['forward_mode'] as String? ?? 'app',
      forwardDestination: json['forward_destination'] as String?,
      renewsAt: json['renews_at'] != null
          ? DateTime.parse(json['renews_at'] as String)
          : DateTime.now().add(const Duration(days: 30)),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      numberType: json['number_type'] as String? ?? 'unknown',
      supportsSms: json['supports_sms'] == true,
      supportsVoice: json['supports_voice'] == true,
      autoRenew: json['auto_renew'] == true,
      kycStatus: json['kyc_status'] as String? ?? 'unknown',
      unreadSmsCount: (json['unread_sms_count'] as num?)?.toInt() ?? 0,
      billingPeriodDays: (json['billing_period_days'] as num?)?.toInt() ?? 30,
      graceExpiresAt: DateTime.tryParse(
        json['grace_expires_at'] as String? ?? '',
      ),
      lifecycleManaged: json['lifecycle_managed'] == true,
    );
  }

  String get forwardModeDisplay {
    switch (forwardMode) {
      case 'app':
        return 'KeepSIMs In-App (VoIP)';
      case 'pstn':
        return 'Forwarded to $forwardDestination';
      case 'voicemail':
        return 'Direct to AI Voicemail';
      case 'sim_roaming':
        return 'Local SIM Bridge ($forwardDestination)';
      default:
        return 'KeepSIMs App';
    }
  }

  String get flagEmoji {
    final code = countryCode.toUpperCase();
    if (code.length != 2) return '🌐';
    final int first = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int second = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}
