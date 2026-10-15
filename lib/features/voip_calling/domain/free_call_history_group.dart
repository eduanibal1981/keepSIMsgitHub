import 'package:keep_sims/features/voip_calling/data/models/voip_call_session_model.dart';

class FreeCallHistoryGroup {
  final List<VoipCallSession> calls;
  FreeCallHistoryGroup(Iterable<VoipCallSession> calls)
    : calls = List.unmodifiable(calls);
  bool get allMissed => calls.every(
    (call) => call.status == 'missed' || call.status == 'timeout',
  );
}

List<FreeCallHistoryGroup> groupFreeCallHistory(
  List<VoipCallSession> sessions,
) {
  final ordered = [...sessions]
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  final groups = <String, List<VoipCallSession>>{};
  for (final call in ordered) {
    final local = call.startedAt.toLocal();
    // Missing peer IDs must not merge unrelated records by a display name.
    final peer = call.peerId.isEmpty ? call.id : call.peerId;
    final key = '$peer:${local.year}:${local.month}:${local.day}';
    (groups[key] ??= []).add(call);
  }
  return groups.values.map(FreeCallHistoryGroup.new).toList(growable: false);
}
