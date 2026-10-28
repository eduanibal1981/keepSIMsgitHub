class EsimRechargeOffer {
  const EsimRechargeOffer({
    required this.id,
    required this.title,
    required this.total,
    required this.allowanceBytes,
    required this.duration,
    required this.unit,
    required this.addsAllowance,
    required this.quoteSupported,
    this.dataType = 1,
  });
  factory EsimRechargeOffer.fromJson(Map<String, dynamic> j) =>
      EsimRechargeOffer(
        id: j['package_id'] as String,
        title: j['title'] as String,
        total: (j['retail_total'] as num).toDouble(),
        allowanceBytes: int.tryParse(j['allowance_bytes']?.toString() ?? ''),
        duration: j['duration_value'] as int,
        unit: j['duration_unit'] as String,
        addsAllowance: j['effect'] == 'allowance_and_validity',
        quoteSupported: j['quote_supported'] == true,
        dataType: j['data_type'] as int? ?? 1,
      );
  final String id, title, unit;
  final double total;
  final int? allowanceBytes;
  final int duration;
  final int dataType;
  final bool addsAllowance, quoteSupported;
  String get effectLabel => addsAllowance
      ? 'Adds allowance and validity'
      : 'Extends validity; daily allowance does not stack';
  String get durationLabel => '$duration ${unit == 'HOUR' ? 'hours' : 'days'}';
  String get behaviorLabel => switch (dataType) {
    2 => 'Speed reduces after the daily allowance.',
    3 => 'Data stops after the daily allowance.',
    4 => 'Unlimited daily data.',
    _ => 'Fixed total allowance.',
  };
  String get allowanceLabel => dataType == 4
      ? 'Unlimited daily data'
      : allowanceBytes == null
      ? 'Allowance not provided'
      : '${(allowanceBytes! / 1073741824).toStringAsFixed(2)} GB${addsAllowance ? '' : ' per day'}';
}

class EsimRechargeDiscovery {
  const EsimRechargeDiscovery({
    required this.status,
    this.offers = const [],
    this.version,
    this.expiresAt,
  });
  factory EsimRechargeDiscovery.fromJson(Map<String, dynamic> j) =>
      EsimRechargeDiscovery(
        status: j['status'] as String,
        offers: (j['offers'] as List? ?? [])
            .map(
              (o) => EsimRechargeOffer.fromJson(
                Map<String, dynamic>.from(o as Map),
              ),
            )
            .toList(),
        version: j['offer_version'] as String?,
        expiresAt: DateTime.tryParse(j['expires_at']?.toString() ?? ''),
      );
  final String status;
  final List<EsimRechargeOffer> offers;
  final String? version;
  final DateTime? expiresAt;
  String get message => rechargeStatusMessage(status);
}

class EsimRechargeQuote {
  const EsimRechargeQuote({
    required this.status,
    this.id,
    this.ownerId,
    this.payerId,
    this.profileId,
    this.expiresAt,
    this.offer,
    this.balanceState = 'unknown',
    this.availableBalance,
  });
  factory EsimRechargeQuote.fromJson(Map<String, dynamic> j) =>
      EsimRechargeQuote(
        status: j['status'] as String,
        id: j['quote_id'] as String?,
        ownerId: j['owner_id'] as String?,
        payerId: j['payer_id'] as String?,
        profileId: j['profile_id'] as String?,
        expiresAt: DateTime.tryParse(j['expires_at']?.toString() ?? ''),
        offer: j['offer'] is Map
            ? EsimRechargeOffer.fromJson(
                Map<String, dynamic>.from(j['offer'] as Map),
              )
            : null,
        balanceState: j['balance_state'] as String? ?? 'unknown',
        availableBalance: (j['available_balance'] as num?)?.toDouble(),
      );
  final String status, balanceState;
  final String? id, ownerId, payerId, profileId;
  final DateTime? expiresAt;
  final EsimRechargeOffer? offer;
  final double? availableBalance;
  bool get expired => expiresAt == null || !expiresAt!.isAfter(DateTime.now());
  // ESIM-07 deliberately has no acceptance method or spending control.
  String get balanceLabel => switch (balanceState) {
    'sufficient' => 'Available wallet balance covers this preview.',
    'insufficient' =>
      'Insufficient available wallet balance. Reserved funds cannot be spent.',
    _ =>
      'Available wallet balance is unknown. Refresh before any future payment.',
  };
}

String rechargeStatusMessage(String status) => switch (status) {
  'READY' => 'Compatible offers for this eSIM',
  'PENDING' => 'Checking compatible offers. Please refresh shortly.',
  'NO_COMPATIBLE_OFFERS' =>
    'The supplier has no compatible recharge offers for this eSIM.',
  'PROFILE_EXPIRED' => 'This eSIM has expired and cannot be recharged.',
  'SUPPLIER_DISABLED' =>
    'Recharge discovery is unavailable while this supplier is disabled.',
  'UNRESOLVED_OPERATION' =>
    'An earlier operation is still unresolved. Contact support before another recharge.',
  'PROFILE_REFRESH_REQUIRED' || 'CAPABILITY_UNVERIFIED' =>
    'Refresh this eSIM’s status first. Recharge eligibility is not yet confirmed.',
  'TOPUP_UNSUPPORTED' ||
  'UNSUPPORTED_PROFILE' => 'This eSIM does not support recharge discovery.',
  'DISCOVERY_DISABLED' => 'Recharge discovery is not available yet.',
  'STALE_OFFERS' || 'PRICE_CHANGED' || 'STALE_QUOTE' =>
    'This offer or price changed. Refresh and request a new quote.',
  'DURATION_QUOTE_UNAVAILABLE' =>
    'Quotes for daily extensions will be available later.',
  'INCOMPATIBLE_OFFER' => 'This package is not compatible with this eSIM.',
  'PROFILE_UNAVAILABLE' ||
  'QUOTE_UNAVAILABLE' => 'This eSIM or quote is unavailable for this account.',
  _ => 'Recharge information is temporarily unavailable. Please try again.',
};
