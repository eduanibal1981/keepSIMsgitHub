import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
