import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/features/sim_lines/data/models/payment_method_model.dart';

part 'app_config_provider.g.dart';

/// Fallback app fee, matching `calculate_topup_fees`. Both sides must agree on
/// this number: if the config row is unreadable here it is usually unreadable
/// (or absent) for the trigger too, and they land on the same answer.
const double kDefaultAppFeePercent = 3.0;

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

/// Margin on a premium subscription, as a percentage of the year's cost.
///
/// Stated rather than hidden: it used to live inside `inapp_pricing` as a
/// gateway fixed fee charged once per refill (13x $0.30 to cover one $0.49
/// PayPal charge). Now it is `system_configs.PREMIUM_MARGIN_PERCENT` — one row,
/// no app update, and the number means what its name says.
@Riverpod(keepAlive: true)
Future<double> premiumMarginPercent(Ref ref) async =>
    _numericConfig('PREMIUM_MARGIN_PERCENT', fallback: 0);

/// Reads a percentage from `system_configs`, refusing nonsense rather than
/// pricing on it. Mirrors the guard in `calculate_topup_fees`.
Future<double> _numericConfig(String key, {required double fallback}) async {
  try {
    final row = await Supabase.instance.client
        .from('system_configs')
        .select('config_value')
        .eq('config_key', key)
        .maybeSingle();

    final parsed = double.tryParse(row?['config_value']?.toString() ?? '');
    if (parsed == null || parsed < 0 || parsed > 100) return fallback;
    return parsed;
  } catch (_) {
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
