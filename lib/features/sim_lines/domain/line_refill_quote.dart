/// A server-priced customer refill total. Supplier pricing stays on the server.
class LineRefillQuote {
  final String? simLineId;
  final String? offerId;
  final int? offerValue;
  final String effectiveTier;
  final int? feeRuleVersion;
  final double totalUsd;
  final String currency;

  const LineRefillQuote({
    this.simLineId,
    this.offerId,
    this.offerValue,
    required this.effectiveTier,
    this.feeRuleVersion,
    required this.totalUsd,
    this.currency = 'USD',
  });

  double get total => totalUsd;
  String get breakdownText => 'Total: \$${totalUsd.toStringAsFixed(2)} USD';
  String get compactBreakdownText => breakdownText;

  factory LineRefillQuote.fromJson(
    Map<String, dynamic> json, {
    String? simLineId,
  }) {
    final total = (json['total_charge_usd'] as num?)?.toDouble();
    if (total == null ||
        !total.isFinite ||
        total <= 0 ||
        json['currency'] != 'USD') {
      throw const FormatException('Refill pricing unavailable');
    }
    return LineRefillQuote(
      simLineId: simLineId,
      offerId: json['offer_id'] as String?,
      offerValue: (json['offer_value'] as num?)?.toInt(),
      effectiveTier: json['pricing_tier'] as String? ?? 'free',
      totalUsd: total,
    );
  }
}
