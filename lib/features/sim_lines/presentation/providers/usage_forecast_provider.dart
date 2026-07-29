/// SIM Shield — Depletion Forecast Providers (G1)
///
/// Reads `sim_line_usage_forecast`, an RLS-guarded read-own table. There is no
/// RPC and no write path: the row is produced by the nightly
/// `refresh_usage_forecasts()` cron job.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/features/sim_lines/data/models/usage_forecast_model.dart';

part 'usage_forecast_provider.g.dart';

/// Cache key holding the last successfully fetched forecast rows.
const String kCachedForecastsKey = 'cached_usage_forecasts';

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

/// Every forecast row the user can see, cached to disk (G4).
///
/// The per-line provider above is a live read for one screen; this one exists
/// because the home-screen widget needs the whole set, and needs it to survive
/// a cold offline start — the countdown it renders on a plane comes from here.
///
/// Cached rather than fetched-or-nothing: a forecast is regenerated nightly and
/// is about validity windows measured in weeks, so yesterday's copy is a good
/// answer and a blank widget is not.
@Riverpod(keepAlive: true)
Future<List<UsageForecast>> usageForecasts(Ref ref) async {
  final cache = ref.watch(localCacheServiceProvider);

  List<UsageForecast> decode(List<dynamic> rows) => rows
      .whereType<Map<String, dynamic>>()
      .map(UsageForecast.fromJson)
      .toList();

  try {
    final rows =
        await Supabase.instance.client.from('sim_line_usage_forecast').select()
            as List<dynamic>;
    await cache.writeJson(kCachedForecastsKey, rows);
    return decode(rows);
  } catch (_) {
    final cached = cache.readJson(kCachedForecastsKey);
    if (cached is List) {
      try {
        return decode(cached);
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }
}
