/// KeepSIMs — Opus SDP Codec Optimizer
library;

/// Pure utility to optimize WebRTC SDP for high-fidelity, low-latency Opus voice calling
class OpusSdpTransformer {
  /// Transform an SDP offer or answer to configure the WhatsApp-grade Opus voice profile:
  /// - 20ms frame packetization (ptime=20, maxptime=40)
  /// - In-band Forward Error Correction (useinbandfec=1)
  /// - Discontinuous Transmission (usedtx=1)
  /// - Mono encoding (stereo=0, sprop-stereo=0)
  /// - 32 kbps baseline speech target (maxaveragebitrate=32000)
  /// - Prioritize Opus payload type first in audio m-line
  static String optimizeOpusVoiceProfile(
    String sdp, {
    int ptime = 20,
    int maxptime = 40,
    int maxAverageBitrate = 32000,
    bool enableFec = true,
    bool enableDtx = true,
  }) {
    if (sdp.isEmpty) return sdp;

    final lines = sdp.split('\r\n');
    final isCrlf = lines.length > 1;
    final workingLines = isCrlf ? lines : sdp.split('\n');

    // 1. Identify Opus payload type from rtpmap
    String? opusPt;
    for (final line in workingLines) {
      final match = RegExp(r'^a=rtpmap:(\d+)\s+opus/48000/2', caseSensitive: false).firstMatch(line);
      if (match != null) {
        opusPt = match.group(1);
        break;
      }
    }

    if (opusPt == null) {
      // No Opus codec found in SDP, return unchanged
      return sdp;
    }

    final resultLines = <String>[];
    bool inAudioSection = false;
    bool fmtpModified = false;
    bool hasPtimeLine = false;
    bool hasMaxptimeLine = false;

    for (int i = 0; i < workingLines.length; i++) {
      final line = workingLines[i];

      // Detect m-lines
      if (line.startsWith('m=audio ')) {
        inAudioSection = true;
        // Prioritize Opus payload type first in the m=audio line
        final parts = line.split(' ');
        if (parts.length > 3) {
          final prefix = parts.sublist(0, 3);
          final payloads = parts.sublist(3);
          if (payloads.contains(opusPt)) {
            payloads.remove(opusPt);
            payloads.insert(0, opusPt);
            resultLines.add('${prefix.join(' ')} ${payloads.join(' ')}');
            continue;
          }
        }
        resultLines.add(line);
        continue;
      } else if (line.startsWith('m=')) {
        // Entering a non-audio media section (e.g. video/application)
        inAudioSection = false;
      }

      if (inAudioSection) {
        // Check for existing ptime / maxptime lines
        if (line.startsWith('a=ptime:')) {
          hasPtimeLine = true;
          resultLines.add('a=ptime:$ptime');
          continue;
        }
        if (line.startsWith('a=maxptime:')) {
          hasMaxptimeLine = true;
          resultLines.add('a=maxptime:$maxptime');
          continue;
        }

        // Check for Opus fmtp line
        if (line.startsWith('a=fmtp:$opusPt')) {
          fmtpModified = true;
          resultLines.add(_buildOpusFmtpLine(
            opusPt,
            existingLine: line,
            maxAverageBitrate: maxAverageBitrate,
            enableFec: enableFec,
            enableDtx: enableDtx,
          ));
          continue;
        }
      }

      resultLines.add(line);
    }

    // If fmtp was missing under audio section, inject it right after rtpmap
    if (!fmtpModified) {
      for (int i = 0; i < resultLines.length; i++) {
        if (resultLines[i].startsWith('a=rtpmap:$opusPt')) {
          resultLines.insert(
            i + 1,
            _buildOpusFmtpLine(
              opusPt,
              existingLine: null,
              maxAverageBitrate: maxAverageBitrate,
              enableFec: enableFec,
              enableDtx: enableDtx,
            ),
          );
          break;
        }
      }
    }

    // Decoupled insertion of missing a=ptime / a=maxptime attributes under m=audio
    if (!hasPtimeLine || !hasMaxptimeLine) {
      int audioIndex = -1;
      for (int i = 0; i < resultLines.length; i++) {
        if (resultLines[i].startsWith('m=audio ')) {
          audioIndex = i;
          break;
        }
      }

      if (audioIndex != -1) {
        int insertOffset = 1;
        if (!hasPtimeLine) {
          resultLines.insert(audioIndex + insertOffset, 'a=ptime:$ptime');
          insertOffset++;
        }
        if (!hasMaxptimeLine) {
          resultLines.insert(audioIndex + insertOffset, 'a=maxptime:$maxptime');
          insertOffset++;
        }
      }
    }

    final delimiter = isCrlf ? '\r\n' : '\n';
    return resultLines.join(delimiter);
  }

  static String _buildOpusFmtpLine(
    String pt, {
    String? existingLine,
    required int maxAverageBitrate,
    required bool enableFec,
    required bool enableDtx,
  }) {
    final params = <String, String>{};

    if (existingLine != null) {
      final colonIndex = existingLine.indexOf(' ');
      if (colonIndex != -1) {
        final paramString = existingLine.substring(colonIndex + 1);
        for (final pair in paramString.split(';')) {
          final kv = pair.trim().split('=');
          if (kv.length == 2) {
            params[kv[0].trim()] = kv[1].trim();
          }
        }
      }
    }

    // RFC 7587: ptime and maxptime belong only as standalone SDP media attributes
    // (a=ptime:20 and a=maxptime:40), NOT in the fmtp line.
    params.remove('ptime');
    params.remove('maxptime');

    // Force voice optimization parameters per RFC 7587
    params['minptime'] = '10';
    params['useinbandfec'] = enableFec ? '1' : '0';
    params['usedtx'] = enableDtx ? '1' : '0';
    params['stereo'] = '0';
    params['sprop-stereo'] = '0';
    params['maxaveragebitrate'] = maxAverageBitrate.toString();

    final paramList = params.entries.map((e) => '${e.key}=${e.value}').join(';');
    return 'a=fmtp:$pt $paramList';
  }
}
