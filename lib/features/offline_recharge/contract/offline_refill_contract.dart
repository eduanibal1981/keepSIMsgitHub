import '../model/offline_refill_model.dart';
import 'package:keep_sims/core/result.dart';

abstract interface class OfflineRefillContract {
  Future<Result<OfflineRefillSettings>> getSettings();
  Future<Result<OfflineRefillSettings>> saveSettings(OfflineRefillSettings settings);
  Future<Result<List<CarrierUssdSuggestion>>> getUssdSuggestions(String carrierId);
}
