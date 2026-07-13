import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_activity_log_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/payment_method_model.dart';

abstract class SimLinesRepository {
  Future<List<SimLine>> getSimLines();
  Future<SimLine> addSimLine(SimLine line);
  Future<SimLine> updateSimLine(SimLine line);
  Future<void> deleteSimLine(String id);
  Future<List<Country>> getSupportedCountries();
  Future<List<Carrier>> getCarriersForCountry(String countryId);
  Future<CarrierRule?> getCarrierRule(String carrierId);
  Future<CarrierRule?> getCarrierRuleById(String ruleId);
  Future<List<LineActivityLog>> getLineActivityLogs(String simLineId);
  Future<void> deleteLineActivityLog(String id);
  Future<void> cleanMockLogs(String simLineId);
  Future<void> clearAllActivityLogs(String simLineId);
  Future<void> recordManualTopupExecution({
    required String simLineId,
    required double baseCostUsd,
    required String paymentGatewayCode,
    required String status,
    String? failureReason,
    String? offerId,
    int? offerValue,
  });
  Future<void> scheduleTopupExecution({
    required String simLineId,
    required double amount,
    required DateTime executionTime,
    required String executionType,
    String? offerId,
    int? offerValue,
    String? scheduledTopupId,
  });
  Future<String?> triggerMissedCall(String phoneNumber);
  Future<bool> checkCallStatus(String callSid);
  Future<void> confirmLineVerification(String simLineId);
  Future<void> cancelCall(String callSid);
  Future<List<Map<String, dynamic>>> fetchZenditOffers(String countryId, String carrierId);
  Future<List<PaymentMethod>> getPaymentMethods();
}
