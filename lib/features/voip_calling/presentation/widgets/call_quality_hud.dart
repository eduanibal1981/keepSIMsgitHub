/// KeepSIMs — Live WebRTC Quality Diagnostics HUD
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keep_sims/features/voip_calling/data/services/webrtc_quality_collector.dart';

class CallQualityHud extends StatelessWidget {
  final CallQualitySnapshot snapshot;
  final VoidCallback? onExportReport;
  final Map<String, dynamic>? sessionReport;

  const CallQualityHud({
    super.key,
    required this.snapshot,
    this.onExportReport,
    this.sessionReport,
  });

  @override
  Widget build(BuildContext context) {
    final isRelayed = snapshot.isRelayed;
    final rtt = snapshot.currentRttMs;
    final jitter = snapshot.receiveJitterMs;
    final loss = snapshot.intervalLossPct;
    final jbDelay = snapshot.intervalJitterBufferDelayMs;

    Color rttColor = Colors.greenAccent;
    if (rtt > 200) {
      rttColor = Colors.redAccent;
    } else if (rtt > 120) {
      rttColor = Colors.amberAccent;
    }

    Color lossColor = Colors.greenAccent;
    if (loss > 5.0) {
      lossColor = Colors.redAccent;
    } else if (loss > 1.5) {
      lossColor = Colors.amberAccent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC0D131A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Transport & Codec
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRelayed
                      ? Colors.amber.withValues(alpha: 0.2)
                      : Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isRelayed ? Colors.amber : Colors.greenAccent,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRelayed ? Icons.alt_route_rounded : Icons.bolt_rounded,
                      size: 13,
                      color: isRelayed ? Colors.amber : Colors.greenAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isRelayed ? 'TURN RELAY' : 'DIRECT UDP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isRelayed ? Colors.amber : Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ),
              if (!snapshot.hasTurn) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.redAccent,
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 12,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'STUN ONLY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${snapshot.negotiatedCodec.toUpperCase()} • ${(snapshot.clockRate ?? 48000) ~/ 1000}kHz • 20ms',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onExportReport != null)
                IconButton(
                  icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white70),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Export Sanitized Report',
                  onPressed: () {
                    if (sessionReport != null) {
                      final jsonStr = const JsonEncoder.withIndent('  ').convert(sessionReport);
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Diagnostics report copied to clipboard!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                    onExportReport?.call();
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Primary Grid Metrics
          Row(
            children: [
              _metricTile(
                label: 'RTT',
                value: '${rtt.toStringAsFixed(0)} ms',
                valueColor: rttColor,
              ),
              _metricTile(
                label: 'Jitter',
                value: '${jitter.toStringAsFixed(1)} ms',
                valueColor: Colors.white,
              ),
              _metricTile(
                label: 'Loss',
                value: '${loss.toStringAsFixed(1)}%',
                valueColor: lossColor,
              ),
              _metricTile(
                label: 'NetEQ Playout',
                value: '${jbDelay.toStringAsFixed(1)} ms',
                valueColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Secondary Row: Bitrates & PLC
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tx: ${snapshot.sendBitrateKbps.toStringAsFixed(1)} kbps  •  Rx: ${snapshot.receiveBitrateKbps.toStringAsFixed(1)} kbps',
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Colors.white60,
                  ),
                ),
              ),
              Text(
                'PLC: ${snapshot.concealedSamples} smp (${snapshot.concealmentEvents} ev)',
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white38,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
