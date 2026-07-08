import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/refill_request.dart';
import '../../domain/repositories/refill_request_repository.dart';

class SupabaseRefillRequestRepository implements IRefillRequestRepository {
  final SupabaseClient _supabase;

  SupabaseRefillRequestRepository(this._supabase);

  @override
  Future<RefillRequest?> getById(String id) async {
    final response = await _supabase
        .from('refill_requests')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return RefillRequest.fromJson(response);
  }

  @override
  Future<void> updateStatus(
    String id,
    String status, {
    String? methodUsed,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (methodUsed != null) {
      updates['fulfillment_method_used'] = methodUsed;
    }

    await _supabase.from('refill_requests').update(updates).eq('id', id);
  }

  @override
  Stream<List<RefillRequest>> streamPendingRequests() {
    return _supabase
        .from('refill_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .map(
          (data) => data.map((json) => RefillRequest.fromJson(json)).toList(),
        );
  }
}
