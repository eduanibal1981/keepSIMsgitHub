import '../data/models/available_virtual_number_model.dart';
import '../data/models/second_number_models.dart';
import '../data/models/virtual_did_model.dart';

abstract interface class SecondNumberContract {
  Future<List<VirtualDidNumber>> getVirtualDids();
  Future<List<SecondNumberCountry>> getSecondNumberCountries();
  Future<List<AvailableVirtualNumber>> searchAvailableNumbers({
    required String countryCode,
    int limit = 15,
    String? areaCode,
  });
  Future<List<SecondNumberOrder>> getPendingSecondNumberOrders();
  Future<SecondNumberOrder> purchaseSecondNumber({
    required String quoteId,
    required bool autoRenew,
  });
  Future<SecondNumberOrder> getSecondNumberOrder(String id);
  Stream<List<SecondNumberMessage>> watchDidMessages(String didId);
  Future<void> markDidMessageRead(String messageId);
  Future<void> setSecondNumberRenewal(String didId, bool enabled);
  Future<void> releaseSecondNumber(String didId);
}
