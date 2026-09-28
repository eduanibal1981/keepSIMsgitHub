/// KeepSIMs — Carrier Call Forwarding & Divert Rule Model
library;

class CarrierDivertRule {
  final String carrierId;
  final String carrierName;
  final String countryCode;
  final String countryName;
  final String? flagEmoji;
  final String? dialingCode;
  final String cfuFormat;
  final String cfuCancel;
  final String cfuStatus;
  final String cancelAll;
  final String? specialNotes;

  const CarrierDivertRule({
    required this.carrierId,
    required this.carrierName,
    required this.countryCode,
    required this.countryName,
    this.flagEmoji,
    this.dialingCode,
    required this.cfuFormat,
    required this.cfuCancel,
    required this.cfuStatus,
    required this.cancelAll,
    this.specialNotes,
  });

  /// Formats the CFU activation code for the given destination virtual number.
  String formatActivationCode(String destinationNumber) {
    final clean = destinationNumber.trim();
    return cfuFormat.replaceAll('{number}', clean);
  }

  /// Label for dropdown display (e.g. "STC (Saudi Arabia)")
  String get displayName => '$carrierName ($countryName)';

  factory CarrierDivertRule.fromJson(Map<String, dynamic> json) {
    return CarrierDivertRule(
      carrierId: json['carrier_id'] as String? ?? '',
      carrierName: json['carrier_name'] as String? ?? 'Carrier',
      countryCode: json['country_code'] as String? ?? '',
      countryName: json['country_name'] as String? ?? '',
      flagEmoji: json['flag_emoji'] as String?,
      dialingCode: json['dialing_code'] as String?,
      cfuFormat: json['cfu_format'] as String? ?? '**21*{number}#',
      cfuCancel: json['cfu_cancel'] as String? ?? '##21#',
      cfuStatus: json['cfu_status'] as String? ?? '*#21#',
      cancelAll: json['cancel_all'] as String? ?? '##002#',
      specialNotes: json['special_notes'] as String?,
    );
  }
}
