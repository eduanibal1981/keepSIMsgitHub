class EsimControlSnapshot {
  const EsimControlSnapshot(this.controls, this.automation);
  final Map<String, dynamic> controls, automation;
  String get status => controls['status'] as String? ?? 'UNAVAILABLE';
  String? get ownerId => controls['owner_id'] as String?;
  bool get cancellationEnabled => controls['cancellation_enabled'] == true;
  bool get suspendEnabled => controls['suspend_enabled'] == true;
  bool get resumeEnabled => controls['resume_enabled'] == true;
  String get cancellationReason =>
      controls['cancellation_reason'] as String? ?? 'Review the refund below.';
  List<Map<String, dynamic>> get refunds => _rows(controls['refunds']);
  List<Map<String, dynamic>> get operations => _rows(controls['operations']);
  Map<String, dynamic>? get consent => automation['consent'] is Map
      ? Map<String, dynamic>.from(automation['consent'] as Map)
      : null;
  int get revision => (consent?['revision'] as num?)?.toInt() ?? 0;
  bool get autoEnabled => consent?['enabled'] == true;
  bool get autoAvailable => automation['available'] == true;
  static List<Map<String, dynamic>> _rows(dynamic v) => v is List
      ? v.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList()
      : const [];
}

class EsimAutomationSettings {
  const EsimAutomationSettings({
    required this.packageId,
    required this.daily,
    required this.maxCents,
    required this.monthlyCents,
    required this.threshold,
    required this.intervalHours,
    this.days,
    this.endsAt,
  });
  final String packageId;
  final bool daily;
  final int maxCents, monthlyCents, threshold, intervalHours;
  final int? days;
  final DateTime? endsAt;
  bool get valid =>
      packageId.isNotEmpty &&
      packageId.length <= 100 &&
      maxCents > 0 &&
      monthlyCents >= maxCents &&
      intervalHours >= 1 &&
      intervalHours <= 720 &&
      threshold >= 1 &&
      threshold <= (daily ? 168 : 50) &&
      (daily ? days != null && days! >= 1 && days! <= 365 : days == null) &&
      (endsAt == null || endsAt!.isAfter(DateTime.now()));
  Map<String, dynamic> toJson() => {
    'package_id': packageId,
    'trigger': daily ? 'daily_near_expiry' : 'fixed_low_data',
    'max_charge': maxCents / 100,
    'monthly_cap': monthlyCents / 100,
    'threshold': threshold,
    'minimum_interval_hours': intervalHours,
    'period_count': days,
    'ends_at': endsAt?.toUtc().toIso8601String(),
  };
  static DateTime? parseLocalEnd(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final parts = value.split('-').map(int.parse).toList();
    final date = DateTime(parts[0], parts[1], parts[2]);
    return date.year == parts[0] &&
            date.month == parts[1] &&
            date.day == parts[2]
        ? date
        : null;
  }

  static int? parseCents(String value) {
    if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(value.trim())) return null;
    final parts = value.trim().split('.');
    return int.parse(parts.first) * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  }
}
