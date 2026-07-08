import '../entities/system_config.dart';

abstract class ISystemConfigRepository {
  /// Fetches a configuration by key.
  Future<SystemConfig?> getConfig(String key);

  /// Updates a configuration value.
  Future<void> updateConfig(String key, String value);

  /// Streams the system config changes.
  Stream<SystemConfig?> streamConfig(String key);
}
