import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/features/sim_lines/data/models/payment_method_model.dart';

part 'app_config_provider.g.dart';

/// Fallback app fee, matching `calculate_topup_fees`. Both sides must agree on
/// this number: if the config row is unreadable here it is usually unreadable
/// (or absent) for the trigger too, and they land on the same answer.
const double kDefaultAppFeePercent = 3.0;

/// Fallback minimum app fee floor, matching `calculate_topup_fees`.
const double kDefaultMinAppFeeUsd = 0.03;

/// The KeepSIMs service fee, as a percentage of a refill's base cost.
///
/// Read from `system_configs.APP_FEE_PERCENT` instead of a constant so the
/// price quoted in the UI is the price `calculate_topup_fees` debits. These
/// were two hardcoded numbers that silently disagreed — the client quoted 3%
/// while the trigger charged 5%, so every refill cost more than it displayed.
/// A power user can change the row from the Supabase dashboard and both the
/// quote and the debit follow it with no redeploy.
///
/// The trigger is always the authority on what is actually charged; this only
/// decides what the user is shown before they confirm.
@Riverpod(keepAlive: true)
Future<double> appFeePercent(Ref ref) async {
  try {
    final row = await Supabase.instance.client
        .from('system_configs')
        .select('config_value')
        .eq('config_key', 'APP_FEE_PERCENT')
        .maybeSingle();

    final parsed = double.tryParse(row?['config_value']?.toString() ?? '');
    // Same sanity window as the trigger, so a nonsense row can't quote a
    // nonsense price.
    if (parsed == null || parsed < 0 || parsed > 100) {
      return kDefaultAppFeePercent;
    }
    return parsed;
  } catch (_) {
    return kDefaultAppFeePercent;
  }
}

/// The minimum dollar floor for the app fee, read from `system_configs.MIN_APP_FEE_USD`.
///
/// Ensures micro-topups (under $1.00) retain a safe minimum profit margin floor
/// ($0.03 by default) rather than fractions of a cent.
@Riverpod(keepAlive: true)
Future<double> minAppFeeUsd(Ref ref) async {
  try {
    final row = await Supabase.instance.client
        .from('system_configs')
        .select('config_value')
        .eq('config_key', 'MIN_APP_FEE_USD')
        .maybeSingle();

    final parsed = double.tryParse(row?['config_value']?.toString() ?? '');
    if (parsed == null || parsed < 0 || parsed > 100) {
      return kDefaultMinAppFeeUsd;
    }
    return parsed;
  } catch (_) {
    return kDefaultMinAppFeeUsd;
  }
}

/// Fallback yearly service fee, matching `pay_plan_fee_from_wallet`'s own
/// fallback so a failed read here quotes the price the RPC would debit.
const double kDefaultBaseServiceFeeUsd = 2.50;

/// The yearly per-line service fee both paid tiers carry.
///
/// Read from `system_configs.BASE_SERVICE_FEE_USD` (C3c) instead of the
/// hardcoded $2.50 that lived in three screens. The wallet-billed charge is
/// priced server-side by `pay_plan_fee_from_wallet` from the same row; this
/// value only decides what is displayed and what a PayPal fallback bills.
/// Zero and negative are refused like the RPC refuses them, so the quote and
/// the debit cannot disagree.
@Riverpod(keepAlive: true)
Future<double> baseServiceFeeUsd(Ref ref) async {
  try {
    final row = await Supabase.instance.client
        .from('system_configs')
        .select('config_value')
        .eq('config_key', 'BASE_SERVICE_FEE_USD')
        .maybeSingle();

    final parsed = double.tryParse(row?['config_value']?.toString() ?? '');
    if (parsed == null || parsed <= 0 || parsed > 1000) {
      return kDefaultBaseServiceFeeUsd;
    }
    return parsed;
  } catch (_) {
    return kDefaultBaseServiceFeeUsd;
  }
}

/// Percentage part of the premium margin, applied to the refill's cost.
///
/// Stated rather than hidden: it used to live inside `inapp_pricing` labelled as
/// a PayPal fee, charged once per refill against a bill PayPal issues once a
/// year. `system_configs.PREMIUM_MARGIN_PERCENT` — one row, no app update.
@Riverpod(keepAlive: true)
Future<double> premiumMarginPercent(Ref ref) async =>
    _numericConfig('PREMIUM_MARGIN_PERCENT', fallback: 0);

/// Flat part of the premium margin, per refill.
///
/// The margin needs both parts: the flat component is worth ~2.6% of a $277 plan
/// but ~41% of a $13 one, so a single percentage cannot express it. Capped well
/// above any sane value rather than at 100, since this is dollars, not a rate.
@Riverpod(keepAlive: true)
Future<double> premiumMarginPerRefillUsd(Ref ref) async =>
    _numericConfig('PREMIUM_MARGIN_PER_REFILL_USD', fallback: 0, max: 1000);

/// Whether geolocation is allowed to write each line's home/travel mode.
///
/// The derivation itself (`resolveLineMode`) is pure and always runs; this row
/// decides whether the result is persisted. Off by default: turning it on
/// un-pauses the protection of every line whose country the user is not in,
/// which resumes schedules and makes those lines eligible for `run_auto_rescue`
/// — a live money decision that belongs to the owner, not to a deploy.
///
/// `system_configs.GEO_LINE_MODE_SYNC_ENABLED`. A failed read means off, so a
/// network blip cannot start writing modes.
@Riverpod(keepAlive: true)
Future<bool> geoLineModeSyncEnabled(Ref ref) async {
  try {
    final row = await Supabase.instance.client
        .from('system_configs')
        .select('config_value')
        .eq('config_key', 'GEO_LINE_MODE_SYNC_ENABLED')
        .maybeSingle();

    return row?['config_value']?.toString().trim().toLowerCase() == 'true';
  } catch (_) {
    return false;
  }
}

/// Reads a number from `system_configs`, refusing nonsense rather than pricing
/// on it. Mirrors the guard in `calculate_topup_fees`.
Future<double> _numericConfig(
  String key, {
  required double fallback,
  double max = 100,
}) async {
  try {
    final row = await Supabase.instance.client
        .from('system_configs')
        .select('config_value')
        .eq('config_key', key)
        .maybeSingle();

    final parsed = double.tryParse(row?['config_value']?.toString() ?? '');
    if (parsed == null || parsed < 0 || parsed > max) return fallback;
    return parsed;
  } catch (_) {
    return fallback;
  }
}

/// A contact number for the offline-recharge flow, from `system_configs`.
///
/// These were hardcoded Oman numbers in `offline_refill_screen.dart` (C3c).
/// The screen exists precisely for when the device is offline, so the last
/// good DB value is cached locally and served when the read fails; only a
/// fresh install that has never been online sees [fallback].
@Riverpod(keepAlive: true)
Future<String> offlineContactNumber(
  Ref ref,
  String configKey,
  String fallback,
) async {
  final cache = ref.watch(localCacheServiceProvider);
  final cacheKey = 'cached_system_config_$configKey';
  try {
    final row = await Supabase.instance.client
        .from('system_configs')
        .select('config_value')
        .eq('config_key', configKey)
        .maybeSingle();

    final value = row?['config_value']?.toString().trim();
    if (value == null || value.isEmpty) return fallback;
    await cache.writeJson(cacheKey, {'value': value});
    return value;
  } catch (_) {
    final cached = cache.readJson(cacheKey);
    if (cached is Map && cached['value'] is String) {
      return cached['value'] as String;
    }
    return fallback;
  }
}

/// A per-channel offline-recharge message fee, from `system_configs`.
///
/// The official WhatsApp Business API, the SMS gateway and the Twilio voice
/// number each cost us per inbound message; that cost is passed to the wallet by
/// `calculate_topup_fees` when the refill's channel is set (C4). Keys:
/// `OFFLINE_WHATSAPP_MESSAGE_FEE_USD` / `OFFLINE_SMS_MESSAGE_FEE_USD` /
/// `OFFLINE_MISSED_CALL_FEE_USD`.
///
/// Cached locally like [offlineContactNumber] because this screen is *for* being
/// offline — the last good value is shown when the read fails. The DB trigger is
/// always the authority on what is actually debited; this only decides what the
/// card shows before the user acts.
@Riverpod(keepAlive: true)
Future<double> offlineMessageFeeUsd(
  Ref ref,
  String configKey,
  double fallback,
) async {
  final cache = ref.watch(localCacheServiceProvider);
  final cacheKey = 'cached_system_config_num_$configKey';
  try {
    final row = await Supabase.instance.client
        .from('system_configs')
        .select('config_value')
        .eq('config_key', configKey)
        .maybeSingle();

    final parsed = double.tryParse(row?['config_value']?.toString() ?? '');
    // Same sanity window as calculate_topup_fees' message-fee guard.
    if (parsed == null || parsed < 0 || parsed > 100) return fallback;
    await cache.writeJson(cacheKey, {'value': parsed});
    return parsed;
  } catch (_) {
    final cached = cache.readJson(cacheKey);
    if (cached is Map && cached['value'] is num) {
      return (cached['value'] as num).toDouble();
    }
    return fallback;
  }
}

/// One gateway's fees, straight from `payment_gateways` — the single source of
/// truth for what a gateway charges.
///
/// Nothing should hardcode a rate or bake one into a stored column: the whole
/// point of the table is that renegotiating a rate is one row change with no app
/// update. Returns null when the gateway is missing or inactive, so callers must
/// decide what that means rather than silently pricing at zero.
@Riverpod(keepAlive: true)
Future<PaymentMethod?> paymentGateway(Ref ref, String code) async {
  final row = await Supabase.instance.client
      .from('payment_gateways')
      .select()
      .eq('code', code)
      .eq('is_active', true)
      .maybeSingle();

  return row == null ? null : PaymentMethod.fromJson(row);
}
