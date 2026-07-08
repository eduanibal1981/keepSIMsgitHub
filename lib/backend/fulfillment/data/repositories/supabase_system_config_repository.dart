import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/system_config.dart';
import '../../domain/repositories/system_config_repository.dart';

class SupabaseSystemConfigRepository implements ISystemConfigRepository {
  final SupabaseClient _supabase;

  SupabaseSystemConfigRepository(this._supabase);

  @override
  Future<SystemConfig?> getConfig(String key) async {
    final response = await _supabase
        .from('system_configs')
        .select()
        .eq('config_key', key)
        .maybeSingle();

    if (response == null) return null;
    return SystemConfig.fromJson(response);
  }

  @override
  Future<void> updateConfig(String key, String value) async {
    await _supabase
        .from('system_configs')
        .update({
          'config_value': value,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('config_key', key);
  }

  @override
  Stream<SystemConfig?> streamConfig(String key) {
    return _supabase
        .from('system_configs')
        .stream(primaryKey: ['config_key'])
        .eq('config_key', key)
        .map((data) {
          if (data.isEmpty) return null;
          return SystemConfig.fromJson(data.first);
        });
  }
}
