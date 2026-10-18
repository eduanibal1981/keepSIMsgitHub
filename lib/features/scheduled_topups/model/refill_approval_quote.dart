class RefillApprovalQuote {
  final String id;
  final double totalUsd;
  final double? targetValue;
  final String? targetCurrency;
  final DateTime expiresAt;

  const RefillApprovalQuote({
    required this.id,
    required this.totalUsd,
    this.targetValue,
    this.targetCurrency,
    required this.expiresAt,
  });

  factory RefillApprovalQuote.fromJson(Map<String, dynamic> json) {
    final route = json['route'] as Map<String, dynamic>;
    double number(dynamic value) => double.parse(value.toString());
    return RefillApprovalQuote(
      id: json['id'] as String,
      totalUsd: number(route['totalChargeUsd']),
      targetValue: route['targetLocalValue'] == null
          ? null
          : number(route['targetLocalValue']),
      targetCurrency: route['targetLocalCurrency'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}
