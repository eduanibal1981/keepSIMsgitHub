/// KeepSIMs Admin — the whole server-side surface, in one place.
///
/// Every call here is an `admin_*` RPC. None of them writes to a table
/// directly, and that is the point.
///
/// The admin app authenticates with the same anon key the customer app ships,
/// upgraded to a power-user session. Writing to tables from here means every new
/// admin capability needs a new RLS policy on a user-facing table — which is
/// exactly how the F-1..F-4 money holes happened. It also does not work: probed
/// live on 2026-07-31 with a real power-user JWT,
///
///   * `UPDATE carriers`          → 0 rows, no error. There is no UPDATE policy,
///     so the Routing tab reported success and changed nothing, for months.
///   * `UPDATE topup_executions`  → 42501. SELECT is the only grant, so
///     "Complete" and "Switch to Manual" were dead buttons.
///   * `SELECT wallets`           → 1 row, the admin's own. Support could never
///     see a customer's balance.
///
/// The RPCs re-derive authority from the JWT, validate the change, and write an
/// `admin_audit_log` row naming the actor. If a call here throws, the change did
/// not happen — which is a strict improvement on silence.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// A refusal from the server, already carrying a message worth showing a human.
///
/// The `admin_*` RPCs raise with their own SQLSTATEs rather than generic errors
/// so the UI can tell "you may not do that" from "that value is impossible".
class AdminError implements Exception {
  AdminError(this.code, this.message, {this.hint});

  final String code;
  final String message;
  final String? hint;

  /// The caller is not a power user (or their session went stale).
  bool get isAuthorisation => code == 'KS460';

  /// The value was refused by a validator — the message names the range.
  bool get isValidation => code == 'KS466' || code == 'KS467';

  @override
  String toString() => message;
}

/// Everything the admin app can ask the server to do.
class AdminApi {
  AdminApi(this._db);

  final SupabaseClient _db;

  // ---------------------------------------------------------------- plumbing

  Future<T> _rpc<T>(String fn, [Map<String, dynamic>? args]) async {
    try {
      final res = await _db.rpc(fn, params: args);
      return res as T;
    } on PostgrestException catch (e) {
      throw AdminError(e.code ?? 'unknown', _humanise(e), hint: e.hint);
    }
  }

  Future<List<Map<String, dynamic>>> _rows(
    String fn, [
    Map<String, dynamic>? args,
  ]) async {
    final res = await _rpc<dynamic>(fn, args);
    if (res == null) return const [];
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _obj(
    String fn, [
    Map<String, dynamic>? args,
  ]) async {
    final res = await _rpc<dynamic>(fn, args);
    return (res as Map).cast<String, dynamic>();
  }

  /// Postgres prefixes raised messages with nothing useful, but PostgREST wraps
  /// permission failures in wording no operator should have to read.
  String _humanise(PostgrestException e) {
    switch (e.code) {
      case 'KS460':
        return 'This account is not a power user. Sign in with an admin account.';
      case 'KS461':
        return 'That record no longer exists — someone may have removed it.';
      case '42501':
        return 'The server refused this call. Your session may have expired.';
      default:
        return e.message;
    }
  }

  // ---------------------------------------------------------------- overview

  Future<Map<String, dynamic>> overview() => _obj('admin_overview');

  Future<List<Map<String, dynamic>>> audit({
    int limit = 100,
    String? targetType,
    String? action,
  }) => _rows('admin_list_audit', {
    'p_limit': limit,
    'p_target_type': targetType,
    'p_action': action,
  });

  // -------------------------------------------------------- scheduled jobs
  Future<List<Map<String, dynamic>>> scheduledJobs() =>
      _rows('admin_get_scheduled_jobs_overview');

  Future<Map<String, dynamic>> checkJobsHealth() =>
      _obj('check_scheduled_jobs_health');

  Future<Map<String, dynamic>> pruneDatabaseLogs({
    int cronRetentionDays = 14,
    int alertsRetentionDays = 90,
  }) => _obj('admin_prune_database_logs', {
    'p_cron_retention_days': cronRetentionDays,
    'p_alerts_retention_days': alertsRetentionDays,
  });

  // ------------------------------------------------------------------ config

  Future<List<Map<String, dynamic>>> configs() => _rows('admin_list_configs');

  Future<Map<String, dynamic>> setConfig(
    String key,
    String value, {
    String? note,
  }) => _obj('admin_set_config', {
    'p_key': key,
    'p_value': value,
    'p_note': note,
  });

  // ----------------------------------------------------------- app fee rules

  Future<List<Map<String, dynamic>>> appFeeRules() =>
      _rows('admin_list_app_fee_rules');

  Future<Map<String, dynamic>> saveDraftAppFeeRule({
    required String item,
    required double freePercentage,
    required double freeMinimum,
    required double standPercentage,
    required double standMinimum,
    required double premPercentage,
    required double premMinimum,
    String chargeUnit = 'purchase',
    String? changeReason,
  }) => _obj('admin_save_draft_app_fee_rule', {
    'p_item': item,
    'p_free_percentage': freePercentage,
    'p_free_minimum': freeMinimum,
    'p_stand_percentage': standPercentage,
    'p_stand_minimum': standMinimum,
    'p_prem_percentage': premPercentage,
    'p_prem_minimum': premMinimum,
    'p_charge_unit': chargeUnit,
    'p_change_reason': changeReason,
  });

  Future<Map<String, dynamic>> publishAppFeeRule({
    required String item,
    required double freePercentage,
    required double freeMinimum,
    required double standPercentage,
    required double standMinimum,
    required double premPercentage,
    required double premMinimum,
    String chargeUnit = 'purchase',
    String? changeReason,
  }) => _obj('admin_publish_app_fee_rule', {
    'p_item': item,
    'p_free_percentage': freePercentage,
    'p_free_minimum': freeMinimum,
    'p_stand_percentage': standPercentage,
    'p_stand_minimum': standMinimum,
    'p_prem_percentage': premPercentage,
    'p_prem_minimum': premMinimum,
    'p_charge_unit': chargeUnit,
    'p_change_reason': changeReason,
  });

  // ---------------------------------------------------- suppliers & catalogue

  /// Every service provider, with what it can sell, how many carriers it is
  /// mapped to, how much of the catalogue it holds, and a `readiness` string
  /// naming the one fault an operator cannot see by eye — a supplier switched
  /// on with nothing to sell ranks as infinitely cheap by absence.
  Future<List<Map<String, dynamic>>> serviceProviders() =>
      _rows('admin_list_service_providers');

  /// Creates the provider when [code] is new, updates it otherwise. A new
  /// provider always lands INACTIVE regardless of the patch — see the RPC.
  Future<Map<String, dynamic>> upsertServiceProvider(
    String code,
    Map<String, dynamic> patch, {
    String? note,
  }) => _obj('admin_upsert_service_provider', {
    'p_code': code,
    'p_patch': patch,
    'p_note': note,
  });

  /// Which suppliers can fulfil a carrier, and what each one calls the country
  /// and the telecom. Pass null for every carrier.
  Future<List<Map<String, dynamic>>> carrierProviderMap({String? carrierId}) =>
      _rows('admin_list_carrier_provider_map', {'p_carrier_id': carrierId});

  Future<Map<String, dynamic>> upsertCarrierProviderMap(
    String carrierId,
    String provider,
    Map<String, dynamic> patch, {
    String? note,
  }) => _obj('admin_upsert_carrier_provider_map', {
    'p_carrier_id': carrierId,
    'p_provider': provider,
    'p_patch': patch,
    'p_note': note,
  });

  /// Rebuilds `provider_offers` from the two upstream caches.
  ///
  /// This is the SECOND half of a catalogue refresh. The VM worker fills
  /// `provider_offers_cache` from the supplier APIs; this promotes that into
  /// the curated shelf that `carrier_refill_offer()` actually reads. Running
  /// only the first half leaves the new prices invisible to pricing.
  ///
  /// Manual `override_*` values are never touched by it.
  Future<Map<String, dynamic>> dtonePreviewStatus() => _obj('admin_dtone_preview_status');

  Future<Map<String, dynamic>> refreshProviderOffers({String? note}) =>
      _obj('admin_refresh_provider_offers', {'p_note': note});

  /// Total offers in the catalogue and the latest fetch timestamp from the supplier cache.
  Future<Map<String, dynamic>> offersSummary() async {
    int totalOffers = 0;
    int activeOffers = 0;
    DateTime? lastFetchedAt;

    try {
      totalOffers = await _db
          .from('admin_internal_provider_offers')
          .count(CountOption.exact);
      try {
        activeOffers = await _db
            .from('admin_internal_provider_offers')
            .count(CountOption.exact)
            .eq('is_active', true);
      } catch (_) {
        activeOffers = totalOffers;
      }
    } catch (_) {
      try {
        totalOffers = await _db
            .from('admin_internal_provider_offers_cache')
            .count(CountOption.exact);
        activeOffers = totalOffers;
      } catch (_) {}
    }

    try {
      final cacheRow = await _db
          .from('admin_internal_provider_offers_cache')
          .select('refreshed_at')
          .not('refreshed_at', 'is', null)
          .order('refreshed_at', ascending: false)
          .limit(1);
      if (cacheRow.isNotEmpty && cacheRow.first['refreshed_at'] != null) {
        lastFetchedAt = DateTime.tryParse('${cacheRow.first['refreshed_at']}');
      }
    } catch (_) {}

    if (lastFetchedAt == null) {
      try {
        final offerRow = await _db
            .from('admin_internal_provider_offers')
            .select('source_refreshed_at, updated_at')
            .order('updated_at', ascending: false)
            .limit(1);
        if (offerRow.isNotEmpty) {
          final s =
              offerRow.first['source_refreshed_at'] ??
              offerRow.first['updated_at'];
          if (s != null) {
            lastFetchedAt = DateTime.tryParse('$s');
          }
        }
      } catch (_) {}
    }

    return {
      'total_offers': totalOffers,
      'active_offers': activeOffers,
      'last_fetched_at': lastFetchedAt,
    };
  }

  /// Returns all available catalog offers for a specific provider and carrier,
  /// including SKU, delivery type, wholesale cost, and denomination details.
  Future<List<Map<String, dynamic>>> providerOffersForCarrier({
    required String carrierId,
    required String provider,
    required String carrierCode,
    String? countryCode,
    String? providerCountryCode,
  }) async {
    final p = provider.trim().toLowerCase();
    final country = countryCode?.trim().toUpperCase() ?? '';
    final providerCountry =
        (providerCountryCode ?? countryCode)?.trim().toUpperCase() ?? '';

    // DT One previews have a private, admin-only catalogue. Never resurrect
    // retired shelf/cache rows or silently fall back if this RPC is unavailable.
    // The server resolves the enabled country/operator mapping by carrier ID.
    if (p == 'dtone') {
      return _rows('admin_dtone_catalogue_offers', {'p_carrier_id': carrierId});
    }

    // 1. First check curated provider_offers mapped to carrier_id
    try {
      var query = _db
          .from('admin_internal_provider_offers')
          .select('*')
          .eq('carrier_id', carrierId)
          .eq('provider_code', p);
      if (country.isNotEmpty) {
        query = query.inFilter('country_code', [
          country,
          country.toLowerCase(),
        ]);
      }
      // Environment changes retire the DT One shelf. Historical rows must not
      // appear as current supplier offers while no Production catalogue is active.
      if (p == 'dtone') query = query.eq('is_active', true);
      final res = await query.order('effective_price_usd', ascending: true);

      final rows = List<Map<String, dynamic>>.from(res);
      if (rows.isNotEmpty) {
        return rows.map((r) {
          final price = r['effective_price_usd'] ?? r['source_price_usd'];
          final minP = r['source_price_min_usd'];
          final maxP = r['source_price_max_usd'];
          return {
            'offer_id': '${r['offer_code'] ?? r['id'] ?? ''}',
            'offer_name':
                '${r['effective_name'] ?? r['source_name'] ?? 'Airtime Top-Up'}',
            'delivery_type': '${r['delivery_type'] ?? 'direct'}',
            'price_type': '${r['source_price_type'] ?? 'FIXED'}',
            'price_fixed_usd': price != null
                ? (num.tryParse('$price')?.toDouble())
                : null,
            'price_min_usd': minP != null
                ? (num.tryParse('$minP')?.toDouble())
                : null,
            'price_max_usd': maxP != null
                ? (num.tryParse('$maxP')?.toDouble())
                : null,
            'send_min': r['source_send_min'],
            'send_max': r['source_send_max'],
            'send_currency': r['source_send_currency'],
            'service_type': '${r['offer_kind'] ?? 'airtime'}',
            'is_active': r['is_active'] != false,
            'benefit_summary': r['effective_name'] ?? r['source_name'],
          };
        }).toList();
      }
    } catch (_) {}

    // 2. Operator names can be shared across countries (for example Vodafone).
    // Raw offers require both parts of the supplier mapping. An unmapped
    // carrier must never fall back to another carrier's or country's catalogue.
    final codes = carrierCode
        .split(RegExp(r'[,/|]'))
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty && !c.startsWith('(') && !c.startsWith('*'))
        .toList();
    if (codes.isEmpty || providerCountry.isEmpty) return const [];

    var query = _db
        .from('admin_internal_provider_offers_cache')
        .select('*')
        .eq('api_provider', p)
        .inFilter('country_code', [
          providerCountry,
          providerCountry.toLowerCase(),
        ]);

    if (codes.length == 1) {
      query = query.eq('carrier_code', codes.first);
    } else if (codes.length > 1) {
      query = query.inFilter('carrier_code', codes);
    }

    final cacheRes = await query.order('price_fixed_usd', ascending: true);
    final cacheRows = List<Map<String, dynamic>>.from(cacheRes);
    return cacheRows.map((r) {
      final price = r['price_fixed_usd'];
      final minP = r['price_min_usd'];
      final maxP = r['price_max_usd'];
      return {
        'offer_id': '${r['offer_id'] ?? ''}',
        'offer_name': '${r['offer_name'] ?? 'Airtime Top-Up'}',
        'delivery_type': '${r['delivery_type'] ?? 'direct'}',
        'price_type': '${r['price_type'] ?? 'FIXED'}',
        'price_fixed_usd': price != null
            ? (num.tryParse('$price')?.toDouble())
            : null,
        'price_min_usd': minP != null
            ? (num.tryParse('$minP')?.toDouble())
            : null,
        'price_max_usd': maxP != null
            ? (num.tryParse('$maxP')?.toDouble())
            : null,
        'send_min': r['send_min'],
        'send_max': r['send_max'],
        'send_currency': r['send_currency'],
        'service_type': '${r['service_type'] ?? 'airtime'}',
        'is_active': true,
        'benefit_summary': r['benefit_summary'],
      };
    }).toList();
  }

  // ---------------------------------------------------------------- carriers

  Future<List<Map<String, dynamic>>> carriers() async {
    final res = await _db
        .from('carriers')
        .select('*, carrier_rules(*), countries(name, iso_code)');
    final rows = List<Map<String, dynamic>>.from(res);

    final mapped = rows.map((row) {
      final rules = row['carrier_rules'] as List<dynamic>?;
      final rule = (rules != null && rules.isNotEmpty)
          ? rules.first as Map<String, dynamic>
          : <String, dynamic>{};

      final flat = Map<String, dynamic>.from(row);
      flat.remove('carrier_rules');

      rule.forEach((k, v) {
        if (k != 'id' &&
            k != 'created_at' &&
            k != 'updated_at' &&
            k != 'carrier_id') {
          flat[k] = v;
        }
      });

      final country = row['countries'] as Map<String, dynamic>?;
      flat['country_name'] = country?['name'];
      flat['country_iso'] = country?['iso_code'];
      flat.remove('countries');
      flat['rule_last_verified_at'] = rule['last_verified_at'];

      return flat;
    }).toList();

    mapped.sort((a, b) {
      final cA = (a['country_name'] ?? '').toString();
      final cB = (b['country_name'] ?? '').toString();
      final cmp = cA.compareTo(cB);
      if (cmp != 0) return cmp;
      final nA = (a['name'] ?? '').toString();
      final nB = (b['name'] ?? '').toString();
      return nA.compareTo(nB);
    });

    return mapped;
  }

  /// [patch] carries only the fields being changed. An absent key means "leave
  /// alone"; a key set to null means "clear it". A misspelt key is refused
  /// rather than ignored — silently saving nothing is the failure this whole
  /// layer exists to end.
  Future<Map<String, dynamic>> updateCarrier(
    String carrierId,
    Map<String, dynamic> patch, {
    String? note,
  }) => _obj('admin_update_carrier', {
    'p_carrier_id': carrierId,
    'p_patch': patch,
    'p_note': note,
  });

  Future<Map<String, dynamic>> updateCarrierRule(
    String carrierId,
    Map<String, dynamic> patch, {
    String? note,
  }) => _obj('admin_update_carrier_rule', {
    'p_carrier_id': carrierId,
    'p_patch': patch,
    'p_note': note,
  });

  // ------------------------------------------------------------------- queue

  /// Marks a MANUAL execution fulfilled **and debits the wallet for it**.
  ///
  /// The debit is the part worth knowing about: nothing on `topup_executions`
  /// moves money — the debit lives in the VM worker, which only claims API rows.
  /// Before this, completing a manual refill delivered airtime and charged
  /// nobody. Returns `debited: false` when a debit already existed under the
  /// same `exec_<id>` reference, which is the retry case, not an error.
  Future<Map<String, dynamic>> completeManualRefill(
    String id, {
    String? note,
  }) => _obj('admin_complete_manual_refill', {
    'p_execution_id': id,
    'p_note': note,
  });

  Future<Map<String, dynamic>> switchGatewayToManual(
    String id, {
    String? note,
  }) => _obj('admin_switch_gateway_to_manual', {
    'p_execution_id': id,
    'p_note': note,
  });

  /// Fails an execution, refunding only a debit it can prove exists.
  Future<Map<String, dynamic>> failRefill(
    String id,
    String reason, {
    bool refund = true,
  }) => _obj('admin_fail_refill', {
    'p_execution_id': id,
    'p_reason': reason,
    'p_refund': refund,
  });

  // ------------------------------------------------------------------ alerts

  Future<List<Map<String, dynamic>>> channels() => _rows('admin_list_channels');

  Future<Map<String, dynamic>> updateChannel(
    String key,
    Map<String, dynamic> patch, {
    String? note,
  }) => _obj('admin_update_channel', {
    'p_channel_key': key,
    'p_patch': patch,
    'p_note': note,
  });

  Future<List<Map<String, dynamic>>> notificationHealth({int days = 30}) =>
      _rows('admin_notification_health', {'p_days': days});

  Future<Map<String, dynamic>> notificationDispatchHealth() =>
      _obj('admin_notification_dispatch_health');

  Future<List<Map<String, dynamic>>> notificationDispatchIncidents() =>
      _rows('admin_list_notification_dispatch_incidents');

  Future<Map<String, dynamic>> retryNotificationDispatchJob(String jobId) =>
      _obj('admin_retry_notification_dispatch_job', {'p_id': jobId});

  // ------------------------------------------------------------- alert clocks

  /// Overview stats and dry-run preview for the Alert Clock engine.
  Future<Map<String, dynamic>> alertClockOverview() =>
      _obj('admin_get_alert_clock_overview');

  Future<Map<String, dynamic>> alertClockSchedulerStatus() =>
      _obj('admin_alert_clock_scheduler_status');

  Future<Map<String, dynamic>> setAlertClockSchedulerEnabled(bool enabled) =>
      _obj('admin_set_alert_clock_scheduler_enabled', {'p_enabled': enabled});

  Future<Map<String, dynamic>> carrierAlertRule(String carrierId) =>
      _obj('admin_get_carrier_alert_rule', {'p_carrier_id': carrierId});

  Future<Map<String, dynamic>> previewCarrierAlertRule(
    String carrierId,
    Map<String, dynamic> patch,
  ) => _obj('admin_preview_carrier_alert_rule', {
    'p_carrier_id': carrierId,
    'p_patch': patch,
  });

  /// Filterable list of all SIM line alert clocks with carrier rule provenance.
  Future<Map<String, dynamic>> listAlertClocks({
    String? state,
    int limit = 50,
    int offset = 0,
  }) => _obj('admin_list_alert_clocks', {
    'p_state': state,
    'p_limit': limit,
    'p_offset': offset,
  });

  /// Batch recalculates alert clocks for all active SIM lines.
  Future<Map<String, dynamic>> syncAlertClocks() =>
      _obj('admin_sync_alert_clocks');

  // --------------------------------------------------------------- suppliers

  Future<Map<String, dynamic>> esimRuntimeStatus() =>
      _obj('admin_esim_runtime_status');

  Future<Map<String, dynamic>> esimCatalogueDiagnostics() =>
      _obj('admin_esim_catalogue_diagnostics');

  Future<List<Map<String, dynamic>>> esimSuppliers() =>
      _rows('admin_list_esim_suppliers');

  Future<Map<String, dynamic>> upsertEsimSupplier(
    String code,
    Map<String, dynamic> patch, {
    String? note,
  }) => _obj('admin_upsert_esim_supplier', {
    'p_code': code,
    'p_patch': patch,
    'p_note': note,
  });

  /// Queues a full catalogue re-pull from eSIM Go.
  ///
  /// Returns as soon as the request is QUEUED — pg_net is asynchronous and the
  /// walk is 28 pages. Read `esim_suppliers.last_sync_*` for the outcome; do
  /// not report success from this call alone.
  Future<Map<String, dynamic>> syncEsimCatalogue({String? note}) =>
      _obj('admin_sync_esim_catalogue', {'p_note': note});

  // --------------------------------------------------------------- affiliates

  Future<List<Map<String, dynamic>>> affiliatePartners() =>
      _rows('admin_list_affiliate_partners');

  Future<Map<String, dynamic>> upsertAffiliatePartner(
    String code,
    Map<String, dynamic> patch, {
    String? note,
  }) => _obj('admin_upsert_affiliate_partner', {
    'p_code': code,
    'p_patch': patch,
    'p_note': note,
  });

  Future<List<Map<String, dynamic>>> affiliateOffers({String? partnerCode}) =>
      _rows('admin_list_affiliate_offers', {'p_partner_code': partnerCode});

  /// Creates when [id] is null, updates otherwise.
  ///
  /// `price_checked_at` is NOT a patch field and never can be — the server
  /// stamps it. Pass `confirm_price: true` to record "I just looked at the
  /// partner's site and this price is still right"; editing `price_usd` counts
  /// as confirming it too.
  Future<Map<String, dynamic>> upsertAffiliateOffer(
    String? id,
    Map<String, dynamic> patch, {
    String? note,
  }) => _obj('admin_upsert_affiliate_offer', {
    'p_id': id,
    'p_patch': patch,
    'p_note': note,
  });

  /// Deactivates. Never a hard delete — clicks reference the offer and are what
  /// commission is reconciled against.
  Future<Map<String, dynamic>> deactivateAffiliateOffer(
    String id, {
    String? note,
  }) => _obj('admin_delete_affiliate_offer', {'p_id': id, 'p_note': note});

  Future<Map<String, dynamic>> affiliateOverview({int days = 30}) =>
      _obj('admin_affiliate_overview', {'p_days': days});

  Future<Map<String, dynamic>> syncAffiliateNetwork({
    int sinceDays = 45,
    String? note,
  }) => _obj('admin_sync_affiliate_network', {
    'p_since_days': sinceDays,
    'p_note': note,
  });

  // --------------------------------------------------------------------- mail

  /// Queues one hand-written message for delivery through Resend.
  ///
  /// The body is PLAIN TEXT. It is escaped and wrapped in a fixed template
  /// server-side — the form deliberately does not accept HTML, because an
  /// admin screen that renders arbitrary HTML from a verified domain is a
  /// phishing kit the moment a power-user session leaks.
  ///
  /// Returns once the message is QUEUED. Delivery happens in an Edge Function;
  /// poll [emails] for the outcome rather than reporting success from this.
  Future<Map<String, dynamic>> sendEmail({
    required List<String> to,
    required String subject,
    required String body,
    List<String> cc = const [],
    String? replyTo,
    String? from,
    String? note,
  }) => _obj('admin_send_email', {
    'p_to': to,
    'p_subject': subject,
    'p_body': body,
    'p_cc': cc,
    'p_reply_to': replyTo,
    'p_from': from,
    'p_note': note,
  });

  Future<List<Map<String, dynamic>>> emails({int limit = 50}) =>
      _rows('admin_list_emails', {'p_limit': limit});

  // ----------------------------------------------------------------- offline

  Future<List<Map<String, dynamic>>> offlineEndpoints() =>
      _rows('admin_list_offline_endpoints');

  /// Pass a null [id] to create. Promoting a row to primary demotes its sibling
  /// and re-points the mirrored `system_configs` key the customer app caches.
  Future<Map<String, dynamic>> upsertOfflineEndpoint(
    String? id,
    Map<String, dynamic> patch, {
    String? note,
  }) => _obj('admin_upsert_offline_endpoint', {
    'p_id': id,
    'p_patch': patch,
    'p_note': note,
  });

  Future<Map<String, dynamic>> deleteOfflineEndpoint(
    String id, {
    String? note,
  }) => _obj('admin_delete_offline_endpoint', {'p_id': id, 'p_note': note});

  // ---------------------------------------------------------------- vouchers

  /// Stock, demand, debt and SLA per carrier — only carriers that have one of
  /// them. A carrier with no premium line and no stock is not an operations
  /// problem, and sixty rows of zeroes hide the three that are.
  Future<List<Map<String, dynamic>>> voucherOverview() =>
      _rows('admin_voucher_overview');

  /// Never returns a PIN. `pin_last4` is an identifier, not a credential: it is
  /// there so a row can be matched against a physical card or a supplier
  /// statement. The whole PIN has exactly one exit from the database and it is
  /// `provision_offline_voucher`, which hands it to an entitled subscriber's
  /// device and nowhere else.
  Future<List<Map<String, dynamic>>> voucherStock({
    String? carrierId,
    String? status,
    int limit = 200,
  }) => _rows('admin_list_voucher_stock', {
    'p_carrier_id': carrierId,
    'p_status': status,
    'p_limit': limit,
  });

  /// Bulk-loads PINs for one carrier.
  ///
  /// [pins] takes either bare strings or objects carrying per-PIN overrides
  /// (`pin`, `serial`, `face_value_usd`, `expires_at`, `cost_usd`). [defaults]
  /// fills in the rest. A PIN already loaded for this carrier is SKIPPED and
  /// counted, not refused — a paste that overlaps a previous one by three rows
  /// should still load the other forty-seven.
  ///
  /// `face_value_usd` has no default anywhere. It is what the subscriber is
  /// asked to repay, and a plausible wrong number here is charged to a customer
  /// without anyone noticing.
  Future<Map<String, dynamic>> addVoucherStock(
    String carrierId,
    List<dynamic> pins, {
    Map<String, dynamic> defaults = const {},
    String? note,
  }) => _obj('admin_add_voucher_stock', {
    'p_carrier_id': carrierId,
    'p_pins': pins,
    'p_defaults': defaults,
    'p_note': note,
  });

  /// Voids unissued stock. A PIN already on somebody's handset cannot be voided
  /// here — voiding would not take it back, it would only stop us recognising
  /// it when they report the reveal. Write off the grant instead.
  Future<Map<String, dynamic>> voidVoucherStock(
    String id,
    String reason, {
    String? note,
  }) => _obj('admin_void_voucher_stock', {
    'p_id': id,
    'p_reason': reason,
    'p_note': note,
  });

  Future<List<Map<String, dynamic>>> voucherGrants({
    String? status,
    int limit = 200,
  }) => _rows('admin_list_voucher_grants', {
    'p_status': status,
    'p_limit': limit,
  });

  /// Forgives a debt. Deliberately NOT a wallet credit: no money moved when the
  /// voucher was revealed — that is the whole "gift now, pay later" design — so
  /// booking a credit would invent one. This clears the block on the
  /// subscriber's next voucher and records who chose to absorb the cost.
  Future<Map<String, dynamic>> writeOffVoucherGrant(
    String grantId,
    String reason, {
    String? note,
  }) => _obj('admin_write_off_voucher_grant', {
    'p_grant_id': grantId,
    'p_reason': reason,
    'p_note': note,
  });

  /// The fulfilment queue: premium subscribers entitled to a PIN we do not
  /// have, each with the deadline `OFFLINE_VOUCHER_MANUAL_SLA_DAYS` set.
  Future<List<Map<String, dynamic>>> voucherRequests({
    String? status = 'open',
    int limit = 200,
  }) => _rows('admin_list_voucher_requests', {
    'p_status': status,
    'p_limit': limit,
  });

  Future<Map<String, dynamic>> cancelVoucherRequest(
    String id,
    String reason, {
    String? note,
  }) => _obj('admin_cancel_voucher_request', {
    'p_id': id,
    'p_reason': reason,
    'p_note': note,
  });

  Future<List<Map<String, dynamic>>> voucherRedemptionCodes() =>
      _rows('admin_list_carrier_voucher_redemption');

  /// The USSD a subscriber dials to redeem, per carrier.
  ///
  /// `verified_at` is not a patch field and never can be — pass
  /// `{'verified': true}` and the server stamps it with the caller. Editing the
  /// template un-verifies it, because somebody has to look at the new string.
  /// The customer app only offers a dial button on a verified code: an
  /// unverified one is dialled by a person with no signal and no credit, and
  /// cannot be corrected afterwards.
  Future<Map<String, dynamic>> upsertVoucherRedemption(
    String carrierId,
    Map<String, dynamic> patch, {
    String? note,
  }) => _obj('admin_upsert_carrier_voucher_redemption', {
    'p_carrier_id': carrierId,
    'p_patch': patch,
    'p_note': note,
  });

  /// Queues a DingConnect PIN purchase.
  ///
  /// Every Ding PIN is a real, paid `SendTransfer` — there is no "give me a
  /// PIN" endpoint — so this spends money. It returns once the job is QUEUED;
  /// `worker_voucher_stock.js` on the VM performs the purchase. Read the job
  /// row for the outcome rather than reporting success from this call.
  Future<Map<String, dynamic>> queueDingVoucherPurchase({
    required String carrierId,
    required int quantity,
    String? accountNumber,
    num? maxUnitCost,
    String? note,
  }) => _obj('admin_queue_ding_voucher_purchase', {
    'p_carrier_id': carrierId,
    'p_quantity': quantity,
    'p_account_number': accountNumber,
    'p_max_unit_cost': maxUnitCost,
    'p_note': note,
  });

  Future<List<Map<String, dynamic>>> voucherPurchaseJobs({int limit = 50}) =>
      _rows('admin_list_voucher_purchase_jobs', {'p_limit': limit});

  /// Only a job the worker has not picked up. Once claimed, money may already
  /// be in flight at Ding and "cancelled" here would just lose the receipt.
  Future<Map<String, dynamic>> cancelVoucherPurchaseJob(
    String id, {
    String? note,
  }) => _obj('admin_cancel_voucher_purchase_job', {'p_id': id, 'p_note': note});

  // ----------------------------------------------------------------- support

  Future<List<Map<String, dynamic>>> tickets({
    String? status,
    int limit = 100,
  }) => _rows('admin_list_tickets', {'p_status': status, 'p_limit': limit});

  Future<Map<String, dynamic>> ticket(String id) =>
      _obj('admin_get_ticket', {'p_ticket_id': id});

  /// Posting the reply is what notifies the customer: C7's trigger on
  /// `ticket_messages` raises the notification. Do not add a second one.
  Future<Map<String, dynamic>> replyTicket(
    String id,
    String message, {
    String? newStatus,
  }) => _obj('admin_reply_ticket', {
    'p_ticket_id': id,
    'p_message': message,
    'p_new_status': newStatus,
  });

  Future<Map<String, dynamic>> setTicketStatus(
    String id,
    String status, {
    String? priority,
  }) => _obj('admin_set_ticket_status', {
    'p_ticket_id': id,
    'p_status': status,
    'p_priority': priority,
  });

  // ------------------------------------------------------------------- users

  Future<List<Map<String, dynamic>>> users({String? search, int limit = 100}) =>
      _rows('admin_list_users', {'p_search': search, 'p_limit': limit});

  Future<Map<String, dynamic>> user(String id) =>
      _obj('admin_get_user', {'p_user_id': id});

  /// Suspension and tier only.
  ///
  /// `is_power_user` is deliberately not settable here. `protect_is_power_user()`
  /// reverts any change to that column made under a non-service_role JWT and
  /// logs the caller as a privilege-escalation attempt — three of those inside
  /// an hour and it suspends the caller's own account. An admin promoting a
  /// colleague from this app would appear to succeed, do nothing, and on the
  /// third attempt lock themselves out. Promotion is a service_role action.
  Future<Map<String, dynamic>> setUserFlags(
    String userId,
    Map<String, dynamic> patch, {
    String? note,
  }) => _obj('admin_set_user_flags', {
    'p_user_id': userId,
    'p_patch': patch,
    'p_note': note,
  });

  /// Support goodwill credit, or a correction. Negative debits.
  ///
  /// Capped by `ADMIN_WALLET_ADJUST_MAX_USD`, reason mandatory, self-adjustment
  /// refused, and booked as `admin_adjustment` so it is neither giftable nor
  /// mistaken for a refund.
  Future<Map<String, dynamic>> adjustWallet(
    String userId,
    num amount,
    String reason,
  ) => _obj('admin_adjust_wallet', {
    'p_user_id': userId,
    'p_amount': amount,
    'p_reason': reason,
  });

  /// Lists customer refund requests, with lot items and statuses.
  Future<List<Map<String, dynamic>>> listRefundRequests({
    String? status,
    int limit = 50,
  }) => _rows('admin_list_refund_requests', {
    'p_status': ?status,
    'p_limit': limit,
  });

  /// Triggers server-side processing of an approved refund request through PayPal Payments v2.
  Future<Map<String, dynamic>> processRefundRequest({
    required String requestId,
  }) async {
    final response = await _db.functions.invoke(
      'process-wallet-refund',
      body: {'request_id': requestId},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw AdminError(
      'KS500',
      'Unexpected response from refund processor: $data',
    );
  }

  /// Lists country verification prices with optional search and zero-price filter.
  Future<Map<String, dynamic>> listCountryVerificationPrices({
    String? search,
    bool onlyZero = false,
    int limit = 50,
    int offset = 0,
  }) => _obj('admin_list_country_verification_prices', {
    'p_search': search,
    'p_only_zero': onlyZero,
    'p_limit': limit,
    'p_offset': offset,
  });

  /// Updates SMS and Call verification pricing for a country atomically.
  Future<Map<String, dynamic>> updateCountryVerificationPrices({
    required String countryId,
    required double smsVerifyCost,
    required double callVerifyCost,
    required int expectedVersion,
  }) => _obj('admin_update_country_verification_prices', {
    'p_country_id': countryId,
    'p_sms_verify_cost': smsVerifyCost,
    'p_call_verify_cost': callVerifyCost,
    'p_expected_version': expectedVersion,
  });

  /// Lists real live verification attempts.
  Future<Map<String, dynamic>> listLineVerificationAttempts({
    String? simLineId,
    String? status,
    int limit = 50,
    int offset = 0,
  }) => _obj('admin_list_line_verification_attempts', {
    'p_sim_line_id': simLineId,
    'p_status': status,
    'p_limit': limit,
    'p_offset': offset,
  });

  /// Fetches Telnyx telecom usage and account charges from the Edge Function
  /// `admin-telnyx-billing` within a date range and optional service filter.
  Future<Map<String, dynamic>> fetchTelnyxBilling({
    DateTime? startDate,
    DateTime? endDate,
    String serviceType = 'all',
  }) async {
    try {
      final response = await _db.functions.invoke(
        'admin-telnyx-billing',
        body: {
          if (startDate != null)
            'start_date': startDate.toUtc().toIso8601String(),
          if (endDate != null) 'end_date': endDate.toUtc().toIso8601String(),
          'service_type': serviceType,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw AdminError(
        'KS500',
        'Unexpected response from telnyx billing: $data',
      );
    } on FunctionException catch (e) {
      final msg = e.details is Map
          ? (e.details['error'] ?? e.reasonPhrase ?? e.toString())
          : (e.reasonPhrase ?? e.toString());
      throw AdminError('KS502', 'Failed to fetch Telnyx billing: $msg');
    } catch (e) {
      if (e is AdminError) rethrow;
      throw AdminError('KS500', 'Telecom billing error: $e');
    }
  }

  // ----------------------------------------------------------- whatsapp routing

  /// Lists all configured WhatsApp provider profiles (Baileys and Meta Cloud).
  Future<Map<String, dynamic>> listWhatsappProfiles() =>
      _obj('admin_list_whatsapp_profiles');

  /// Creates or updates a WhatsApp provider profile.
  Future<Map<String, dynamic>> saveWhatsappProfile({
    String? id,
    required String providerType,
    required String profileName,
    String? expectedSender,
    String? endpointUrl,
    String? secretToken,
    Map<String, dynamic> profileSecrets = const {},
    bool isActive = true,
    Map<String, dynamic> metadata = const {},
    int? expectedVersion,
  }) {
    final effectiveMeta = {...metadata, 'endpoint_url': ?endpointUrl};
    final secrets = <String, dynamic>{
      ...profileSecrets,
      (providerType == 'baileys' ? 'api_key' : 'access_token'): ?secretToken,
    };
    return _obj('admin_save_whatsapp_profile', {
      'p_id': id,
      'p_provider_kind': providerType,
      'p_label': profileName,
      'p_expected_sender': expectedSender,
      'p_is_enabled': isActive,
      'p_metadata': effectiveMeta,
      'p_secrets': secrets,
      'p_expected_version': expectedVersion,
    });
  }

  /// Deletes a WhatsApp provider profile (if unreferenced by active routes).
  Future<Map<String, dynamic>> deleteWhatsappProfile(String id) =>
      _obj('admin_delete_whatsapp_profile', {'p_id': id});

  /// Lists all country WhatsApp routing rules.
  Future<Map<String, dynamic>> listWhatsappRoutes() =>
      _obj('admin_list_whatsapp_routes');

  /// Updates WhatsApp routing for a country with optimistic concurrency check.
  Future<Map<String, dynamic>> updateWhatsappRoute({
    required String countryId,
    required String providerType,
    String? profileId,
    bool isActive = true,
    bool overrideAllowed = false,
    required int expectedVersion,
    String? note,
  }) => _obj('admin_update_whatsapp_route', {
    'p_country_id': countryId,
    'p_route_mode': providerType,
    'p_profile_id': profileId,
    'p_expected_version': expectedVersion,
    'p_note': note,
  });

  /// Lists durable WhatsApp message attempt logs.
  Future<Map<String, dynamic>> listWhatsappAttempts({
    String? countryId,
    String? profileId,
    String? purpose,
    String? provider,
    String? status,
    int limit = 50,
    int offset = 0,
  }) => _obj('admin_list_whatsapp_attempts', {
    'p_country_id': countryId,
    'p_purpose': purpose,
    'p_provider': provider,
    'p_state': status,
    'p_limit': limit,
    'p_offset': offset,
  });

  /// Records the result of a connectivity probe for a provider profile.
  Future<Map<String, dynamic>> recordWhatsappProbe({
    required String profileId,
    String? observedSender,
    required String readyState,
    String? errorCategory,
    String? errorDetail,
    Map<String, dynamic> metadataPatch = const {},
  }) => _obj('admin_record_whatsapp_probe', {
    'p_profile_id': profileId,
    'p_observed_sender': observedSender,
    'p_ready_state': readyState,
    'p_error_category': errorCategory,
    'p_error_detail': errorDetail,
    'p_metadata_patch': metadataPatch,
  });

  /// Probes live connectivity of a WhatsApp profile through the edge function.
  Future<Map<String, dynamic>> probeWhatsappProfile(String profileId) async {
    try {
      final response = await _db.functions.invoke(
        'send-whatsapp-alert',
        body: {'action': 'probe', 'profile_id': profileId},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw AdminError('KS500', 'Unexpected response from probe: $data');
    } on FunctionException catch (e) {
      final msg = e.details is Map
          ? (e.details['error'] ?? e.reasonPhrase ?? e.toString())
          : (e.reasonPhrase ?? e.toString());
      throw AdminError('KS502', 'Profile probe failed: $msg');
    } catch (e) {
      if (e is AdminError) rethrow;
      throw AdminError('KS500', 'Profile probe error: $e');
    }
  }

  /// Fetches raw QR code and session status for a Baileys worker profile.
  Future<Map<String, dynamic>> getWhatsappBaileysQr(String profileId) async {
    try {
      final response = await _db.functions.invoke(
        'send-whatsapp-alert',
        body: {'action': 'qr', 'profile_id': profileId},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw AdminError('KS500', 'Unexpected response from QR query: $data');
    } on FunctionException catch (e) {
      final msg = e.details is Map
          ? (e.details['error'] ?? e.reasonPhrase ?? e.toString())
          : (e.reasonPhrase ?? e.toString());
      throw AdminError('KS502', 'QR query failed: $msg');
    } catch (e) {
      if (e is AdminError) rethrow;
      throw AdminError('KS500', 'QR query error: $e');
    }
  }

  /// Disconnects/logs out a Baileys worker session.
  Future<Map<String, dynamic>> logoutWhatsappBaileys(String profileId) async {
    try {
      final response = await _db.functions.invoke(
        'send-whatsapp-alert',
        body: {'action': 'logout', 'profile_id': profileId},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw AdminError('KS500', 'Unexpected response from logout: $data');
    } on FunctionException catch (e) {
      final msg = e.details is Map
          ? (e.details['error'] ?? e.reasonPhrase ?? e.toString())
          : (e.reasonPhrase ?? e.toString());
      throw AdminError('KS502', 'Logout failed: $msg');
    } catch (e) {
      if (e is AdminError) rethrow;
      throw AdminError('KS500', 'Logout error: $e');
    }
  }

  /// Executes an admin test send to a phone number.
  Future<Map<String, dynamic>> sendWhatsappTest({
    required String phoneNumber,
    required String message,
    String? templateName,
    String? templateLanguage,
  }) async {
    try {
      final response = await _db.functions.invoke(
        'send-whatsapp-alert',
        body: {
          'action': 'test',
          'phone': phoneNumber,
          'message': message,
          'templateName': ?templateName,
          'templateLanguage': ?templateLanguage,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw AdminError('KS500', 'Unexpected response from test send: $data');
    } on FunctionException catch (e) {
      final msg = e.details is Map
          ? (e.details['error'] ?? e.reasonPhrase ?? e.toString())
          : (e.reasonPhrase ?? e.toString());
      throw AdminError('KS502', 'WhatsApp test send failed: $msg');
    } catch (e) {
      if (e is AdminError) rethrow;
      throw AdminError('KS500', 'WhatsApp test send error: $e');
    }
  }
}
