import 'package:keep_sims/features/topup/data/models/top_up_result.dart';
import 'package:keep_sims/features/topup/domain/repositories/i_top_up_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Zendit exclusively through Supabase Edge Functions
/// (`execute_zendit_recharge`, `fetch_zendit_offers`) so the Zendit API
/// secret never ships inside the client binary.
class ZenditRepository implements ITopUpRepository {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  Future<TopUpResult> executeRecharge({
    required String phoneNumber,
    required String countryCode,
    required double amount,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'execute_zendit_recharge',
        body: {
          'phoneNumber': phoneNumber,
          'countryCode': countryCode,
          'amount': amount,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const TopUpResult(
          success: false,
          transactionId: '',
          errorMessage: 'Unexpected response from recharge service',
        );
      }

      return TopUpResult(
        success: data['success'] == true,
        transactionId: data['transactionId'] as String? ?? '',
        errorMessage: data['errorMessage'] as String?,
        amountToppedUp: (data['amountToppedUp'] as num?)?.toDouble(),
        localBenefit: data['localBenefit'] as String?,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map<String, dynamic>
          ? (details['errorMessage'] ?? details['error'] ?? e.reasonPhrase)
          : e.reasonPhrase;
      return TopUpResult(
        success: false,
        transactionId: '',
        errorMessage: 'Recharge service error: $message',
      );
    } catch (e) {
      return TopUpResult(
        success: false,
        transactionId: '',
        errorMessage: 'Network Exception: $e',
      );
    }
  }

  /// Fetches all available offers for a country code.
  Future<List<dynamic>> fetchOffersForCountry(String countryCode) async {
    try {
      final response = await _supabase.functions.invoke(
        'fetch_zendit_offers',
        body: {'countryCode': countryCode},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['offers'] as List<dynamic>? ?? [];
      }
    } catch (_) {}
    return [];
  }
}
