import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/services/device_identity_service.dart';
import '../../domain/entities/esim_group.dart';
import '../../domain/repositories/esim_group_repository.dart';

class EsimGroupRepositoryImpl implements EsimGroupRepository {
  EsimGroupRepositoryImpl(this.client);
  final SupabaseClient client;
  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    final response = await client.functions.invoke(
      'esim-recharge-discovery',
      body: body,
    );
    if (response.status != 200 || response.data is! Map) {
      throw Exception('Group request unavailable');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<EsimOrganization> organization() async =>
      EsimOrganization(await _call({'action': 'organization'}));
  @override
  Future<EsimGroupQuote> quote(
    String group,
    List<EsimTravellerIntent> members,
  ) async => EsimGroupQuote(
    await _call({
      'action': 'quote_group',
      'group_label': group,
      'members': members.map((m) => m.toJson()).toList(),
    }),
  );
  @override
  Future<Map<String, dynamic>> accept(
    String quoteId,
    String acceptanceKey,
    String requestKey,
  ) async => _call({
    'action': 'accept_group',
    'quote_id': quoteId,
    'acceptance_key': acceptanceKey,
    'request_key': requestKey,
    'device_id': await DeviceIdentityService(supabase: client).deviceId(),
  });
  @override
  Future<String> label(String id, String traveller, String group) async =>
      (await _call({
            'action': 'label',
            'profile_id': id,
            'traveller_label': traveller,
            'group_label': group,
          }))['status']
          as String? ??
      'UNAVAILABLE';
}
