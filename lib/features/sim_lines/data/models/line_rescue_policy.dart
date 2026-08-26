/// SIM Shield — per-line auto-rescue policy (G7)
///
/// Maps `sim_line_rescue_policy`. The client reads the row through RLS and
/// writes it only through `set_line_rescue_policy()`, which is why there is no
/// `toJson` write path here.
///
/// **`maxUsd == 0` means the line is NOT insured.** It is not "no limit" — it
/// is the default, and the fail-closed state. The same idiom as G6's household
/// cap: the cap is the permission, so there is no second boolean to fall out of
/// step with it.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'line_rescue_policy.freezed.dart';
part 'line_rescue_policy.g.dart';

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

int _parseLeadDays(dynamic value) => _parseInt(value, 2);
int _parseWarnLeadDays(dynamic value) => _parseInt(value, 3);
int _parseRescueCount(dynamic value) => _parseInt(value, 0);

@freezed
abstract class LineRescuePolicy with _$LineRescuePolicy {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LineRescuePolicy({
    required String simLineId,
    required String userId,

    /// The most one rescue may cost. 0 = insurance off.
    @JsonKey(fromJson: _parseDouble)
    @Default(0.0) double maxUsd,

    /// Rescue when the forecast says this many days of life remain.
    @JsonKey(fromJson: _parseLeadDays)
    @Default(2) int leadDays,

    /// Warn this many days before that, giving the user a chance to act first.
    @JsonKey(fromJson: _parseWarnLeadDays)
    @Default(3) int warnLeadDays,

    /// When the warning that starts the grace clock was written. Null means no
    /// warning is outstanding — either none was needed, or the user acted.
    DateTime? lastWarnedAt,
    DateTime? lastRescueAt,
    String? lastRescueExecutionId,
    @JsonKey(fromJson: _parseRescueCount)
    @Default(0) int rescueCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _LineRescuePolicy;

  const LineRescuePolicy._();

  factory LineRescuePolicy.fromJson(Map<String, dynamic> json) =>
      _$LineRescuePolicyFromJson(json);

  bool get isInsured => maxUsd > 0;

  /// True while the user is inside the window where they can still act before
  /// money moves. The server is the authority — this only decides whether to
  /// show the countdown, never whether to spend.
  bool get hasOutstandingWarning => isInsured && lastWarnedAt != null;

  /// Hours left of the grace period, given the server's configured window.
  /// Mirrors `system_configs.RESCUE_GRACE_HOURS`; display only.
  int graceHoursLeft({int graceHours = 24}) {
    final DateTime? warned = lastWarnedAt;
    if (warned == null) return 0;
    final int elapsed = DateTime.now().toUtc().difference(warned.toUtc()).inHours;
    final int left = graceHours - elapsed;
    return left < 0 ? 0 : left;
  }

  bool get hasEverRescued => rescueCount > 0;
}
