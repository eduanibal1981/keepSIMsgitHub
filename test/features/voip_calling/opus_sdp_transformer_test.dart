import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/voip_calling/data/services/opus_sdp_transformer.dart';

void main() {
  group('OpusSdpTransformer Voice Optimization Tests', () {
    const rawSdp =
        'v=0\r\n'
        'o=- 123456789 2 IN IP4 127.0.0.1\r\n'
        's=-\r\n'
        't=0 0\r\n'
        'm=audio 9 UDP/TLS/RTP/SAVPF 0 8 111 126\r\n'
        'c=IN IP4 0.0.0.0\r\n'
        'a=rtcp:9 IN IP4 0.0.0.0\r\n'
        'a=rtpmap:0 PCMU/8000\r\n'
        'a=rtpmap:8 PCMA/8000\r\n'
        'a=rtpmap:111 opus/48000/2\r\n'
        'a=fmtp:111 minptime=10;useinbandfec=1\r\n'
        'a=rtpmap:126 telephone-event/8000\r\n';

    test('Prioritizes Opus payload type first in audio m-line', () {
      final optimized = OpusSdpTransformer.optimizeOpusVoiceProfile(rawSdp);
      expect(
        optimized.contains('m=audio 9 UDP/TLS/RTP/SAVPF 111 0 8 126'),
        isTrue,
        reason: 'Opus (111) must be moved to the front of the payload list',
      );
    });

    test('Injects ptime=20, maxptime=40, inbandfec, dtx, and 32kbps bitrate', () {
      final optimized = OpusSdpTransformer.optimizeOpusVoiceProfile(rawSdp);

      // Verify explicit ptime lines
      expect(optimized.contains('a=ptime:20'), isTrue);
      expect(optimized.contains('a=maxptime:40'), isTrue);

      // Verify fmtp parameter injection
      expect(optimized.contains('useinbandfec=1'), isTrue);
      expect(optimized.contains('usedtx=1'), isTrue);
      expect(optimized.contains('stereo=0'), isTrue);
      expect(optimized.contains('sprop-stereo=0'), isTrue);
      expect(optimized.contains('maxaveragebitrate=32000'), isTrue);
    });

    test('Transformation is strictly idempotent', () {
      final firstPass = OpusSdpTransformer.optimizeOpusVoiceProfile(rawSdp);
      final secondPass = OpusSdpTransformer.optimizeOpusVoiceProfile(firstPass);

      expect(secondPass, equals(firstPass));

      // Verify no duplicate keys
      final fmtpMatches = RegExp(r'a=fmtp:111.*').allMatches(secondPass);
      expect(fmtpMatches.length, equals(1));
    });

    test('Preserves SDP without Opus intact', () {
      const pcmuOnlySdp =
          'v=0\r\n'
          'm=audio 9 UDP/TLS/RTP/SAVPF 0\r\n'
          'a=rtpmap:0 PCMU/8000\r\n';

      final result = OpusSdpTransformer.optimizeOpusVoiceProfile(pcmuOnlySdp);
      expect(result, equals(pcmuOnlySdp));
    });

    test('RFC 7587: Does not inject ptime or maxptime inside fmtp line', () {
      final optimized = OpusSdpTransformer.optimizeOpusVoiceProfile(rawSdp);
      final fmtpLine = optimized.split('\r\n').firstWhere((l) => l.startsWith('a=fmtp:111'));

      // RFC 7587 dictates ptime/maxptime belong as media attributes, NOT fmtp parameters
      // Note: check with boundary so 'minptime' does not match 'ptime='
      expect(RegExp(r'(^|[; ])ptime=').hasMatch(fmtpLine), isFalse);
      expect(RegExp(r'(^|[; ])maxptime=').hasMatch(fmtpLine), isFalse);
      expect(fmtpLine.contains('minptime=10'), isTrue);
    });

    test('Decoupled injection: inserts a=maxptime:40 when a=ptime:20 already exists', () {
      const sdpWithPtimeOnly =
          'v=0\r\n'
          'm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n'
          'a=ptime:20\r\n'
          'a=rtpmap:111 opus/48000/2\r\n'
          'a=fmtp:111 minptime=10;ptime=20;maxptime=40\r\n';

      final optimized = OpusSdpTransformer.optimizeOpusVoiceProfile(sdpWithPtimeOnly);

      expect(optimized.contains('a=ptime:20'), isTrue);
      expect(optimized.contains('a=maxptime:40'), isTrue);

      final fmtpLine = optimized.split('\r\n').firstWhere((l) => l.startsWith('a=fmtp:111'));
      expect(RegExp(r'(^|[; ])ptime=').hasMatch(fmtpLine), isFalse);
      expect(RegExp(r'(^|[; ])maxptime=').hasMatch(fmtpLine), isFalse);
    });
  });
}
