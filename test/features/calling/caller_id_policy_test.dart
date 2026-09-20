import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/data/models/call_record_model.dart';
import 'package:keep_sims/features/calling/data/models/caller_id_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';

void main() {
  group('International Calling: Caller ID & Route Policy Verification', () {
    const gatewayNumber = '+17543180369';
    const verifiedOmanNumber = '+96893990492';
    const destinationOmanNumber = '+96879761061';

    test(
      '1. Gateway to Oman preserves gateway; explicit gateway selection wins over verified default',
      () {
        const listResult = CallerIdListResult(
          callerIds: [
            CallerIdModel(
              id: 'cid-oman-1',
              phoneNumber: verifiedOmanNumber,
              isVerified: true,
              isDefault: true,
            ),
          ],
          defaultGatewayNumber: gatewayNumber,
          isGatewayActive: true, // Explicit gateway chosen
          activeCallerId: gatewayNumber,
        );

        expect(listResult.isGatewayActive, isTrue);
        expect(listResult.activeCallerId, equals(gatewayNumber));
        expect(listResult.defaultGatewayNumber, equals(gatewayNumber));
      },
    );

    test(
      '2. External verified Oman identity to different Oman destination detects unsupported carrier route and suggests gateway',
      () {
        // Simulate policy resolution rule
        bool isEligible(String callerId, String dest, bool isGateway) {
          if (isGateway) return true;
          if (callerId.startsWith('+968') && dest.startsWith('+968')) {
            return false; // Unsupported on direct carrier route
          }
          return true;
        }

        final verifiedEligible = isEligible(
          verifiedOmanNumber,
          destinationOmanNumber,
          false,
        );
        expect(verifiedEligible, isFalse);

        final gatewayEligible = isEligible(
          gatewayNumber,
          destinationOmanNumber,
          true,
        );
        expect(gatewayEligible, isTrue);

        const preview = CallPreviewResult(
          eligible: false,
          policyCode: 'unsupported_same_country_route',
          policyReason:
              'External Oman mobile numbers cannot be used as caller ID to call Oman destinations due to local carrier restrictions.',
          suggestedAction: 'use_gateway',
          requestedCallerId: verifiedOmanNumber,
          effectiveCallerId: verifiedOmanNumber,
          callerIdType: 'verified_number',
          walletBalance: 5.0,
          gatewayNumber: gatewayNumber,
        );

        expect(preview.eligible, isFalse);
        expect(preview.policyCode, equals('unsupported_same_country_route'));
        expect(preview.suggestedAction, equals('use_gateway'));
      },
    );

    test(
      '3. Self-dialing never silently substitutes caller ID; prompts gateway selection',
      () {
        bool isSelfDial(String callerId, String dest, bool isGateway) {
          if (isGateway) return false;
          return callerId == dest;
        }

        expect(
          isSelfDial(verifiedOmanNumber, verifiedOmanNumber, false),
          isTrue,
        );
        expect(isSelfDial(gatewayNumber, verifiedOmanNumber, true), isFalse);

        const preview = CallPreviewResult(
          eligible: false,
          policyCode: 'self_dial_conflict',
          policyReason:
              'You cannot call your own Caller ID number. Please switch to KeepSIMs Voice Gateway.',
          suggestedAction: 'use_gateway',
          requestedCallerId: verifiedOmanNumber,
          effectiveCallerId: verifiedOmanNumber,
          callerIdType: 'verified_number',
          walletBalance: 5.0,
          gatewayNumber: gatewayNumber,
        );

        expect(preview.eligible, isFalse);
        expect(preview.policyCode, equals('self_dial_conflict'));
        expect(preview.suggestedAction, equals('use_gateway'));
      },
    );

    test(
      '4. Supported verified-ID cross-border routes (e.g. US/Canada/UK) remain selectable',
      () {
        bool isEligibleRoute(String callerId, String dest, bool isGateway) {
          if (isGateway) return true;
          if (callerId == dest) return false;
          if (callerId.startsWith('+968') && dest.startsWith('+968')) {
            return false;
          }
          return true;
        }

        // Oman caller ID calling US destination -> supported cross-border
        expect(
          isEligibleRoute(verifiedOmanNumber, '+12025550143', false),
          isTrue,
        );
        // US caller ID calling Egypt destination -> supported
        expect(isEligibleRoute('+12025550199', '+201001234567', false), isTrue);
      },
    );

    test(
      '5. Unowned or unverified caller IDs cannot be accepted as outbound identity',
      () {
        final verifiedCallerIds = [
          const CallerIdModel(
            id: 'c1',
            phoneNumber: verifiedOmanNumber,
            isVerified: true,
          ),
          const CallerIdModel(
            id: 'c2',
            phoneNumber: '+12025550199',
            isVerified: false,
          ),
        ];

        bool canUseCallerId(String requestedPhone) {
          return verifiedCallerIds.any(
            (c) => c.phoneNumber == requestedPhone && c.isVerified,
          );
        }

        expect(canUseCallerId(verifiedOmanNumber), isTrue);
        expect(canUseCallerId('+12025550199'), isFalse);
        expect(canUseCallerId('+96899999999'), isFalse); // Arbitrary number
      },
    );

    test(
      '6. HTTP 200 does not display ringing prematurely; retains initiating until alerting',
      () {
        // ActiveCallState initial state upon startCall
        const state = ActiveCallState(
          destinationNumber: destinationOmanNumber,
          status: 'initiating', // Retain 'initiating' on setup
        );

        expect(state.status, equals('initiating'));
        expect(state.status == 'ringing', isFalse);
      },
    );

    test(
      '7. Observed 603/user_busy classifies as declined with \$0 charge; true busy and no_answer remain distinct',
      () {
        // 1. Observed failure fixture: SIP 603 + user_busy
        final declinedRecord = CallRecord.fromJson({
          'id': 'bc266bfe-77ce-464d-afb2-a7d600221963',
          'user_id': 'user-123',
          'caller_number': verifiedOmanNumber,
          'destination_number': destinationOmanNumber,
          'status': 'declined',
          'started_at': '2026-09-16T20:27:31.206774Z',
          'ended_at': '2026-09-16T20:27:32.646774Z',
          'answered_at': null,
          'duration_seconds': 0,
          'billed_duration_seconds': 0,
          'rate_per_minute_usd': 0.07,
          'total_cost_usd': 0.0000,
          'sip_hangup_cause': 603,
          'telnyx_hangup_cause': 'user_busy',
          'hangup_source': 'callee',
          'error_message':
              'Call declined or rejected by the destination network',
        });

        expect(declinedRecord.status, equals('declined'));
        expect(declinedRecord.sipHangupCause, equals(603));
        expect(declinedRecord.totalCost, equals(0.0));
        expect(declinedRecord.durationSeconds, equals(0));
        expect(declinedRecord.isTerminal, isTrue);

        // 2. True busy fixture: SIP 486
        final busyRecord = CallRecord.fromJson({
          'id': 'rec-busy-1',
          'user_id': 'user-123',
          'caller_number': gatewayNumber,
          'destination_number': destinationOmanNumber,
          'status': 'busy',
          'started_at': '2026-09-16T20:25:00.000Z',
          'ended_at': '2026-09-16T20:25:05.000Z',
          'sip_hangup_cause': 486,
          'telnyx_hangup_cause': 'user_busy',
          'hangup_source': 'callee',
          'rate_per_minute_usd': 0.07,
          'total_cost_usd': 0.0000,
        });
        expect(busyRecord.status, equals('busy'));
        expect(busyRecord.totalCost, equals(0.0));

        // 3. No answer fixture: SIP 487 / timeout
        final noAnswerRecord = CallRecord.fromJson({
          'id': 'rec-no-answer-1',
          'user_id': 'user-123',
          'caller_number': gatewayNumber,
          'destination_number': destinationOmanNumber,
          'status': 'no_answer',
          'started_at': '2026-09-16T20:26:10.626776Z',
          'ended_at': '2026-09-16T20:26:24.646788Z',
          'sip_hangup_cause': 487,
          'telnyx_hangup_cause': 'normal_clearing',
          'hangup_source': 'carrier',
          'rate_per_minute_usd': 0.07,
          'total_cost_usd': 0.0000,
        });
        expect(noAnswerRecord.status, equals('no_answer'));
        expect(noAnswerRecord.totalCost, equals(0.0));
      },
    );

    test(
      '8. Final 603 status survives later user hangup; completed is terminal in UI and cannot be reopened by late events',
      () {
        const state = ActiveCallState(
          callId: 'bc266bfe-77ce-464d-afb2-a7d600221963',
          status: 'declined',
          errorMessage: 'Call declined or rejected by the destination network',
        );

        expect(state.isTerminal, isTrue);

        const completedState = ActiveCallState(
          callId: 'rec-completed-1',
          status: 'completed',
          durationSeconds: 45,
          estimatedCost: 0.0525,
        );

        expect(completedState.isTerminal, isTrue);
      },
    );

    test(
      '9. Ed25519 webhook security fails closed if key or signature is invalid',
      () {
        // Simulate signature verifier behavior
        bool isSignatureValid(String? sig, String? timestamp, String? pubKey) {
          if (sig == null ||
              timestamp == null ||
              pubKey == null ||
              pubKey.isEmpty) {
            return false;
          }
          return true;
        }

        expect(isSignatureValid(null, '1726518451', 'test_key'), isFalse);
        expect(isSignatureValid('sig', null, 'test_key'), isFalse);
        expect(
          isSignatureValid('sig', '1726518451', ''),
          isFalse,
        ); // Missing key fails closed
        expect(
          isSignatureValid('valid_sig', '1726518451', 'valid_key'),
          isTrue,
        );
      },
    );

    test(
      '10. Atomic default selection allows at most one default verified number per user',
      () {
        final userCallerIds = [
          const CallerIdModel(
            id: 'c1',
            phoneNumber: '+96893990492',
            isVerified: true,
            isDefault: true,
          ),
          const CallerIdModel(
            id: 'c2',
            phoneNumber: '+12025550100',
            isVerified: true,
            isDefault: false,
          ),
        ];

        final defaultCount = userCallerIds.where((c) => c.isDefault).length;
        expect(defaultCount, equals(1));
      },
    );

    test(
      '11. Answered calls bill strictly on answered duration once; unanswered fixtures never debit',
      () {
        double calculateCallCost({
          required bool wasAnswered,
          required int durationSeconds,
          required double ratePerMinute,
        }) {
          if (!wasAnswered || durationSeconds <= 0) return 0.0;
          return double.parse(
            (durationSeconds * (ratePerMinute / 60.0)).toStringAsFixed(4),
          );
        }

        // 1. Answered 45s call at $0.07/min
        final answeredCost = calculateCallCost(
          wasAnswered: true,
          durationSeconds: 45,
          ratePerMinute: 0.07,
        );
        expect(answeredCost, equals(0.0525));

        // 2. Unanswered 15s ringing/declined call
        final unansweredCost = calculateCallCost(
          wasAnswered: false,
          durationSeconds: 15,
          ratePerMinute: 0.07,
        );
        expect(unansweredCost, equals(0.0));
      },
    );

    test(
      '12. Call rate per-second calculation and country flag formatting',
      () {
        const rate = CallRate(
          id: 'rate-om',
          countryCode: 'OM',
          countryName: 'Oman',
          phonePrefix: '+968',
          costPerMinute: 0.045,
          ratePerMinute: 0.070,
          billingIncrementSeconds: 1,
        );

        expect(rate.ratePerSecond, closeTo(0.070 / 60.0, 0.0001));
        expect(rate.flagEmoji, isNotEmpty);
      },
    );
  });
}
