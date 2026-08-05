/// The operator's own top-up channel — the answer for every case where
/// KeepSIMs' automation is not the right one.
///
/// Hand-written rather than generated because of what it is allowed to say. The
/// table (`carrier_self_service`, I8) ships with every URL column NULL and
/// `verified_at` NULL on all 29 seeded rows: what we hold today is the *name*
/// an operator publishes its app under, and only where that differs from the
/// carrier's own name. A prepaid telecom app is among the most cloned things in
/// either store, so an unverified row must render as something to search for,
/// never as a link to follow — which is why [isVerified] exists and why the
/// store-search URLs are built here rather than stored.
library;

class CarrierSelfService {
  const CarrierSelfService({
    required this.carrierId,
    this.appName,
    this.androidUrl,
    this.iosUrl,
    this.webTopupUrl,
    this.ussdCode,
    this.note,
    this.verifiedAt,
    this.sourceUrl,
  });

  final String carrierId;

  /// What the operator publishes its app as — "Ana Vodafone", "mySTC". Null
  /// means we do not know, and the UI falls back to the carrier's own name.
  final String? appName;

  final String? androidUrl;
  final String? iosUrl;
  final String? webTopupUrl;

  /// Dialled on the handset. Works with no data at all, which is the one thing
  /// a relative at home can always do.
  final String? ussdCode;

  final String? note;

  /// Null until a human has checked this row against the operator.
  final DateTime? verifiedAt;
  final String? sourceUrl;

  factory CarrierSelfService.fromJson(Map<String, dynamic> json) =>
      CarrierSelfService(
        carrierId: json['carrier_id'] as String,
        appName: _text(json['app_name']),
        androidUrl: _text(json['android_url']),
        iosUrl: _text(json['ios_url']),
        webTopupUrl: _text(json['web_topup_url']),
        ussdCode: _text(json['ussd_code']),
        note: _text(json['note']),
        verifiedAt: json['verified_at'] == null
            ? null
            : DateTime.tryParse(json['verified_at'] as String),
        sourceUrl: _text(json['source_url']),
      );

  Map<String, dynamic> toJson() => {
    'carrier_id': carrierId,
    'app_name': appName,
    'android_url': androidUrl,
    'ios_url': iosUrl,
    'web_topup_url': webTopupUrl,
    'ussd_code': ussdCode,
    'note': note,
    'verified_at': verifiedAt?.toIso8601String(),
    'source_url': sourceUrl,
  };

  /// Whether a human has checked this against the operator. Only a verified row
  /// may present its stored links as links.
  bool get isVerified => verifiedAt != null;

  /// A direct link we are willing to stand behind, or null.
  ///
  /// An unverified row's URLs are deliberately withheld even when present: the
  /// row can be edited by an admin at any time, and "we have a URL" is not the
  /// same claim as "someone checked that it is the operator's".
  String? verifiedLink({required bool preferIos}) {
    if (!isVerified) return null;
    return (preferIos ? iosUrl : androidUrl) ?? webTopupUrl;
  }

  /// What to search the store for. Never a claim about a specific listing —
  /// the caller pairs this with a "check the publisher" caution.
  String storeSearchUrl({
    required String carrierName,
    required bool preferIos,
  }) {
    final term = Uri.encodeQueryComponent(searchTerm(carrierName));
    return preferIos
        ? 'https://apps.apple.com/search?term=$term'
        : 'https://play.google.com/store/search?q=$term&c=apps';
  }

  /// The app's published name when we have one, else the carrier's own.
  String searchTerm(String carrierName) {
    final name = appName;
    if (name == null || name.isEmpty) return carrierName;
    // Both, so a wrong or renamed app name still lands the user on the right
    // publisher's page rather than on nothing.
    return name.toLowerCase() == carrierName.toLowerCase()
        ? name
        : '$name $carrierName';
  }

  static String? _text(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
