/// KeepSIMs — WebRTC Call Quality Telemetry & Statistics Collector
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Single snapshot of call quality and network transport metrics
class CallQualitySnapshot {
  final DateTime timestamp;
  final String negotiatedCodec;
  final int? clockRate;
  final int? channels;
  final String? sdpFmtpLine;

  // Transport & Candidates
  final String localCandidateType; // 'host', 'srflx', 'prflx', 'relay', 'unknown'
  final String remoteCandidateType;
  final String transportProtocol; // 'udp', 'tcp', 'tls', 'unknown'
  final bool isRelayed;
  final bool hasTurn;

  // Network Latency & Jitter
  final double currentRttMs;
  final double receiveJitterMs;

  // Bandwidth & Rates (bits per second)
  final double sendBitrateKbps;
  final double receiveBitrateKbps;

  // Packets & Loss
  final int packetsSent;
  final int packetsReceived;
  final int packetsLost;
  final double intervalLossPct;
  final double cumulativeLossPct;

  // NetEQ & Jitter Buffer
  final double intervalJitterBufferDelayMs;
  final double cumulativeJitterBufferDelayMs;
  final int concealedSamples;
  final int intervalConcealedSamples;
  final int concealmentEvents;
  final int intervalConcealmentEvents;

  // Audio Level (0.0 to 1.0)
  final double audioLevel;

  const CallQualitySnapshot({
    required this.timestamp,
    this.negotiatedCodec = 'opus',
    this.clockRate = 48000,
    this.channels = 1,
    this.sdpFmtpLine,
    this.localCandidateType = 'unknown',
    this.remoteCandidateType = 'unknown',
    this.transportProtocol = 'udp',
    this.isRelayed = false,
    this.hasTurn = true,
    this.currentRttMs = 0.0,
    this.receiveJitterMs = 0.0,
    this.sendBitrateKbps = 0.0,
    this.receiveBitrateKbps = 0.0,
    this.packetsSent = 0,
    this.packetsReceived = 0,
    this.packetsLost = 0,
    this.intervalLossPct = 0.0,
    this.cumulativeLossPct = 0.0,
    this.intervalJitterBufferDelayMs = 0.0,
    this.cumulativeJitterBufferDelayMs = 0.0,
    this.concealedSamples = 0,
    this.intervalConcealedSamples = 0,
    this.concealmentEvents = 0,
    this.intervalConcealmentEvents = 0,
    this.audioLevel = 0.0,
  });

  Map<String, dynamic> toSanitizedMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'codec': {
        'name': negotiatedCodec,
        'clock_rate': clockRate,
        'channels': channels,
        'fmtp': sdpFmtpLine,
      },
      'transport': {
        'is_relayed': isRelayed,
        'has_turn': hasTurn,
        'protocol': transportProtocol,
        'local_type': localCandidateType,
        'remote_type': remoteCandidateType,
      },
      'metrics': {
        'rtt_ms': double.parse(currentRttMs.toStringAsFixed(1)),
        'jitter_ms': double.parse(receiveJitterMs.toStringAsFixed(1)),
        'send_kbps': double.parse(sendBitrateKbps.toStringAsFixed(1)),
        'recv_kbps': double.parse(receiveBitrateKbps.toStringAsFixed(1)),
        'interval_loss_pct': double.parse(intervalLossPct.toStringAsFixed(2)),
        'cumulative_loss_pct': double.parse(cumulativeLossPct.toStringAsFixed(2)),
        'jitter_buffer_delay_ms': double.parse(
          intervalJitterBufferDelayMs.toStringAsFixed(1),
        ),
        'concealed_samples': concealedSamples,
        'concealment_events': concealmentEvents,
        'audio_level': double.parse(audioLevel.toStringAsFixed(2)),
      },
    };
  }
}

/// Internal state tracker for counter deltas
class _StatsBaseline {
  double timestampMs = 0;
  int bytesSent = 0;
  int bytesReceived = 0;
  int packetsSent = 0;
  int packetsReceived = 0;
  int packetsLost = 0;
  int inboundSsrc = 0;
  int outboundSsrc = 0;
  double jitterBufferDelay = 0;
  int jitterBufferEmittedCount = 0;
  int concealedSamples = 0;
  int concealmentEvents = 0;
}

/// Lightweight, periodic WebRTC statistics collector
class WebRTCQualityCollector {
  final Duration sampleInterval;
  Timer? _pollingTimer;
  RTCPeerConnection? _peerConnection;

  final _baseline = _StatsBaseline();
  final _snapshots = <CallQualitySnapshot>[];
  final _controller = StreamController<CallQualitySnapshot>.broadcast();

  bool _isCollecting = false;
  bool _hasTurnServers = true;
  CallQualitySnapshot _latestSnapshot = CallQualitySnapshot(
    timestamp: DateTime.now(),
  );

  WebRTCQualityCollector({
    this.sampleInterval = const Duration(milliseconds: 1000),
  });

  Stream<CallQualitySnapshot> get snapshotStream => _controller.stream;
  CallQualitySnapshot get latestSnapshot => _latestSnapshot;
  List<CallQualitySnapshot> get sessionSnapshots => List.unmodifiable(_snapshots);
  bool get isCollecting => _isCollecting;
  bool get hasTurnServers => _hasTurnServers;

  /// Update whether TURN relay servers are provisioned for this session
  void setHasTurnServers(bool value) {
    _hasTurnServers = value;
  }

  /// Start periodic sampling of peer connection stats
  void start(RTCPeerConnection peerConnection) {
    stop();
    _peerConnection = peerConnection;
    _isCollecting = true;
    _snapshots.clear();
    _resetBaseline();

    _pollingTimer = Timer.periodic(sampleInterval, (_) async {
      await collectOnce();
    });
  }

  /// Reset internal baseline counters (e.g. on ICE restart or new connection)
  void resetBaseline() {
    _resetBaseline();
  }

  void _resetBaseline() {
    _baseline.timestampMs = 0;
    _baseline.bytesSent = 0;
    _baseline.bytesReceived = 0;
    _baseline.packetsSent = 0;
    _baseline.packetsReceived = 0;
    _baseline.packetsLost = 0;
    _baseline.inboundSsrc = 0;
    _baseline.outboundSsrc = 0;
    _baseline.jitterBufferDelay = 0;
    _baseline.jitterBufferEmittedCount = 0;
    _baseline.concealedSamples = 0;
    _baseline.concealmentEvents = 0;
  }

  /// Process a single collection round from WebRTC StatsReports
  Future<CallQualitySnapshot?> collectOnce() async {
    final pc = _peerConnection;
    if (pc == null || !_isCollecting) return null;

    try {
      final reports = await pc.getStats();
      final snapshot = parseStatsReports(reports, DateTime.now());
      if (snapshot != null) {
        _latestSnapshot = snapshot;
        _snapshots.add(snapshot);
        if (_controller.hasListener && !_controller.isClosed) {
          _controller.add(snapshot);
        }
      }
      return snapshot;
    } catch (e) {
      debugPrint('[QualityCollector] Error reading stats: $e');
      return null;
    }
  }

  /// Pure parser that calculates deltas from a list of StatsReport items
  CallQualitySnapshot? parseStatsReports(
    List<StatsReport> reports,
    DateTime now,
  ) {
    if (reports.isEmpty) return null;

    // Lookup tables by id and type
    final reportsById = <String, StatsReport>{};
    StatsReport? inboundRtp;
    StatsReport? outboundRtp;
    StatsReport? remoteInboundRtp;
    StatsReport? selectedCandidatePair;
    final codecs = <String, StatsReport>{};
    final candidates = <String, StatsReport>{};

    for (final report in reports) {
      reportsById[report.id] = report;
      final type = report.type;

      if (type == 'inbound-rtp' && report.values['kind'] == 'audio') {
        inboundRtp = report;
      } else if (type == 'outbound-rtp' && report.values['kind'] == 'audio') {
        outboundRtp = report;
      } else if (type == 'remote-inbound-rtp' && report.values['kind'] == 'audio') {
        remoteInboundRtp = report;
      } else if (type == 'candidate-pair') {
        final state = report.values['state'];
        final nominated = report.values['nominated'];
        if (nominated == true || nominated == 'true' || state == 'succeeded') {
          selectedCandidatePair = report;
        }
      } else if (type == 'codec') {
        codecs[report.id] = report;
      } else if (type == 'local-candidate' || type == 'remote-candidate') {
        candidates[report.id] = report;
      }
    }

    final currentTimestampMs = now.millisecondsSinceEpoch.toDouble();
    final double deltaSec;
    if (_baseline.timestampMs > 0 && currentTimestampMs > _baseline.timestampMs) {
      deltaSec = (currentTimestampMs - _baseline.timestampMs) / 1000.0;
    } else {
      deltaSec = sampleInterval.inMilliseconds / 1000.0;
    }

    // 1. Inbound Audio Metrics (Receive)
    int currentPacketsRecv = 0;
    int currentPacketsLost = 0;
    int currentBytesRecv = 0;
    double currentJitterMs = 0;
    int currentInboundSsrc = 0;
    double currentJbDelaySec = 0;
    int currentJbEmitted = 0;
    int currentConcealedSamples = 0;
    int currentConcealmentEvents = 0;
    double currentAudioLevel = 0;
    String codecId = '';

    if (inboundRtp != null) {
      final v = inboundRtp.values;
      currentPacketsRecv = _asInt(v['packetsReceived']);
      currentPacketsLost = _asInt(v['packetsLost']);
      currentBytesRecv = _asInt(v['bytesReceived']);
      currentJitterMs = _asDouble(v['jitter']) * 1000.0; // WebRTC standard reports jitter in seconds
      currentInboundSsrc = _asInt(v['ssrc']);
      currentJbDelaySec = _asDouble(v['jitterBufferDelay']);
      currentJbEmitted = _asInt(v['jitterBufferEmittedCount']);
      currentConcealedSamples = _asInt(v['concealedSamples']);
      currentConcealmentEvents = _asInt(v['concealmentEvents']);
      currentAudioLevel = _asDouble(v['audioLevel']);
      codecId = v['codecId']?.toString() ?? '';
    }

    // 2. Outbound Audio Metrics (Send)
    int currentPacketsSent = 0;
    int currentBytesSent = 0;
    int currentOutboundSsrc = 0;

    if (outboundRtp != null) {
      final v = outboundRtp.values;
      currentPacketsSent = _asInt(v['packetsSent']);
      currentBytesSent = _asInt(v['bytesSent']);
      currentOutboundSsrc = _asInt(v['ssrc']);
    }

    // 3. SSRC Changes or Counter Resets: if counters decreased or SSRC changed, re-anchor baseline
    final bool ssrcChanged =
        (_baseline.inboundSsrc != 0 && _baseline.inboundSsrc != currentInboundSsrc) ||
        (_baseline.outboundSsrc != 0 && _baseline.outboundSsrc != currentOutboundSsrc);

    final bool counterReset =
        currentBytesSent < _baseline.bytesSent ||
        currentBytesRecv < _baseline.bytesReceived ||
        currentPacketsRecv < _baseline.packetsReceived;

    if (ssrcChanged || counterReset || _baseline.timestampMs == 0) {
      _baseline.timestampMs = currentTimestampMs;
      _baseline.bytesSent = currentBytesSent;
      _baseline.bytesReceived = currentBytesRecv;
      _baseline.packetsSent = currentPacketsSent;
      _baseline.packetsReceived = currentPacketsRecv;
      _baseline.packetsLost = currentPacketsLost;
      _baseline.inboundSsrc = currentInboundSsrc;
      _baseline.outboundSsrc = currentOutboundSsrc;
      _baseline.jitterBufferDelay = currentJbDelaySec;
      _baseline.jitterBufferEmittedCount = currentJbEmitted;
      _baseline.concealedSamples = currentConcealedSamples;
      _baseline.concealmentEvents = currentConcealmentEvents;
    }

    // Delta calculations
    final deltaBytesSent = currentBytesSent - _baseline.bytesSent;
    final deltaBytesRecv = currentBytesRecv - _baseline.bytesReceived;
    final deltaPacketsRecv = currentPacketsRecv - _baseline.packetsReceived;
    final deltaPacketsLost = currentPacketsLost - _baseline.packetsLost;
    final deltaJbDelay = currentJbDelaySec - _baseline.jitterBufferDelay;
    final deltaJbEmitted = currentJbEmitted - _baseline.jitterBufferEmittedCount;
    final deltaConcealed = currentConcealedSamples - _baseline.concealedSamples;
    final deltaConcealmentEvents = currentConcealmentEvents - _baseline.concealmentEvents;

    // Rates in kbps
    final double sendKbps = deltaSec > 0 && deltaBytesSent >= 0
        ? (deltaBytesSent * 8.0) / (deltaSec * 1000.0)
        : 0.0;
    final double recvKbps = deltaSec > 0 && deltaBytesRecv >= 0
        ? (deltaBytesRecv * 8.0) / (deltaSec * 1000.0)
        : 0.0;

    // Loss percentages (Interval & Cumulative)
    double intervalLoss = 0.0;
    if (deltaPacketsLost >= 0 && deltaPacketsRecv >= 0) {
      final totalInterval = deltaPacketsLost + deltaPacketsRecv;
      if (totalInterval > 0) {
        intervalLoss = (deltaPacketsLost / totalInterval) * 100.0;
      }
    }

    double cumulativeLoss = 0.0;
    if (currentPacketsLost >= 0 && currentPacketsRecv >= 0) {
      final totalCumulative = currentPacketsLost + currentPacketsRecv;
      if (totalCumulative > 0) {
        cumulativeLoss = (currentPacketsLost / totalCumulative) * 100.0;
      }
    }

    // Jitter Buffer Delay in ms
    double intervalJbDelayMs = 0.0;
    if (deltaJbEmitted > 0 && deltaJbDelay >= 0) {
      intervalJbDelayMs = (deltaJbDelay / deltaJbEmitted) * 1000.0;
    }
    double cumulativeJbDelayMs = 0.0;
    if (currentJbEmitted > 0 && currentJbDelaySec >= 0) {
      cumulativeJbDelayMs = (currentJbDelaySec / currentJbEmitted) * 1000.0;
    }

    // 4. Candidate Pair & RTT
    double currentRttMs = 0.0;
    String localCandType = 'unknown';
    String remoteCandType = 'unknown';
    String protocol = 'udp';
    bool isRelayed = false;

    if (selectedCandidatePair != null) {
      final v = selectedCandidatePair.values;
      final rawRtt = _asDouble(v['currentRoundTripTime']);
      currentRttMs = rawRtt > 0 ? rawRtt * 1000.0 : 0.0;

      final localCandId = v['localCandidateId']?.toString();
      final remoteCandId = v['remoteCandidateId']?.toString();

      if (localCandId != null && candidates.containsKey(localCandId)) {
        final cand = candidates[localCandId]!;
        localCandType = cand.values['candidateType']?.toString() ?? 'unknown';
        protocol = cand.values['protocol']?.toString() ?? 'udp';
      }
      if (remoteCandId != null && candidates.containsKey(remoteCandId)) {
        final cand = candidates[remoteCandId]!;
        remoteCandType = cand.values['candidateType']?.toString() ?? 'unknown';
      }

      isRelayed = localCandType.toLowerCase() == 'relay' ||
          remoteCandType.toLowerCase() == 'relay';
    }

    // Fallback RTT from remote-inbound-rtp if candidate pair did not expose it
    if (currentRttMs == 0.0 && remoteInboundRtp != null) {
      final rtt = _asDouble(remoteInboundRtp.values['roundTripTime']);
      if (rtt > 0) currentRttMs = rtt * 1000.0;
    }

    // 5. Codec Info
    String codecName = 'opus';
    int clockRate = 48000;
    int channels = 1;
    String? fmtp;

    if (codecId.isNotEmpty && codecs.containsKey(codecId)) {
      final c = codecs[codecId]!;
      final mime = c.values['mimeType']?.toString() ?? '';
      if (mime.isNotEmpty) {
        codecName = mime.replaceFirst(RegExp(r'^audio/'), '');
      }
      clockRate = _asInt(c.values['clockRate'], fallback: 48000);
      channels = _asInt(c.values['channels'], fallback: 1);
      fmtp = c.values['sdpFmtpLine']?.toString();
    }

    // Update baseline state for next tick
    _baseline.timestampMs = currentTimestampMs;
    _baseline.bytesSent = currentBytesSent;
    _baseline.bytesReceived = currentBytesRecv;
    _baseline.packetsSent = currentPacketsSent;
    _baseline.packetsReceived = currentPacketsRecv;
    _baseline.packetsLost = currentPacketsLost;
    _baseline.inboundSsrc = currentInboundSsrc;
    _baseline.outboundSsrc = currentOutboundSsrc;
    _baseline.jitterBufferDelay = currentJbDelaySec;
    _baseline.jitterBufferEmittedCount = currentJbEmitted;
    _baseline.concealedSamples = currentConcealedSamples;
    _baseline.concealmentEvents = currentConcealmentEvents;

    return CallQualitySnapshot(
      timestamp: now,
      negotiatedCodec: codecName,
      clockRate: clockRate,
      channels: channels,
      sdpFmtpLine: fmtp,
      localCandidateType: localCandType,
      remoteCandidateType: remoteCandType,
      transportProtocol: protocol,
      isRelayed: isRelayed,
      hasTurn: _hasTurnServers,
      currentRttMs: currentRttMs,
      receiveJitterMs: currentJitterMs,
      sendBitrateKbps: sendKbps,
      receiveBitrateKbps: recvKbps,
      packetsSent: currentPacketsSent,
      packetsReceived: currentPacketsRecv,
      packetsLost: currentPacketsLost,
      intervalLossPct: intervalLoss,
      cumulativeLossPct: cumulativeLoss,
      intervalJitterBufferDelayMs: intervalJbDelayMs,
      cumulativeJitterBufferDelayMs: cumulativeJbDelayMs,
      concealedSamples: currentConcealedSamples,
      intervalConcealedSamples: deltaConcealed >= 0 ? deltaConcealed : 0,
      concealmentEvents: currentConcealmentEvents,
      intervalConcealmentEvents:
          deltaConcealmentEvents >= 0 ? deltaConcealmentEvents : 0,
      audioLevel: currentAudioLevel,
    );
  }

  /// Record a parsed snapshot directly (useful for tests and manual sampling)
  void recordSnapshot(CallQualitySnapshot snapshot) {
    _latestSnapshot = snapshot;
    _snapshots.add(snapshot);
    if (_controller.hasListener && !_controller.isClosed) {
      _controller.add(snapshot);
    }
  }

  /// Export a clean, sanitized session summary for developer inspection or diagnostics
  Map<String, dynamic> exportSanitizedSessionReport({
    List<CallQualitySnapshot>? customSnapshots,
    String? callId,
    String? endReason,
  }) {
    final list = customSnapshots ?? _snapshots;
    if (list.isEmpty) {
      return {
        'call_id': callId ?? 'unknown',
        'end_reason': endReason ?? 'normal_hangup',
        'status': 'no_samples_collected',
        'exported_at': DateTime.now().toIso8601String(),
      };
    }

    final durationSec = list.length * (sampleInterval.inMilliseconds / 1000.0);

    // Compute distribution statistics
    final rtts = list.map((s) => s.currentRttMs).where((v) => v > 0).toList()..sort();
    final jitters = list.map((s) => s.receiveJitterMs).toList()..sort();
    final losses = list.map((s) => s.intervalLossPct).toList()..sort();
    final jbDelays = list.map((s) => s.intervalJitterBufferDelayMs).where((v) => v > 0).toList()..sort();

    final last = list.last;

    return {
      'call_id': callId ?? 'unknown',
      'end_reason': endReason ?? 'normal_hangup',
      'duration_seconds': durationSec.round(),
      'sample_count': _snapshots.length,
      'exported_at': DateTime.now().toIso8601String(),
      'negotiation': {
        'codec': last.negotiatedCodec,
        'clock_rate': last.clockRate,
        'channels': last.channels,
        'fmtp': last.sdpFmtpLine,
      },
      'transport': {
        'is_relayed': _snapshots.any((s) => s.isRelayed),
        'protocol': last.transportProtocol,
        'local_candidate_type': last.localCandidateType,
        'remote_candidate_type': last.remoteCandidateType,
      },
      'latency_rtt_ms': {
        'min': rtts.isNotEmpty ? rtts.first : 0,
        'median': _percentile(rtts, 0.50),
        'p95': _percentile(rtts, 0.95),
        'max': rtts.isNotEmpty ? rtts.last : 0,
      },
      'receive_jitter_ms': {
        'median': _percentile(jitters, 0.50),
        'p95': _percentile(jitters, 0.95),
      },
      'packet_loss_pct': {
        'cumulative': double.parse(last.cumulativeLossPct.toStringAsFixed(2)),
        'p95_interval': _percentile(losses, 0.95),
        'max_interval': losses.isNotEmpty ? losses.last : 0,
      },
      'jitter_buffer_delay_ms': {
        'median': _percentile(jbDelays, 0.50),
        'p95': _percentile(jbDelays, 0.95),
      },
      'neteq_concealment': {
        'total_concealed_samples': last.concealedSamples,
        'total_concealment_events': last.concealmentEvents,
      },
      'bandwidth': {
        'final_send_kbps': double.parse(last.sendBitrateKbps.toStringAsFixed(1)),
        'final_recv_kbps': double.parse(last.receiveBitrateKbps.toStringAsFixed(1)),
        'total_packets_sent': last.packetsSent,
        'total_packets_received': last.packetsReceived,
        'total_packets_lost': last.packetsLost,
      },
    };
  }

  double _percentile(List<double> sortedList, double p) {
    if (sortedList.isEmpty) return 0.0;
    final idx = ((sortedList.length - 1) * p).round();
    return double.parse(sortedList[idx].toStringAsFixed(1));
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _asDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Stop polling and release stream controller
  void stop() {
    _isCollecting = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _peerConnection = null;
  }

  /// Dispose collector
  void dispose() {
    stop();
    _controller.close();
  }
}
