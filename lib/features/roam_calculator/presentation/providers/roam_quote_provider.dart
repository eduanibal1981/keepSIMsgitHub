/// SIM Shield — "Roam or eSIM?" providers (G5)
///
/// Both RPCs are `SECURITY INVOKER`, so there is nothing to pass for identity:
/// the caller's RLS on `sim_lines` is what decides which carriers they can be
/// quoted on. Sending a `carrier_id` the user does not hold a line with simply
/// returns `no_roaming_rate` rather than someone else's tariff.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/features/roam_calculator/data/models/roam_quote_model.dart';

part 'roam_quote_provider.g.dart';

/// The inputs the calculator screen owns. Defaults are a week and a gigabyte —
/// the shape of the only bundle the live eSIM catalogue actually sells.
class RoamQuoteInput {
  const RoamQuoteInput({
    required this.countryCode,
    this.days = 7,
    this.dataMb = 1000,
    this.carrierId,
  });

  final String countryCode;
  final int days;
  final int dataMb;
  final String? carrierId;

  RoamQuoteInput copyWith({
    String? countryCode,
    int? days,
    int? dataMb,
    String? carrierId,
    bool clearCarrier = false,
  }) =>
      RoamQuoteInput(
        countryCode: countryCode ?? this.countryCode,
        days: days ?? this.days,
        dataMb: dataMb ?? this.dataMb,
        carrierId: clearCarrier ? null : (carrierId ?? this.carrierId),
      );

  @override
  bool operator ==(Object other) =>
      other is RoamQuoteInput &&
      other.countryCode == countryCode &&
      other.days == days &&
      other.dataMb == dataMb &&
      other.carrierId == carrierId;

  @override
  int get hashCode => Object.hash(countryCode, days, dataMb, carrierId);
}

/// The comparison itself. Returns null only when the country code is empty —
/// every other outcome is a `verdict` the UI is expected to render.
@riverpod
Future<RoamQuote?> roamQuote(Ref ref, RoamQuoteInput input) async {
  if (input.countryCode.trim().isEmpty) return null;

  final rows = await Supabase.instance.client.rpc(
    'roam_or_esim_quote',
    params: {
      'p_country_code': input.countryCode.toUpperCase(),
      'p_days': input.days,
      'p_data_mb': input.dataMb,
      'p_carrier_id': input.carrierId,
    },
  );

  final List<dynamic> list = rows is List ? rows : <dynamic>[rows];
  if (list.isEmpty) return null;
  return RoamQuote.fromJson(Map<String, dynamic>.from(list.first as Map));
}

/// The caller's own carriers, home carrier first, for the picker.
@riverpod
Future<List<RoamCarrierOption>> roamCarriers(Ref ref, String countryCode) async {
  if (countryCode.trim().isEmpty) return const <RoamCarrierOption>[];

  final rows = await Supabase.instance.client.rpc(
    'my_roaming_carriers',
    params: {'p_country_code': countryCode.toUpperCase()},
  );

  final List<dynamic> list = rows is List ? rows : <dynamic>[];
  return list
      .map<RoamCarrierOption>(
        (r) => RoamCarrierOption.fromJson(Map<String, dynamic>.from(r as Map)),
      )
      .toList(growable: false);
}
