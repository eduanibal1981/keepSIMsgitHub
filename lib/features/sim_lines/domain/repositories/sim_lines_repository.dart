import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_self_service_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_activity_log_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/payment_method_model.dart';
import 'package:keep_sims/features/sim_lines/data/datasources/telnyx_verification_service.dart';

abstract class SimLinesRepository {
  Future<List<SimLine>> getSimLines();
  Future<SimLine> addSimLine(SimLine line);
  Future<SimLine> updateSimLine(SimLine line);
  Future<void> deleteSimLine(String id);
  Future<List<Country>> getSupportedCountries();
  Future<List<Carrier>> getCarriersForCountry(String countryId);
  Future<CarrierRule?> getCarrierRule(String carrierId);
  Future<CarrierRule?> getCarrierRuleById(String ruleId);
  Future<CarrierSelfService?> getCarrierSelfService(String carrierId);
  Future<List<LineActivityLog>> getLineActivityLogs(String simLineId);
  Future<void> deleteLineActivityLog(String id);
  Future<void> cleanMockLogs(String simLineId);
  Future<void> clearAllActivityLogs(String simLineId);
  Future<String> requestInstantRefill({
    required String simLineId,
    required String offerId,
    required String paymentGatewayCode,
    required double displayBaseUsd,
    double? amountUsd,
  });
  Future<int> queuePremiumRefillExecutions({
    required String simLineId,
    required String scheduledTopupId,
    DateTime? planExpiresAt,
  });
  Future<String?> triggerMissedCall(String phoneNumber);
  Future<bool> checkCallStatus(String callSid);
  Future<String?> triggerSmsVerification(String phoneNumber);
  Future<TelnyxSmsResult> checkSmsDeliveryStatus(String messageId);
  Future<void> confirmLineVerification(String simLineId, {String channel = 'twilio_missed_call', String? carrierName});
  Future<void> cancelCall(String callSid);
  Future<List<Map<String, dynamic>>> fetchZenditOffers(String countryId, String carrierId);

  /// I1: every offer this line can actually buy, across every enabled supplier,
  /// ranked cheapest-first by the same rule `request_instant_refill` uses to
  /// resolve the purchase. Prefer this over [fetchZenditOffers] wherever a SIM
  /// line id is in hand — [fetchZenditOffers] resolves only the carrier's
  /// single default supplier and is kept for the add-line flow, which has a
  /// country and carrier but no line yet.
  Future<List<Map<String, dynamic>>> fetchLineRefillOffers(String simLineId);
  Future<List<PaymentMethod>> getPaymentMethods();
  Future<void> recordManualExternalRecharge({
    required String simLineId,
    required DateTime rechargeDate,
    double? amount,
    String? note,
  });
}
