/// The parsed result of one `record_affiliate_click` call.
///
/// Follows the same envelope discipline as [PlanFeeResult]: the RPC always
/// returns a jsonb object and signals refusal with `success: false` at HTTP
/// 200, so a caller that reads "did not throw" as "go ahead" is wrong.
///
/// The stakes are lower than a wallet debit but the failure is still real — an
/// untracked outbound link sends a user to a partner and earns nothing, which
/// is the one outcome worse than not showing the offer. So a body this class
/// cannot read is a refusal, and the caller must not open anything.
library;

abstract final class AffiliateClickErrorCode {
  /// The whole rail is switched off in `system_configs`. Expected while
  /// KeepSIMs is pre-production — nothing clickable should have rendered.
  static const String affiliateDisabled = 'AFFILIATE_DISABLED';

  /// The partner or its network is inactive.
  static const String partnerInactive = 'PARTNER_INACTIVE';

  /// The partner has no tracking URL. The server refuses rather than opening
  /// a bare link, because that is free traffic given away.
  static const String noTrackingUrl = 'NO_TRACKING_URL';

  static const String offerNotFound = 'OFFER_NOT_FOUND';
  static const String unauthorized = 'UNAUTHORIZED';
}

class AffiliateClickResult {
  const AffiliateClickResult({
    required this.success,
    this.url,
    this.clickId,
    this.code,
  });

  final bool success;

  /// The tracked destination. Non-null only on success — there is deliberately
  /// no fallback to an untracked partner URL.
  final String? url;

  final String? clickId;
  final String? code;

  factory AffiliateClickResult.fromRpc(Object? body) {
    if (body is! Map) {
      return const AffiliateClickResult(success: false);
    }
    final map = Map<String, dynamic>.from(body);
    final ok = map['success'] == true; // the string "true" is not a success
    final url = map['url'] as String?;

    // Success without a URL is not success. Guarding here rather than at each
    // call site means no surface can open `null`.
    if (ok && (url == null || url.isEmpty)) {
      return const AffiliateClickResult(success: false);
    }

    return AffiliateClickResult(
      success: ok,
      url: url,
      clickId: map['click_id'] as String?,
      code: map['code'] as String?,
    );
  }
}
