import '../entities/esim_controls.dart';

abstract interface class EsimControlsRepository {
  Future<EsimControlSnapshot> load(String profileId);
  Future<String> control(
    String profileId,
    String action,
    String requestKey,
    EsimControlSnapshot snapshot,
  );
  Future<String> setAutomation(
    String profileId,
    int revision,
    bool enabled,
    EsimAutomationSettings? settings,
  );
}
