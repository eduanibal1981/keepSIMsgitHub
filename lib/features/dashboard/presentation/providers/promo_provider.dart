import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/core/supabase_client.dart';

part 'promo_provider.g.dart';

/// I3 — one carrier-targeted advert, as returned by `get_active_promos()`.
class ActivePromo {
  const ActivePromo({
    required this.id,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.actionUrl,
    this.carrierName,
    this.endsAt,
  });

  final String id;
  final String title;
  final String body;
  final String? ctaLabel;
  final String? actionUrl;
  final String? carrierName;
  final DateTime? endsAt;

  factory ActivePromo.fromJson(Map<String, dynamic> json) => ActivePromo(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        ctaLabel: json['cta_label'] as String?,
        actionUrl: json['action_url'] as String?,
        carrierName: json['carrier_name'] as String?,
        endsAt: json['ends_at'] == null
            ? null
            : DateTime.tryParse(json['ends_at'] as String),
      );
}

/// The adverts this user should see right now.
///
/// Targeting, the live window and the per-user dismissal are all decided
/// server-side by `get_active_promos()`. Nothing is filtered here on purpose:
/// a client that re-applies the targeting rule is a second copy of it, and the
/// two drift.
@riverpod
Future<List<ActivePromo>> activePromos(Ref ref) async {
  final rows = await supabase.rpc('get_active_promos');
  return (rows as List)
      .cast<Map<String, dynamic>>()
      .map(ActivePromo.fromJson)
      .toList();
}

/// Hides a promo for this user, permanently. Invalidates the list so the card
/// disappears without a manual refresh.
@riverpod
class PromoDismissal extends _$PromoDismissal {
  @override
  void build() {}

  Future<void> dismiss(String campaignId) async {
    await supabase.rpc('dismiss_promo', params: {'p_campaign_id': campaignId});
    ref.invalidate(activePromosProvider);
  }
}
