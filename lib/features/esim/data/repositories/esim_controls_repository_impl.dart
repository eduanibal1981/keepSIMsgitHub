import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/services/device_identity_service.dart';
import '../../domain/entities/esim_controls.dart';
import '../../domain/repositories/esim_controls_repository.dart';

class EsimControlsRepositoryImpl implements EsimControlsRepository {
  EsimControlsRepositoryImpl(this.client);
  final SupabaseClient client;
  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    final r = await client.functions.invoke(
      'esim-recharge-discovery',
      body: body,
    );
    if (r.status != 200 || r.data is! Map) {
      throw Exception('eSIM controls are temporarily unavailable.');
    }
    return Map<String, dynamic>.from(r.data as Map);
  }

  @override
  Future<EsimControlSnapshot> load(String id) async {
    final r = await Future.wait([
      _call({'action': 'controls', 'profile_id': id}),
      _call({'action': 'automation', 'profile_id': id}),
    ]);
    return EsimControlSnapshot(r[0], r[1]);
  }

  @override
  Future<String> control(
    String id,
    String action,
    String key,
    EsimControlSnapshot snapshot,
  ) async =>
      (await _call({
            'action': 'control',
            'profile_id': id,
            'control': action,
            'request_key': key,
            if (action == 'cancel') ...{
              'quote_id': snapshot.controls['quote_id'],
              'acceptance_key': snapshot.controls['acceptance_key'],
            },
          }))['status']
          as String? ??
      'UNAVAILABLE';
  @override
  Future<String> setAutomation(
    String id,
    int revision,
    bool enabled,
    EsimAutomationSettings? settings,
  ) async =>
      (await _call({
            'action': 'set_automation',
            'profile_id': id,
            'expected_revision': revision,
            'enabled': enabled,
            'settings': settings?.toJson(),
            'device_id': enabled
                ? await DeviceIdentityService(supabase: client).deviceId()
                : null,
          }))['status']
          as String? ??
      'UNAVAILABLE';
}
