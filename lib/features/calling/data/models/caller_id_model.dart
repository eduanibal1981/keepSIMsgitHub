/// KeepSIMs — Caller ID Model
library;

class CallerIdModel {
  final String id;
  final String phoneNumber;
  final String label;
  final bool isVerified;
  final bool isDefault;
  final DateTime? verifiedAt;

  const CallerIdModel({
    required this.id,
    required this.phoneNumber,
    this.label = 'Mobile Number',
    this.isVerified = false,
    this.isDefault = false,
    this.verifiedAt,
  });

  factory CallerIdModel.fromJson(Map<String, dynamic> json) {
    return CallerIdModel(
      id: json['id'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      label: json['label'] as String? ?? 'Mobile Number',
      isVerified: json['is_verified'] as bool? ?? false,
      isDefault: json['is_default'] as bool? ?? false,
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'] as String)
          : null,
    );
  }
}
