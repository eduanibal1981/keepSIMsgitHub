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
  StreamSubscription<AudioDevicesChangedEvent>? _devicesSub;
  bool _isNear = false;
  bool _isSpeaker = false;

  void Function(bool isNear)? onProximityChanged;
  void Function(bool isSpeaker)? onRouteChanged;

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
              AVAudioSessionCategoryOptions.allowBluetoothA2dp,
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

      // Default routing to earpiece initially (matching call UI state)
      await Helper.setSpeakerphoneOn(false);

      // Listen for audio device/route changes (Bluetooth / wired headset plug/unplug)
      _devicesSub = _audioSession!.devicesChangedEventStream.listen((event) {
        debugPrint('[AudioSession] Audio devices changed: added=${event.devicesAdded}, removed=${event.devicesRemoved}');
      });

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
      onRouteChanged?.call(enableSpeaker);
    } catch (e) {
      debugPrint('[AudioSession] Set speakerphone error: $e');
    }
  }

  /// Activate or reactivate audio session (e.g. CallKit didActivateAudioSession)
  Future<void> setActive(bool active) async {
    try {
      await _audioSession?.setActive(active);
    } catch (e) {
      debugPrint('[AudioSession] setActive error: $e');
    }
  }

  /// Release audio session and stop proximity sensor
  Future<void> dispose() async {
    try {
      await _proximitySub?.cancel();
      _proximitySub = null;
      await _devicesSub?.cancel();
      _devicesSub = null;
      try {
        await Helper.setSpeakerphoneOn(false);
      } catch (_) {}
      await _audioSession?.setActive(false);
      _audioSession = null;
      _isNear = false;
      _isSpeaker = false;
    } catch (e) {
      debugPrint('[AudioSession] Dispose error: $e');
    }
  }
}
