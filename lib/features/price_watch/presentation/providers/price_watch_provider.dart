/// SIM Shield — Price Watch Providers (G2)
///
/// `offer_price_watches` is a plain RLS-guarded table: read-own, with
/// column-scoped INSERT and UPDATE grants. There is no RPC, so every call here
/// sends exactly the columns the grant allows — sending the full model would
/// come back 42501, which is how a column lockdown broke SIM line editing in
/// D5c and profile editing in F6.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/features/price_watch/data/models/offer_price_watch_model.dart';

part 'price_watch_provider.g.dart';

/// Every watch the signed-in user has, auto-derived ones included.
@riverpod
Future<List<OfferPriceWatch>> priceWatches(Ref ref) async {
  final rows = await Supabase.instance.client
      .from('offer_price_watches')
      .select()
      .order('source')
      .order('country_code');

  return rows
      .map<OfferPriceWatch>((r) => OfferPriceWatch.fromJson(r))
      .toList(growable: false);
}

/// The watch covering one eSIM destination, or null when it is not watched.
/// Drives the bell toggle on the plans screen.
@riverpod
Future<OfferPriceWatch?> esimWatchForCountry(Ref ref, String countryCode) async {
  final list = await ref.watch(priceWatchesProvider.future);
  for (final w in list) {
    if (w.isEsim && w.countryCode == countryCode) return w;
  }
  return null;
}

/// Whether the user has consented to the `promo` category.
///
/// Price-drop alerts are `promo`, and `detect_offer_price_drops()` writes
/// nothing at all without an enabled row — so a watch list with promo off is
/// silent by design. The UI has to say that out loud, or the feature looks
/// broken.
@riverpod
Future<bool> promoConsent(Ref ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return false;

  final row = await Supabase.instance.client
      .from('alert_settings')
      .select('is_enabled')
      .eq('user_id', userId)
      .eq('category', 'promo')
      .maybeSingle();

  // Absent row means "never consented" for promo — the inverse of every other
  // category, and the same default trg_fn_dispatch_notification applies.
  return (row?['is_enabled'] as bool?) ?? false;
}

@riverpod
class PriceWatchController extends _$PriceWatchController {
  @override
  FutureOr<void> build() {}

  SupabaseClient get _db => Supabase.instance.client;

  Future<void> _refresh() async {
    ref.invalidate(priceWatchesProvider);
    await ref.read(priceWatchesProvider.future);
  }

  /// Start watching an eSIM destination. `origin` is deliberately not sent:
  /// it is not in the INSERT grant and the RLS policy pins it to 'user'.
  Future<void> watchEsimCountry(String countryCode) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.from('offer_price_watches').insert({
        'user_id': userId,
        'source': 'esim',
        'country_code': countryCode.toUpperCase(),
        'carrier_code': null,
        'is_active': true,
      });
      await _refresh();
    });
  }

  Future<void> setActive(String watchId, bool isActive) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db
          .from('offer_price_watches')
          .update({'is_active': isActive})
          .eq('id', watchId);
      await _refresh();
    });
  }

  Future<void> setThreshold(String watchId, double? percent) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db
          .from('offer_price_watches')
          .update({'threshold_percent': percent})
          .eq('id', watchId);
      await _refresh();
    });
  }

  /// Only ever called for `origin = 'user'` rows. An auto row deleted here
  /// would come straight back on the next nightly sync.
  Future<void> remove(String watchId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.from('offer_price_watches').delete().eq('id', watchId);
      await _refresh();
    });
  }

  /// Turn the `promo` category on so the alerts can actually be delivered.
  ///
  /// An UPDATE, not an upsert: every profile already has all twelve
  /// alert_settings rows — C2's trg_profiles_seed_alert_settings seeds them on
  /// signup and that migration backfilled the existing users — and
  /// NotificationsRepository writes them the same way.
  Future<void> enablePromoConsent() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db
          .from('alert_settings')
          .update({'is_enabled': true})
          .eq('user_id', userId)
          .eq('category', 'promo');
      ref.invalidate(promoConsentProvider);
      await ref.read(promoConsentProvider.future);
    });
  }
}
