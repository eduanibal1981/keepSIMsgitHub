int? _cents(dynamic value) {
  final n = num.tryParse(value?.toString() ?? '');
  return n == null || !n.isFinite || n < 0 ? null : (n * 100).round();
}

List<Map<String, dynamic>> _rows(dynamic value) => value is List
    ? value.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList()
    : const [];

class EsimTravellerIntent {
  const EsimTravellerIntent(this.offerId, this.label, {this.days});
  final String offerId, label;
  final int? days;
  bool get valid =>
      offerId.isNotEmpty &&
      offerId.length <= 120 &&
      label.length <= 60 &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(label) &&
      (days == null || (days! >= 1 && days! <= 365));
  Map<String, dynamic> toJson() => {
    'offer_id': offerId,
    'traveller_label': label,
    if (days != null) 'period_count': days,
  };
}

class EsimGroupQuote {
  const EsimGroupQuote(this.data);
  final Map<String, dynamic> data;
  String get status => data['status'] as String? ?? 'UNAVAILABLE';
  String? get id => data['quote_id'] as String?;
  String? get owner => data['owner_id'] as String?;
  String? get payer => data['payer_id'] as String?;
  String? get acceptanceKey => data['acceptance_key'] as String?;
  List<Map<String, dynamic>> get members => _rows(data['members']);
  int? get totalCents => _cents(data['retail_total']);
  String get totalLabel => totalCents == null
      ? 'Unknown'
      : 'USD ${(totalCents! / 100).toStringAsFixed(2)}';
  DateTime? get expiresAt =>
      DateTime.tryParse(data['expires_at']?.toString() ?? '');
  bool get expired => expiresAt == null || !expiresAt!.isAfter(DateTime.now());
  bool get complete =>
      status == 'QUOTED' &&
      id != null &&
      acceptanceKey != null &&
      owner != null &&
      payer == owner &&
      data['currency'] == 'USD' &&
      members.isNotEmpty &&
      members.length <= 3 &&
      totalCents != null &&
      totalCents! > 0 &&
      members.every((m) => _cents(m['retail_total']) != null) &&
      members.fold<int>(0, (s, m) => s + _cents(m['retail_total'])!) ==
          totalCents;
  bool get enabled =>
      complete &&
      data['acceptance_enabled'] == true &&
      data['balance_state'] == 'sufficient';
}

class EsimOrganization {
  const EsimOrganization(this.data);
  final Map<String, dynamic> data;
  String? get owner => data['owner_id'] as String?;
  List<Map<String, dynamic>> get batches => _rows(data['groups']);
  Map<String, Map<String, dynamic>> get labels => {
    for (final r in _rows(data['labels']))
      if (r['profile_id'] is String) r['profile_id'] as String: r,
  };
  int get maxMembers => (data['max_members'] as num?)?.toInt().clamp(1, 3) ?? 1;
  bool get pending => batches.any(
    (b) => _rows(b['members']).any(
      (m) =>
          !['completed', 'failed'].contains(m['operation_state']) ||
          m['refund_pending'] == true,
    ),
  );
}
