import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_activity_log_model.dart';

abstract class SimLinesRepository {
  Future<List<SimLine>> getSimLines();
  Future<SimLine> addSimLine(SimLine line);
  Future<SimLine> updateSimLine(SimLine line);
  Future<void> deleteSimLine(String id);
  Future<List<Country>> getSupportedCountries();
  Future<List<Carrier>> getCarriersForCountry(String countryId);
  Future<List<LineActivityLog>> getLineActivityLogs(String simLineId);
  Future<void> deleteLineActivityLog(String id);
  Future<void> cleanMockLogs(String simLineId);
  Future<void> clearAllActivityLogs(String simLineId);
  Future<void> recordManualTopupExecution({
    required String simLineId,
    required double amount,
    required String status,
    String? failureReason,
  });
  Future<String?> triggerMissedCall(String phoneNumber);
  Future<bool> checkCallStatus(String callSid);
  Future<void> confirmLineVerification(String simLineId);
  Future<void> cancelCall(String callSid);
}
