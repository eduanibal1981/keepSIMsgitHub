import 'package:flutter/foundation.dart';

/// The authoritative in-app Alert Clock state for a SIM line.
///
/// Derived from `sim_line_alert_clock_states`, evaluating real carrier rules,
/// actual qualifying anchors, and truthful deactivation cutoffs.
///
/// Never invents or hallucinates 48-hour deadlines when anchors are missing.
@immutable
class SimLineAlertClockState {
  final String simLineId;
  final String userId;
  final String? carrierId;
  final String? carrierRuleId;
  final String? carrierName;
  final String activityRequirement;
  final int? inactivityLimitDays;
  final String? qualifyingActivityType;
  final DateTime? qualifyingActivityAt;
  final double? qualifyingActivityAmount;
  final DateTime? deactivationCutoffAt;
  final String precision;
  final String state;
  final String? ineligibilityReason;
  final double? hoursRemaining;
  final bool isWithin48h;
  final String? ruleSourceUrl;
  final DateTime? ruleLastVerifiedAt;
  final String? alertCycleToken;
  final DateTime? alertEmittedAt;
  final DateTime? evaluatedAt;
  final DateTime? updatedAt;

  const SimLineAlertClockState({
    required this.simLineId,
    required this.userId,
    this.carrierId,
    this.carrierRuleId,
    this.carrierName,
    this.activityRequirement = 'recharge_ok',
    this.inactivityLimitDays,
    this.qualifyingActivityType,
    this.qualifyingActivityAt,
    this.qualifyingActivityAmount,
    this.deactivationCutoffAt,
    this.precision = 'date',
    this.state = 'needs_activity_date',
    this.ineligibilityReason,
    this.hoursRemaining,
    this.isWithin48h = false,
    this.ruleSourceUrl,
    this.ruleLastVerifiedAt,
    this.alertCycleToken,
    this.alertEmittedAt,
    this.evaluatedAt,
    this.updatedAt,
  });

  factory SimLineAlertClockState.fromJson(Map<String, dynamic> json) {
    return SimLineAlertClockState(
      simLineId: json['sim_line_id'] as String,
      userId: json['user_id'] as String,
      carrierId: json['carrier_id'] as String?,
      carrierRuleId: json['carrier_rule_id'] as String?,
      carrierName: json['carrier_name'] as String?,
      activityRequirement: (json['activity_requirement'] as String?) ?? 'recharge_ok',
      inactivityLimitDays: json['inactivity_limit_days'] as int?,
      qualifyingActivityType: json['qualifying_activity_type'] as String?,
      qualifyingActivityAt: json['qualifying_activity_at'] != null
          ? DateTime.tryParse(json['qualifying_activity_at'].toString())
          : null,
      qualifyingActivityAmount: _parseNullableDouble(json['qualifying_activity_amount']),
      deactivationCutoffAt: json['deactivation_cutoff_at'] != null
          ? DateTime.tryParse(json['deactivation_cutoff_at'].toString())
          : null,
      precision: (json['precision'] as String?) ?? 'date',
      state: (json['state'] as String?) ?? 'needs_activity_date',
      ineligibilityReason: json['ineligibility_reason'] as String?,
      hoursRemaining: _parseNullableDouble(json['hours_remaining']),
      isWithin48h: json['is_within_48h'] == true,
      ruleSourceUrl: json['rule_source_url'] as String?,
      ruleLastVerifiedAt: json['rule_last_verified_at'] != null
          ? DateTime.tryParse(json['rule_last_verified_at'].toString())
          : null,
      alertCycleToken: json['alert_cycle_token'] as String?,
      alertEmittedAt: json['alert_emitted_at'] != null
          ? DateTime.tryParse(json['alert_emitted_at'].toString())
          : null,
      evaluatedAt: json['evaluated_at'] != null
          ? DateTime.tryParse(json['evaluated_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'sim_line_id': simLineId,
    'user_id': userId,
    'carrier_id': carrierId,
    'carrier_rule_id': carrierRuleId,
    'carrier_name': carrierName,
    'activity_requirement': activityRequirement,
    'inactivity_limit_days': inactivityLimitDays,
    'qualifying_activity_type': qualifyingActivityType,
    'qualifying_activity_at': qualifyingActivityAt?.toIso8601String(),
    'qualifying_activity_amount': qualifyingActivityAmount,
    'deactivation_cutoff_at': deactivationCutoffAt?.toIso8601String(),
    'precision': precision,
    'state': state,
    'ineligibility_reason': ineligibilityReason,
    'hours_remaining': hoursRemaining,
    'is_within_48h': isWithin48h,
    'rule_source_url': ruleSourceUrl,
    'rule_last_verified_at': ruleLastVerifiedAt?.toIso8601String(),
    'alert_cycle_token': alertCycleToken,
    'alert_emitted_at': alertEmittedAt?.toIso8601String(),
    'evaluated_at': evaluatedAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  bool get isEligible => state == 'eligible';
  bool get isNeedsActivityDate => state == 'needs_activity_date';
  bool get isNeedsAmount => state == 'needs_amount';
  bool get isNeedsUsage => state == 'needs_qualifying_usage';
  bool get isMissingRule => state == 'missing_rule';
  bool get isStaleRule => state == 'stale_rule';
  bool get isInactive => state == 'inactive_line' || state == 'carrier_deactivated';

  int? get daysRemaining => hoursRemaining != null ? (hoursRemaining! / 24.0).floor() : null;
}

double? _parseNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is String) return double.tryParse(value);
  if (value is num) return value.toDouble();
  return null;
}
