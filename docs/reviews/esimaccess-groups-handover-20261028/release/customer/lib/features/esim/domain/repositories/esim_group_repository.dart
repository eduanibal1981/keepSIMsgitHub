import '../entities/esim_group.dart';

abstract interface class EsimGroupRepository {
  Future<EsimOrganization> organization();
  Future<EsimGroupQuote> quote(String group, List<EsimTravellerIntent> members);
  Future<Map<String, dynamic>> accept(
    String quoteId,
    String acceptanceKey,
    String requestKey,
  );
  Future<String> label(String profileId, String traveller, String group);
}
