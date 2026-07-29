/// SIM Shield — Depletion Forecast Providers (G1)
///
/// Reads `sim_line_usage_forecast`, an RLS-guarded read-own table. There is no
/// RPC and no write path: the row is produced by the nightly
/// `refresh_usage_forecasts()` cron job.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/features/sim_lines/data/models/usage_forecast_model.dart';

part 'usage_forecast_provider.g.dart';

/// The forecast for one SIM line, or null when the job has not produced one yet
/// (a line added since the last nightly run, or one that is no longer active).
///
/// A failure here must never take the detail screen down with it — the forecast
/// is an enhancement to the page, not the page.
@riverpod
Future<UsageForecast?> usageForecastForLine(Ref ref, String simLineId) async {
  try {
    final row = await Supabase.instance.client
        .from('sim_line_usage_forecast')
        .select()
        .eq('sim_line_id', simLineId)
        .maybeSingle();

    if (row == null) return null;
    return UsageForecast.fromJson(row);
  } on PostgrestException {
    return null;
  }
}
