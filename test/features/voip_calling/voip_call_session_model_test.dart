import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/voip_calling/data/models/ice_server_model.dart';
import 'package:keep_sims/features/voip_calling/data/models/voip_call_session_model.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/voip_calling_controller.dart';

void main() {
  group('IceServerModel', () {
    test('parses single or multiple urls properly', () {
      final json = {
        'urls': ['stun:stun.l.google.com:19302'],
        'username': 'test_user',
        'credential': 'test_password',
      };
      final model = IceServerModel.fromJson(json);
      expect(model.urls, contains('stun:stun.l.google.com:19302'));
      expect(model.username, 'test_user');
      expect(model.credential, 'test_password');

      final map = model.toMap();
      expect(map['urls'], equals(['stun:stun.l.google.com:19302']));
      expect(map['username'], 'test_user');
      expect(map['credential'], 'test_password');
    });
  });

  group('VoipCallSession', () {
    test('parses session json and computes isOutgoing accurately', () {
      final json = {
        'id': 'call-123',
        'caller_id': 'user-1',
        'callee_id': 'user-2',
        'call_type': 'voice',
        'status': 'ringing',
        'offer_sdp': 'v=0...',
        'started_at': '2026-09-19T00:00:00.000Z',
        'duration_seconds': 0,
        'peer_name': 'Alice Expat',
      };

      final callerSession = VoipCallSession.fromJson(json, currentUserId: 'user-1');
      expect(callerSession.isOutgoing, isTrue);
      expect(callerSession.status, 'ringing');
      expect(callerSession.isTerminal, isFalse);

      final calleeSession = VoipCallSession.fromJson(json, currentUserId: 'user-2');
      expect(calleeSession.isOutgoing, isFalse);
      expect(calleeSession.peerName, 'Alice Expat');
    });

    test('isTerminal returns true for finished call states', () {
      for (final s in ['completed', 'declined', 'busy', 'missed', 'failed', 'timeout']) {
        final session = VoipCallSession(
          id: 'test',
          callerId: 'u1',
          calleeId: 'u2',
          status: s,
          startedAt: DateTime.now(),
        );
        expect(session.isTerminal, isTrue, reason: 'Status $s should be terminal');
      }
    });
  });

  group('VoipActiveCallState', () {
    test('isActive and isTerminal property behaviors', () {
      const callingState = VoipActiveCallState(status: 'calling');
      expect(callingState.isActive, isTrue);
      expect(callingState.isTerminal, isFalse);

      const connectedState = VoipActiveCallState(status: 'connected', durationSeconds: 12);
      expect(connectedState.isActive, isTrue);
      expect(connectedState.isTerminal, isFalse);

      const endedState = VoipActiveCallState(status: 'ended');
      expect(endedState.isActive, isFalse);
      expect(endedState.isTerminal, isTrue);
    });

    test('copyWith updates fields correctly', () {
      const initial = VoipActiveCallState(
        peerName: 'Bob',
        isMuted: false,
        isSpeaker: false,
      );

      expect(initial.isMinimized, isFalse);
      final updated = initial.copyWith(
        isMuted: true,
        isSpeaker: true,
        durationSeconds: 30,
        isMinimized: true,
      );

      expect(updated.peerName, 'Bob');
      expect(updated.isMuted, isTrue);
      expect(updated.isSpeaker, isTrue);
      expect(updated.durationSeconds, 30);
      expect(updated.isMinimized, isTrue);
    });
  });
}
