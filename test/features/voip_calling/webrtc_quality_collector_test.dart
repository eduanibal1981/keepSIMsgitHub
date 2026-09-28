import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:keep_sims/features/voip_calling/data/services/webrtc_quality_collector.dart';

void main() {
  group('WebRTCQualityCollector Delta Engine Tests', () {
    late WebRTCQualityCollector collector;

    setUp(() {
      collector = WebRTCQualityCollector(
        sampleInterval: const Duration(milliseconds: 1000),
      );
    });

    tearDown(() {
      collector.dispose();
    });

    test('Initial sample anchors baseline without emitting artificial spikes', () {
      final now = DateTime(2026, 9, 24, 10, 0, 0);
      final initialReports = [
        StatsReport('inbound-audio', 'inbound-rtp', 1000.0, {
          'kind': 'audio',
          'ssrc': 12345,
          'bytesReceived': 10000,
          'packetsReceived': 200,
          'packetsLost': 2,
          'jitter': 0.015,
          'jitterBufferDelay': 2.0,
          'jitterBufferEmittedCount': 100,
          'concealedSamples': 50,
          'concealmentEvents': 3,
          'codecId': 'codec-opus',
        }),
        StatsReport('outbound-audio', 'outbound-rtp', 1000.0, {
          'kind': 'audio',
          'ssrc': 67890,
          'bytesSent': 12000,
          'packetsSent': 240,
        }),
        StatsReport('codec-opus', 'codec', 1000.0, {
          'mimeType': 'audio/opus',
          'clockRate': 48000,
          'channels': 1,
          'sdpFmtpLine': 'minptime=10;useinbandfec=1;usedtx=1',
        }),
      ];

      final snapshot = collector.parseStatsReports(initialReports, now);
      expect(snapshot, isNotNull);
      expect(snapshot!.negotiatedCodec, equals('opus'));
      expect(snapshot.clockRate, equals(48000));
      expect(snapshot.sendBitrateKbps, equals(0.0));
      expect(snapshot.receiveBitrateKbps, equals(0.0));
      expect(snapshot.packetsReceived, equals(200));
      expect(snapshot.packetsSent, equals(240));
    });

    test('Computes accurate rates and NetEQ deltas across consecutive ticks', () {
      final t1 = DateTime(2026, 9, 24, 10, 0, 0);
      final t2 = DateTime(2026, 9, 24, 10, 0, 1); // 1.0 second elapsed

      final r1 = [
        StatsReport('inbound-audio', 'inbound-rtp', 1000.0, {
          'kind': 'audio',
          'ssrc': 1001,
          'bytesReceived': 4000, // baseline: 4000 bytes
          'packetsReceived': 100,
          'packetsLost': 1,
          'jitter': 0.012,
          'jitterBufferDelay': 2.0,
          'jitterBufferEmittedCount': 100,
          'concealedSamples': 10,
          'concealmentEvents': 1,
          'codecId': 'c1',
        }),
        StatsReport('outbound-audio', 'outbound-rtp', 1000.0, {
          'kind': 'audio',
          'ssrc': 2001,
          'bytesSent': 5000, // baseline: 5000 bytes
          'packetsSent': 100,
        }),
        StatsReport('c1', 'codec', 1000.0, {
          'mimeType': 'audio/opus',
          'clockRate': 48000,
          'channels': 1,
        }),
      ];

      collector.parseStatsReports(r1, t1);

      // Tick 2: 1 sec later, 4000 more bytes sent (32 kbps), 3000 more bytes recv (24 kbps)
      // 50 more packets recv, 2 packets lost in interval
      // Jitter buffer emitted 50 more samples with 1.0s delay = 20ms avg delay
      final r2 = [
        StatsReport('inbound-audio', 'inbound-rtp', 2000.0, {
          'kind': 'audio',
          'ssrc': 1001,
          'bytesReceived': 7000, // +3000 bytes = 24 kbps
          'packetsReceived': 150, // +50 packets
          'packetsLost': 3, // +2 lost
          'jitter': 0.018, // 18 ms
          'jitterBufferDelay': 3.0, // +1.0 sec
          'jitterBufferEmittedCount': 150, // +50 emitted
          'concealedSamples': 25, // +15 samples
          'concealmentEvents': 3, // +2 events
          'codecId': 'c1',
        }),
        StatsReport('outbound-audio', 'outbound-rtp', 2000.0, {
          'kind': 'audio',
          'ssrc': 2001,
          'bytesSent': 9000, // +4000 bytes = 32 kbps
          'packetsSent': 150,
        }),
        StatsReport('c1', 'codec', 2000.0, {
          'mimeType': 'audio/opus',
          'clockRate': 48000,
          'channels': 1,
        }),
      ];

      final snapshot = collector.parseStatsReports(r2, t2);
      expect(snapshot, isNotNull);

      // Bitrate checks (tolerance ±0.5 kbps)
      expect(snapshot!.sendBitrateKbps, closeTo(32.0, 0.5));
      expect(snapshot.receiveBitrateKbps, closeTo(24.0, 0.5));

      // Packet loss check: 2 lost / (2 lost + 50 recv) = 2/52 = ~3.846%
      expect(snapshot.intervalLossPct, closeTo(3.84, 0.1));

      // Jitter check: 0.018 sec = 18 ms
      expect(snapshot.receiveJitterMs, closeTo(18.0, 0.1));

      // Jitter Buffer Delay: 1.0s / 50 emitted = 20 ms
      expect(snapshot.intervalJitterBufferDelayMs, closeTo(20.0, 0.1));

      // PLC Concealment check
      expect(snapshot.intervalConcealedSamples, equals(15));
      expect(snapshot.intervalConcealmentEvents, equals(2));
    });

    test('Recovers gracefully from counter reset without negative spikes', () {
      final t1 = DateTime(2026, 9, 24, 10, 0, 0);
      final t2 = DateTime(2026, 9, 24, 10, 0, 1);

      final r1 = [
        StatsReport('inbound-audio', 'inbound-rtp', 1000.0, {
          'kind': 'audio',
          'ssrc': 1001,
          'bytesReceived': 50000,
          'packetsReceived': 1000,
          'packetsLost': 10,
        }),
        StatsReport('outbound-audio', 'outbound-rtp', 1000.0, {
          'kind': 'audio',
          'ssrc': 2001,
          'bytesSent': 60000,
          'packetsSent': 1200,
        }),
      ];
      collector.parseStatsReports(r1, t1);

      // Counter reset (e.g. renegotiation or interface reset)
      final r2 = [
        StatsReport('inbound-audio', 'inbound-rtp', 2000.0, {
          'kind': 'audio',
          'ssrc': 1001,
          'bytesReceived': 500, // dropped from 50000
          'packetsReceived': 10,
          'packetsLost': 0,
        }),
        StatsReport('outbound-audio', 'outbound-rtp', 2000.0, {
          'kind': 'audio',
          'ssrc': 2001,
          'bytesSent': 600, // dropped from 60000
          'packetsSent': 12,
        }),
      ];

      final snapshot = collector.parseStatsReports(r2, t2);
      expect(snapshot, isNotNull);
      // Rates should be safely 0 rather than large negative numbers
      expect(snapshot!.sendBitrateKbps, equals(0.0));
      expect(snapshot.receiveBitrateKbps, equals(0.0));
      expect(snapshot.intervalLossPct, equals(0.0));
    });

    test('Candidate pair properly resolves relay vs direct UDP and converts RTT', () {
      final t = DateTime(2026, 9, 24, 10, 0, 0);
      final reports = [
        StatsReport('cp1', 'candidate-pair', 1000.0, {
          'state': 'succeeded',
          'nominated': true,
          'currentRoundTripTime': 0.045, // 45 ms
          'localCandidateId': 'lc1',
          'remoteCandidateId': 'rc1',
        }),
        StatsReport('lc1', 'local-candidate', 1000.0, {
          'candidateType': 'relay',
          'protocol': 'udp',
        }),
        StatsReport('rc1', 'remote-candidate', 1000.0, {
          'candidateType': 'srflx',
          'protocol': 'udp',
        }),
      ];

      final snapshot = collector.parseStatsReports(reports, t);
      expect(snapshot, isNotNull);
      expect(snapshot!.isRelayed, isTrue);
      expect(snapshot.localCandidateType, equals('relay'));
      expect(snapshot.remoteCandidateType, equals('srflx'));
      expect(snapshot.transportProtocol, equals('udp'));
      expect(snapshot.currentRttMs, closeTo(45.0, 0.1));
    });

    test('Sanitized session export preserves quality distribution and omits PII/credentials', () {
      final t1 = DateTime(2026, 9, 24, 10, 0, 0);
      final t2 = DateTime(2026, 9, 24, 10, 0, 1);

      final s1 = collector.parseStatsReports([
        StatsReport('cp1', 'candidate-pair', 1000.0, {
          'state': 'succeeded',
          'nominated': true,
          'currentRoundTripTime': 0.050, // 50 ms
          'localCandidateId': 'lc1',
          'remoteCandidateId': 'rc1',
        }),
        StatsReport('lc1', 'local-candidate', 1000.0, {
          'candidateType': 'host',
          'protocol': 'udp',
        }),
        StatsReport('rc1', 'remote-candidate', 1000.0, {
          'candidateType': 'host',
          'protocol': 'udp',
        }),
        StatsReport('inbound-audio', 'inbound-rtp', 1000.0, {
          'kind': 'audio',
          'bytesReceived': 4000,
          'packetsReceived': 50,
          'packetsLost': 0,
        }),
        StatsReport('outbound-audio', 'outbound-rtp', 1000.0, {
          'kind': 'audio',
          'bytesSent': 4000,
          'packetsSent': 50,
        }),
      ], t1);
      collector.recordSnapshot(s1!);

      final s2 = collector.parseStatsReports([
        StatsReport('cp1', 'candidate-pair', 2000.0, {
          'state': 'succeeded',
          'nominated': true,
          'currentRoundTripTime': 0.070, // 70 ms
          'localCandidateId': 'lc1',
          'remoteCandidateId': 'rc1',
        }),
        StatsReport('lc1', 'local-candidate', 2000.0, {
          'candidateType': 'host',
          'protocol': 'udp',
        }),
        StatsReport('rc1', 'remote-candidate', 2000.0, {
          'candidateType': 'host',
          'protocol': 'udp',
        }),
        StatsReport('inbound-audio', 'inbound-rtp', 2000.0, {
          'kind': 'audio',
          'bytesReceived': 8000,
          'packetsReceived': 100,
          'packetsLost': 1,
        }),
        StatsReport('outbound-audio', 'outbound-rtp', 2000.0, {
          'kind': 'audio',
          'bytesSent': 8000,
          'packetsSent': 100,
        }),
      ], t2);
      collector.recordSnapshot(s2!);

      final report = collector.exportSanitizedSessionReport(
        callId: 'test-call-123',
        endReason: 'normal_hangup',
      );

      expect(report['call_id'], equals('test-call-123'));
      expect(report['end_reason'], equals('normal_hangup'));
      expect(report['transport']['is_relayed'], isFalse);
      expect(report['transport']['protocol'], equals('udp'));

      // Check RTT metrics in report
      final rttMap = report['latency_rtt_ms'] as Map<String, dynamic>;
      expect(rttMap['min'], closeTo(50.0, 0.1));
      expect(rttMap['max'], closeTo(70.0, 0.1));

      // Check sanitization: verify no IPs, tokens, or SDP keys
      final serialized = report.toString();
      expect(serialized.contains('192.168.'), isFalse);
      expect(serialized.contains('password'), isFalse);
      expect(serialized.contains('credential'), isFalse);
      expect(serialized.contains('candidate:'), isFalse);
    });

    test('Tracks hasTurn configuration and exposes it in sanitized map', () {
      collector.setHasTurnServers(false);
      expect(collector.hasTurnServers, isFalse);

      final now = DateTime(2026, 9, 24, 12, 0, 0);
      final reports = [
        StatsReport('inbound-audio', 'inbound-rtp', 1000.0, {
          'kind': 'audio',
          'packetsReceived': 50,
          'bytesReceived': 2000,
        }),
      ];

      final snapshot = collector.parseStatsReports(reports, now);
      expect(snapshot, isNotNull);
      expect(snapshot!.hasTurn, isFalse);

      final map = snapshot.toSanitizedMap();
      expect(map['transport']['has_turn'], isFalse);
    });
  });
}
