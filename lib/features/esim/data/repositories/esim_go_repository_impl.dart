import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/services/device_identity_service.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_order.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
import 'package:keep_sims/features/esim/domain/repositories/esim_repository.dart';

class EsimGoRepositoryImpl implements EsimRepository {
  final SupabaseClient _supabase;

  EsimGoRepositoryImpl({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<EsimPlan>> getPlans(String countryIsoCode) async {
    try {
      final String upperIso = countryIsoCode.trim().toUpperCase();

      final response = await _supabase
          .from('esim_offers')
          .select()
          .order('retail_price_usd', ascending: true);

      final List<dynamic> data = response as List<dynamic>;

      final plans = data.map((json) {
        final Map<String, dynamic> map = json as Map<String, dynamic>;
        final List<String> countries = (map['countries'] as List<dynamic>?)
                ?.map((e) => e.toString().toUpperCase())
                .toList() ??
            [];
        final List<String> roaming = (map['roaming_enabled'] as List<dynamic>?)
                ?.map((e) => e.toString().toUpperCase())
                .toList() ??
            [];

        return EsimPlan(
          id: (map['bundle_name'] as String?) ?? (map['id'] as String? ?? ''),
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
        );
      }).where((plan) {
        if (upperIso.isEmpty) return true;
        return plan.supportedCountries.contains(upperIso) ||
            plan.roamingEnabled.contains(upperIso);
      }).toList();

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
      final res = await _supabase.rpc('request_esim_purchase', params: {
        'p_offer_id': offerId,
        'p_quantity': quantity,
        // G10: device binding. Refusals come back as
        // {success:false, code:'DEVICE_BLOCKED'} in the same jsonb envelope.
        'p_device_id': await DeviceIdentityService(
          supabase: _supabase,
        ).deviceId(),
      });
      return res as String;
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('eSIM purchase failed: $e');
    }
  }

  @override
  Future<List<UserEsim>> getUserEsims() async {
    try {
      final response = await _supabase
          .from('user_esims')
          .select()
          .order('purchased_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(json as Map);
        return UserEsim(
          id: map['id'] as String,
          userId: map['user_id'] as String,
          esimOrderId: map['esim_order_id'] as String? ?? '',
          iccid: map['iccid'] as String? ?? '',
          lpaActivationCode: map['lpa_activation_code'] as String? ?? '',
          qrCodeUrl: map['qr_code_url'] as String? ?? '',
          bundleName: map['bundle_name'] as String? ?? 'eSIM Plan',
          provider: map['provider'] as String? ?? 'esim_go',
          status: map['status'] as String? ?? 'active',
          dataRemainingMb: (map['data_remaining_mb'] as num?)?.toInt() ?? 0,
          dataTotalMb: (map['data_total_mb'] as num?)?.toInt() ?? 0,
          purchasedAt: map['purchased_at'] != null
              ? DateTime.parse(map['purchased_at'] as String)
              : DateTime.now(),
          firstActivatedAt: map['first_activated_at'] != null
              ? DateTime.parse(map['first_activated_at'] as String)
              : null,
          expiresAt: map['expires_at'] != null
              ? DateTime.parse(map['expires_at'] as String)
              : null,
          lastSyncedAt: map['last_synced_at'] != null
              ? DateTime.parse(map['last_synced_at'] as String)
              : null,
          createdAt: map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : DateTime.now(),
          updatedAt: map['updated_at'] != null
              ? DateTime.parse(map['updated_at'] as String)
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch user eSIMs: $e');
    }
  }

  @override
  Future<List<EsimOrder>> getOrderHistory() async {
    try {
      final response = await _supabase
          .from('esim_orders')
          .select()
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
          wholesalePriceUsd:
              (map['wholesale_price_usd'] as num?)?.toDouble() ?? 0.0,
          retailPriceUsd: (map['retail_price_usd'] as num?)?.toDouble() ?? 0.0,
          markupPercent: (map['markup_percent'] as num?)?.toDouble() ?? 30.0,
          status: map['status'] as String? ?? 'pending',
          providerOrderRef: map['provider_order_ref'] as String?,
          errorMessage: map['error_message'] as String?,
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
    return _supabase
        .from('esim_orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((events) {
          if (events.isEmpty) return null;
          final map = events.first;
          return EsimOrder(
            id: map['id'] as String,
            userId: map['user_id'] as String,
            provider: map['provider'] as String? ?? 'esim_go',
            bundleName: map['bundle_name'] as String,
            quantity: (map['quantity'] as num?)?.toInt() ?? 1,
            wholesalePriceUsd:
                (map['wholesale_price_usd'] as num?)?.toDouble() ?? 0.0,
            retailPriceUsd:
                (map['retail_price_usd'] as num?)?.toDouble() ?? 0.0,
            markupPercent: (map['markup_percent'] as num?)?.toDouble() ?? 30.0,
            status: map['status'] as String? ?? 'pending',
            providerOrderRef: map['provider_order_ref'] as String?,
            errorMessage: map['error_message'] as String?,
            createdAt: DateTime.parse(map['created_at'] as String),
            updatedAt: DateTime.parse(map['updated_at'] as String),
          );
        });
  }
}
