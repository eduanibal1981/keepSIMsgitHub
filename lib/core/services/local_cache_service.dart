import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'local_cache_service.g.dart';

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) async {
  return SharedPreferences.getInstance();
}

@Riverpod(keepAlive: true)
LocalCacheService localCacheService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  return LocalCacheService(prefs);
}

class LocalCacheService {
  final SharedPreferences? _prefs;

  LocalCacheService(this._prefs);

  /// Writes a plain string to the cache.
  Future<bool> writeString(String key, String value) async {
    final prefs = _prefs;
    if (prefs == null) return false;
    return prefs.setString(key, value);
  }

  /// Reads a plain string from the cache.
  String? readString(String key) {
    final prefs = _prefs;
    if (prefs == null) return null;
    return prefs.getString(key);
  }

  /// Encodes and writes any JSON-serializable object or list to cache.
  Future<bool> writeJson(String key, dynamic json) async {
    final prefs = _prefs;
    if (prefs == null) return false;
    try {
      final encodedValue = jsonEncode(json);
      return prefs.setString(key, encodedValue);
    } catch (_) {
      return false;
    }
  }

  /// Reads, decodes and returns a JSON-serialized object or list from cache.
  dynamic readJson(String key) {
    final prefs = _prefs;
    if (prefs == null) return null;
    final value = prefs.getString(key);
    if (value == null) return null;
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  /// Deletes a cached item.
  Future<bool> remove(String key) async {
    final prefs = _prefs;
    if (prefs == null) return false;
    return prefs.remove(key);
  }
}
