/// Active Return Trip Information Entity
library;

import 'package:intl/intl.dart';

class ActiveReturnTripInfo {
  final String tripId;
  final String simLineId;
  final String destinationCountryId;
  final DateTime arrivalDate;
  final String status;
  final String? packageId;
  final String packageType; // 'esim', 'carrier_ussd', 'physical_voucher'
  final String packageTitle;
  final String? carrierName;
  final int dataAllowanceMb;
  final int durationDays;
  final bool isUnlimited;
  final double? effectivePriceUsd;
  final String? ussdRechargeCode;
  final String? activationInstructions;
  final String? badgeLabel;
  final String? notes;
  final DateTime createdAt;

  const ActiveReturnTripInfo({
    required this.tripId,
    required this.simLineId,
    required this.destinationCountryId,
    required this.arrivalDate,
    required this.status,
    this.packageId,
    required this.packageType,
    required this.packageTitle,
    this.carrierName,
    required this.dataAllowanceMb,
    required this.durationDays,
    required this.isUnlimited,
    required this.effectivePriceUsd,
    this.ussdRechargeCode,
    this.activationInstructions,
    this.badgeLabel,
    this.notes,
    required this.createdAt,
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

  String get formattedArrivalDate {
    return DateFormat('MMM d, yyyy').format(arrivalDate);
  }

  String get fullArrivalDateFormatted {
    return DateFormat('EEEE, MMMM d, yyyy').format(arrivalDate);
  }

  factory ActiveReturnTripInfo.fromJson(Map<String, dynamic> json) {
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

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return ActiveReturnTripInfo(
      tripId: json['trip_id'] as String? ?? '',
      simLineId: json['sim_line_id'] as String? ?? '',
      destinationCountryId: json['destination_country_id'] as String? ?? '',
      arrivalDate: parseDate(json['arrival_date']),
      status: json['status'] as String? ?? 'planning',
      packageId: json['package_id'] as String?,
      packageType: json['package_type'] as String? ?? 'carrier_ussd',
      packageTitle: json['package_title'] as String? ?? 'Prepared Data Package',
      carrierName: json['carrier_name'] as String?,
      dataAllowanceMb: parseInt(json['data_allowance_mb']),
      durationDays: parseInt(json['duration_days']),
      isUnlimited: json['is_unlimited'] as bool? ?? false,
      effectivePriceUsd: json['effective_price_usd'] == null
          ? null
          : parseDouble(json['effective_price_usd']),
      ussdRechargeCode: json['ussd_recharge_code'] as String?,
      activationInstructions: json['activation_instructions'] as String?,
      badgeLabel: json['badge_label'] as String?,
      notes: json['notes'] as String?,
      createdAt: parseDate(json['created_at']),
    );
  }
}
