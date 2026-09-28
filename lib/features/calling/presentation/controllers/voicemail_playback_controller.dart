/// KeepSIMs — Voicemail Playback Controller
///
/// Manages real audio streaming, scrubbable position, speed adjustment,
/// and automatic session cleanup for Visual Voicemail messages using `video_player`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

class VoicemailPlaybackState {
  final String? activeVoicemailId;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final double playbackSpeed;
  final String? errorMessage;

  const VoicemailPlaybackState({
    this.activeVoicemailId,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playbackSpeed = 1.0,
    this.errorMessage,
  });

  VoicemailPlaybackState copyWith({
    String? activeVoicemailId,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    double? playbackSpeed,
    String? errorMessage,
    bool clearActiveId = false,
    bool clearError = false,
  }) {
    return VoicemailPlaybackState(
      activeVoicemailId: clearActiveId
          ? null
          : (activeVoicemailId ?? this.activeVoicemailId),
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class VoicemailPlaybackNotifier extends Notifier<VoicemailPlaybackState> {
  VideoPlayerController? _playerController;
  bool _isDisposed = false;

  @override
  VoicemailPlaybackState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _disposePlayer();
    });
    return const VoicemailPlaybackState();
  }

  VideoPlayerController? get playerController => _playerController;

  Future<void> togglePlay({
    required String voicemailId,
    required String audioUrl,
    int? fallbackDurationSeconds,
  }) async {
    // If user tapped the currently active message:
    if (state.activeVoicemailId == voicemailId && _playerController != null) {
      if (state.isPlaying) {
        await pause();
      } else {
        await resume();
      }
      return;
    }

    // Otherwise, start playing a new voicemail message
    await _startNewPlayback(
      voicemailId: voicemailId,
      audioUrl: audioUrl,
      fallbackDurationSeconds: fallbackDurationSeconds,
    );
  }

  Future<void> _startNewPlayback({
    required String voicemailId,
    required String audioUrl,
    int? fallbackDurationSeconds,
  }) async {
    // Stop and dispose any current player
    await _disposePlayer();

    if (audioUrl.trim().isEmpty) {
      state = state.copyWith(
        activeVoicemailId: voicemailId,
        isPlaying: false,
        isBuffering: false,
        errorMessage: 'Audio recording URL unavailable.',
      );
      return;
    }

    final initialDuration = Duration(seconds: fallbackDurationSeconds ?? 0);
    state = VoicemailPlaybackState(
      activeVoicemailId: voicemailId,
      isPlaying: false,
      isBuffering: true,
      position: Duration.zero,
      duration: initialDuration,
      playbackSpeed: 1.0,
      errorMessage: null,
    );

    try {
      final uri = Uri.parse(audioUrl);
      _playerController = VideoPlayerController.networkUrl(uri);

      _playerController!.addListener(_onPlayerStateChanged);

      await _playerController!.initialize();
      await _playerController!.setPlaybackSpeed(state.playbackSpeed);
      await _playerController!.play();

      if (!_isDisposed) {
        state = state.copyWith(
          isPlaying: true,
          isBuffering: false,
          duration: _playerController!.value.duration,
          clearError: true,
        );
      }
    } catch (e) {
      debugPrint('[VoicemailPlayback] Initialization error: $e');
      if (!_isDisposed) {
        state = state.copyWith(
          isPlaying: false,
          isBuffering: false,
          errorMessage: 'Unable to stream audio. Check your connection.',
        );
      }
      await _disposePlayer();
    }
  }

  void _onPlayerStateChanged() {
    if (_playerController == null || _isDisposed) return;

    final value = _playerController!.value;
    if (value.hasError) {
      state = state.copyWith(
        isPlaying: false,
        isBuffering: false,
        errorMessage: 'Playback error: ${value.errorDescription}',
      );
      return;
    }

    final isPlaying = value.isPlaying;
    final isBuffering = value.isBuffering;
    final position = value.position;
    final duration = value.duration > Duration.zero
        ? value.duration
        : state.duration;

    // Check for playback completion
    final isCompleted = duration > Duration.zero && position >= duration;

    if (isCompleted) {
      state = state.copyWith(
        isPlaying: false,
        isBuffering: false,
        position: Duration.zero,
      );
      _playerController?.seekTo(Duration.zero);
      _playerController?.pause();
      return;
    }

    state = state.copyWith(
      isPlaying: isPlaying,
      isBuffering: isBuffering,
      position: position,
      duration: duration,
    );
  }

  Future<void> pause() async {
    if (_playerController != null && state.isPlaying) {
      try {
        await _playerController!.pause();
        if (!_isDisposed) {
          state = state.copyWith(isPlaying: false);
        }
      } catch (_) {}
    }
  }

  Future<void> resume() async {
    if (_playerController != null && !state.isPlaying) {
      try {
        await _playerController!.play();
        if (!_isDisposed) {
          state = state.copyWith(isPlaying: true);
        }
      } catch (_) {}
    }
  }

  Future<void> seek(Duration targetPosition) async {
    if (_playerController != null) {
      try {
        await _playerController!.seekTo(targetPosition);
        if (!_isDisposed) {
          state = state.copyWith(position: targetPosition);
        }
      } catch (_) {}
    }
  }

  Future<void> cyclePlaybackSpeed() async {
    final speeds = [1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexOf(state.playbackSpeed);
    final nextSpeed = speeds[(currentIndex + 1) % speeds.length];

    if (_playerController != null) {
      try {
        await _playerController!.setPlaybackSpeed(nextSpeed);
      } catch (_) {}
    }

    if (!_isDisposed) {
      state = state.copyWith(playbackSpeed: nextSpeed);
    }
  }

  Future<void> stop() async {
    await _disposePlayer();
    if (!_isDisposed) {
      state = const VoicemailPlaybackState();
    }
  }

  Future<void> _disposePlayer() async {
    if (_playerController != null) {
      try {
        _playerController!.removeListener(_onPlayerStateChanged);
        await _playerController!.pause();
        await _playerController!.dispose();
      } catch (_) {}
      _playerController = null;
    }
  }
}

final voicemailPlaybackControllerProvider =
    NotifierProvider.autoDispose<VoicemailPlaybackNotifier, VoicemailPlaybackState>(
  () => VoicemailPlaybackNotifier(),
);
