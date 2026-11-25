import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/track.dart';
import '../services/audio_engine.dart';
import 'http_client_provider.dart';
import 'player_provider.dart';

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final AudioEngine engine = SoLoudAudioEngine(ref.watch(httpClientProvider));
  ref.onDispose(engine.dispose);
  return engine;
});

enum PlaybackStatus { idle, loading, playing, paused, error }

/// Playback of the current track. [trackId] is the track loaded in the engine, null before the first load.
class PlaybackState {
  const PlaybackState({
    this.status = PlaybackStatus.idle,
    this.trackId,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final PlaybackStatus status;
  final String? trackId;
  final Duration position;
  final Duration duration;

  bool get isPlaying => status == PlaybackStatus.playing;

  /// Loaded and controllable: play, pause and seek have an effect.
  bool get isReady => status == PlaybackStatus.playing || status == PlaybackStatus.paused;

  PlaybackState copyWith({PlaybackStatus? status, String? trackId, Duration? position, Duration? duration}) {
    return PlaybackState(
      status: status ?? this.status,
      trackId: trackId ?? this.trackId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

/// How often the position shown in the player is updated while playing.
const Duration _tick = Duration(milliseconds: 200);

/// Plays the track of [currentTrackProvider]. A track restored at launch is loaded only when Play is pressed.
class PlaybackNotifier extends Notifier<PlaybackState> {
  Timer? _ticker;

  @override
  PlaybackState build() {
    ref.onDispose(_stopTicker);
    return const PlaybackState();
  }

  AudioEngine get _engine => ref.read(audioEngineProvider);

  /// Makes [track] the current track and plays it from the beginning.
  /// If [track] is already loaded, it continues from where it is.
  Future<void> playTrack(Track track) async {
    if (state.trackId == track.id && state.isReady) {
      if (!state.isPlaying) _play();
      return;
    }
    unawaited(ref.read(currentTrackProvider.notifier).select(track));
    if (await _load(track)) _play();
  }

  /// Play or pause. Before the first load, loads the current track and plays it.
  Future<void> toggle() async {
    switch (state.status) {
      case PlaybackStatus.playing:
        _pause();
      case PlaybackStatus.paused:
        _play();
      case PlaybackStatus.loading:
        return;
      case PlaybackStatus.idle:
      case PlaybackStatus.error:
        final Track? track = ref.read(currentTrackProvider).value;
        if (track != null && await _load(track)) _play();
    }
  }

  void seek(Duration position) {
    if (!state.isReady) return;
    _engine.seek(position);
    state = state.copyWith(position: position);
  }

  /// Returns true when [track] is loaded and still the latest request.
  Future<bool> _load(Track track) async {
    _stopTicker();
    state = PlaybackState(status: PlaybackStatus.loading, trackId: track.id);
    try {
      final Duration duration = await _engine.load(track.audio);
      if (state.trackId != track.id) return false;
      state = state.copyWith(status: PlaybackStatus.paused, duration: duration, position: Duration.zero);
      return true;
    } on AudioLoadCancelled {
      return false;
    } on AudioLoadException {
      if (state.trackId == track.id) state = state.copyWith(status: PlaybackStatus.error);
      return false;
    }
  }

  void _play() {
    _stopTicker();
    _engine.play();
    state = state.copyWith(status: PlaybackStatus.playing);
    _ticker = Timer.periodic(_tick, (_) => _onTick());
  }

  void _pause() {
    _stopTicker();
    _engine.pause();
    state = state.copyWith(status: PlaybackStatus.paused, position: _engine.position);
  }

  void _onTick() {
    if (_engine.hasEnded) {
      _stopTicker();
      state = state.copyWith(status: PlaybackStatus.paused, position: state.duration);
      return;
    }
    state = state.copyWith(position: _engine.position);
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}

final playbackProvider = NotifierProvider<PlaybackNotifier, PlaybackState>(PlaybackNotifier.new);
