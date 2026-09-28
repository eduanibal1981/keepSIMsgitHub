import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_alert_clock_state.dart';

/// Provider for the Alert Clock state of a specific SIM line.
/// Reads directly from the authoritative `sim_line_alert_clock_states` table.
final simLineAlertClockForLineProvider =
    FutureProvider.family<SimLineAlertClockState?, String>((ref, simLineId) async {
  final row = await Supabase.instance.client
      .from('sim_line_alert_clock_states')
      .select()
      .eq('sim_line_id', simLineId)
      .maybeSingle();

  if (row == null) return null;
  return SimLineAlertClockState.fromJson(row);
});

/// Triggers real-time recalculation of the Alert Clock via RPC and refreshes provider.
Future<void> recalculateAndRefreshAlertClock(WidgetRef ref, String simLineId) async {
  try {
    await Supabase.instance.client.rpc('refresh_own_sim_line_alert_clock', params: {
      'p_sim_line_id': simLineId,
    });
    ref.invalidate(simLineAlertClockForLineProvider(simLineId));
  } catch (_) {
    // Best-effort recalculation
  }
}
