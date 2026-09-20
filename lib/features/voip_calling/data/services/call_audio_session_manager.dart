/// KeepSIMs — Audio Session & Proximity Sensor Manager
library;

import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:proximity_sensor/proximity_sensor.dart';

class CallAudioSessionManager {
  AudioSession? _audioSession;
  StreamSubscription<dynamic>? _proximitySub;
  bool _isNear = false;
  bool _isSpeaker = false;

  void Function(bool isNear)? onProximityChanged;

  bool get isSpeaker => _isSpeaker;
  bool get isNear => _isNear;

  /// Configure hardware audio for voice communication (WhatsApp mode)
  Future<void> initialize() async {
    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
        ),
      );

      await _audioSession!.setActive(true);

      // Listen to proximity sensor on mobile devices
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        _proximitySub = ProximitySensor.events.listen((int event) {
          final near = event > 0;
          if (_isNear != near) {
            _isNear = near;
            onProximityChanged?.call(near);
            // If near ear and speaker is off, ensure earpiece is active
            if (near && !_isSpeaker) {
              setSpeakerphone(false);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[AudioSession] Init error: $e');
    }
  }

  /// Toggle speakerphone vs earpiece
  Future<void> setSpeakerphone(bool enableSpeaker) async {
    _isSpeaker = enableSpeaker;
    try {
      await Helper.setSpeakerphoneOn(enableSpeaker);
    } catch (e) {
      debugPrint('[AudioSession] Set speakerphone error: $e');
    }
  }

  /// Release audio session and stop proximity sensor
  Future<void> dispose() async {
    try {
      await _proximitySub?.cancel();
      _proximitySub = null;
      await _audioSession?.setActive(false);
      _audioSession = null;
      _isNear = false;
      _isSpeaker = false;
    } catch (e) {
      debugPrint('[AudioSession] Dispose error: $e');
    }
  }
}
