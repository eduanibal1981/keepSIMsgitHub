import 'package:keep_sims/core/utils/retail_poll_ticks.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/services/device_identity_service.dart';
import 'package:keep_sims/features/esim/domain/entities/affiliate_click_result.dart';
import 'package:keep_sims/features/esim/domain/entities/compare_offer.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_order.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
import 'package:keep_sims/features/esim/domain/repositories/esim_repository.dart';

class EsimGoRepositoryImpl implements EsimRepository {
  final SupabaseClient _supabase;

  EsimGoRepositoryImpl({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<CompareOffer>> compareOffers(
    String countryIsoCode, {
    CompareFilters filters = const CompareFilters(),
    int limit = 60,
    int offset = 0,
  }) async {
    try {
      // Every bound comes from a `wire*` getter rather than the raw field, so
      // the "an exact list only counts in exact mode" rule is applied once, in
      // CompareFilters, instead of being re-implemented here.
      final res = await _supabase.rpc(
        'compare_esim_offers_v2',
        params: {
          'p_country_code': countryIsoCode.trim().toUpperCase(),
          'p_coverage': filters.coverage,
          'p_plan_types': filters.planTypes,
          'p_min_data_mb': filters.wireMinDataMb,
          'p_max_data_mb': filters.wireMaxDataMb,
          'p_data_exact_mb': filters.wireDataExactMb,
          'p_min_days': filters.wireMinDays,
          'p_max_days': filters.wireMaxDays,
          'p_days_exact': filters.wireDaysExact,
          'p_min_price_usd': filters.wireMinPriceUsd,
          'p_max_price_usd': filters.wireMaxPriceUsd,
          'p_unlimited_only': filters.wireUnlimitedOnly,
          'p_speed_tiers': filters.wireSpeedTiers,
          'p_sort': filters.sort.wire,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final rows = (res as List<dynamic>?) ?? const [];
      return rows
          .map((e) => CompareOffer.fromRpc(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to load eSIM comparison: $e');
    }
  }

  @override
  Future<CompareBounds> compareFilterBounds(String countryIsoCode) async {
    try {
      final res = await _supabase.rpc(
        'compare_esim_filter_bounds',
        params: {'p_country_code': countryIsoCode.trim().toUpperCase()},
      );
      return CompareBounds.fromRpc(res);
    } catch (_) {
      // Empty bounds make the sheet fall back to All-only on each dimension,
      // which is a usable sheet. Throwing here would take the filters down
      // with it over a call that only decides which chips to draw.
      return const CompareBounds();
    }
  }

  @override
  Future<AffiliateClickResult> recordAffiliateClick(
    String offerId, {
    String? countryCode,
  }) async {
    try {
      final res = await _supabase.rpc(
        'record_affiliate_click',
        params: {
          'p_offer_id': offerId,
          'p_country_code': countryCode,
          'p_device_id': await DeviceIdentityService(
            supabase: _supabase,
          ).deviceId(),
        },
      );
      return AffiliateClickResult.fromRpc(res);
    } catch (_) {
      // A refusal here must never fall through to "open something anyway".
      // An untracked outbound click is traffic given away for free.
      return const AffiliateClickResult(success: false);
    }
  }

  @override
  Future<List<EsimPlan>> getPlans(String countryIsoCode) async {
    try {
      final String upperIso = countryIsoCode.trim().toUpperCase();

      // Filter server-side. This used to select the entire `esim_offers` view
      // and match countries in Dart, which was fine while the supplier fetch
      // was accidentally truncated to 50 rows and is not now that the real
      // catalogue (5,412 bundles) is cached. `countries` and `roaming_enabled`
      // both carry GIN indexes for exactly this predicate.
      final response = await _supabase
          .from('esim_offers')
          .select(
            'id,provider,bundle_name,description,countries,roaming_enabled,data_amount_mb,duration_days,retail_price_usd,image_url,is_unlimited,catalogue_details',
          )
          .or('countries.cs.{$upperIso},roaming_enabled.cs.{$upperIso}')
          .order('retail_price_usd', ascending: true)
          .limit(200);

      final List<dynamic> data = response as List<dynamic>;

      final plans = data
          .map((json) {
            final Map<String, dynamic> map = json as Map<String, dynamic>;
            final List<String> countries =
                (map['countries'] as List<dynamic>?)
                    ?.map((e) => e.toString().toUpperCase())
                    .toList() ??
                [];
            final List<String> roaming =
                (map['roaming_enabled'] as List<dynamic>?)
                    ?.map((e) => e.toString().toUpperCase())
                    .toList() ??
                [];

            return EsimPlan(
              id:
                  (map['id'] as String?) ??
                  (map['bundle_name'] as String? ?? ''),
              name: (map['description'] as String?)?.isNotEmpty == true
                  ? map['description'] as String
                  : (map['bundle_name'] as String? ?? ''),
              dataAmountMB: (map['data_amount_mb'] as num?)?.toInt() ?? 0,
              durationDays: (map['duration_days'] as num?)?.toInt() ?? 0,
              priceUsd: (map['retail_price_usd'] as num?)?.toDouble() ?? 0.0,
              providerName: (map['provider'] as String?) ?? 'eSIM Go',
              description: map['description'] as String?,
              supportedCountries: countries,
              roamingEnabled: roaming,
              imageUrl: map['image_url'] as String?,
              isUnlimited: map['is_unlimited'] == true,
              catalogueDetails: map['catalogue_details'] is Map
                  ? Map<String, dynamic>.from(map['catalogue_details'] as Map)
                  : null,
            );
          })
          .where((plan) {
            if (upperIso.isEmpty) return true;
            return plan.supportedCountries.contains(upperIso) ||
                plan.roamingEnabled.contains(upperIso);
          })
          .toList();

      return plans;
    } catch (e) {
      throw Exception('Failed to fetch eSIM plans from database: $e');
    }
  }

  @override
  Future<bool> validatePlanPurchase(String planId, {int quantity = 1}) async {
    return true;
  }

  @override
  Future<String> requestPurchase(String offerId, {int quantity = 1}) async {
    try {
      final res = await _supabase.rpc(
        'request_esim_purchase',
        params: {
          'p_offer_id': offerId,
          'p_quantity': quantity,
          // G10: device binding. Refusals come back as
          // {success:false, code:'DEVICE_BLOCKED'} in the same jsonb envelope.
          'p_device_id': await DeviceIdentityService(
            supabase: _supabase,
          ).deviceId(),
        },
      );
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        if (map['success'] == false) {
          throw Exception(
            map['error'] ?? map['reason'] ?? map['code'] ?? 'Purchase failed',
          );
        }
        final orderId = map['order_id'] ?? map['id'];
        if (orderId != null) return orderId.toString();
      }
      return res.toString();
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('eSIM purchase failed: $e');
    }
  }

  @override
  Future<List<UserEsim>> getUserEsims({bool requestRefresh = false}) async {
    if (requestRefresh) await _supabase.rpc('request_esim_profile_refresh');
    final response = await _supabase
        .from('customer_esim_profiles')
        .select()
        .order('purchased_at', ascending: false);
    return response
        .map((row) => UserEsim.fromRecord(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<List<EsimOrder>> getOrderHistory() async {
    try {
      final response = await _supabase
          .from('customer_esim_orders')
          .select(
            'id,user_id,provider,bundle_name,quantity,retail_price_usd,status,created_at,updated_at,error_message,delivery_state',
          )
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(json as Map);
        return EsimOrder(
          id: map['id'] as String,
          userId: map['user_id'] as String,
          provider: map['provider'] as String? ?? 'esim_go',
          bundleName: map['bundle_name'] as String,
          quantity: (map['quantity'] as num?)?.toInt() ?? 1,
          retailPriceUsd: (map['retail_price_usd'] as num?)?.toDouble() ?? 0.0,
          status: map['status'] as String? ?? 'pending',
          errorMessage: map['error_message'] as String?,
          deliveryState: map['delivery_state'] as String? ?? 'unverified',
          createdAt: DateTime.parse(map['created_at'] as String),
          updatedAt: DateTime.parse(map['updated_at'] as String),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch eSIM order history: $e');
    }
  }

  @override
  Stream<EsimOrder?> watchOrder(String orderId) {
    // Poll only the retail receipt view. Realtime base-table payloads can
    // contain privileged supplier columns even when the UI does not parse them.
    return retailPollTicks(const Duration(seconds: 3))
        .asyncMap(
          (_) => _supabase
              .from('customer_esim_orders')
              .select(
                'id,user_id,provider,bundle_name,quantity,retail_price_usd,status,created_at,updated_at,error_message,delivery_state',
              )
              .eq('id', orderId)
              .limit(1),
        )
        .map((events) {
          if (events.isEmpty) return null;
          final map = events.first;
          return EsimOrder(
            id: map['id'] as String,
            userId: map['user_id'] as String,
            provider: map['provider'] as String? ?? 'esim_go',
            bundleName: map['bundle_name'] as String,
            quantity: (map['quantity'] as num?)?.toInt() ?? 1,
            retailPriceUsd:
                (map['retail_price_usd'] as num?)?.toDouble() ?? 0.0,
            status: map['status'] as String? ?? 'pending',
            errorMessage: map['error_message'] as String?,
            deliveryState: map['delivery_state'] as String? ?? 'unverified',
            createdAt: DateTime.parse(map['created_at'] as String),
            updatedAt: DateTime.parse(map['updated_at'] as String),
          );
        });
  }
}
