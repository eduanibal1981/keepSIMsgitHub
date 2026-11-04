import 'package:keep_sims/features/voip_calling/data/models/voip_call_session_model.dart';
import 'package:keep_sims/features/calling/domain/call_destination.dart';

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

List<VoipCallSession> filterFreeCallHistory(
  List<VoipCallSession> calls,
  String query,
) {
  final text = CallDestination.normalizeDigits(query).trim().toLowerCase();
  if (text.isEmpty) return calls;
  final compact = text.replaceAll(RegExp(r'[\s().-]'), '');
  return calls
      .where(
        (call) =>
            [
              call.peerName,
              call.peerPhone,
              call.peerPublicId,
              call.peerEmail,
            ].whereType<String>().any(
              (value) =>
                  value.toLowerCase().contains(text) ||
                  (compact.isNotEmpty &&
                      value
                          .toLowerCase()
                          .replaceAll(RegExp(r'[\s().-]'), '')
                          .contains(compact)),
            ),
      )
      .toList();
}
