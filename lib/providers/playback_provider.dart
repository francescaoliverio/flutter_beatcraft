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
    this.queue = const [],
    this.queueIndex = 0,
  });

  final PlaybackStatus status;
  final String? trackId;
  final Duration position;
  final Duration duration;

  /// The list the current track was started from (a playlist, an artist, a Home row, the favorites).
  /// Next and previous move through it, and after the last track it starts again from the first.
  /// Empty for a track restored at launch.
  final List<Track> queue;

  /// Position of the current track in [queue].
  final int queueIndex;

  bool get isPlaying => status == PlaybackStatus.playing;

  /// Loaded and controllable: play, pause and seek have an effect.
  bool get isReady => status == PlaybackStatus.playing || status == PlaybackStatus.paused;

  /// True when next and previous have another track to go to.
  bool get hasQueue => queue.length > 1;

  PlaybackState copyWith({
    PlaybackStatus? status,
    String? trackId,
    Duration? position,
    Duration? duration,
    List<Track>? queue,
    int? queueIndex,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      trackId: trackId ?? this.trackId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
    );
  }
}

/// Played for longer than this, previous starts the track again instead of going back.
const Duration restartThreshold = Duration(seconds: 3);

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

  /// Makes [track] the current track and plays it from the beginning, with [queue] (the list it was
  /// chosen from, [track] included) for next and previous. Without a queue, only [track] is in it.
  /// If [track] is already loaded, it continues from where it is.
  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    final List<Track> list = queue == null || !queue.any((t) => t.id == track.id) ? [track] : List.unmodifiable(queue);
    final int index = list.indexWhere((t) => t.id == track.id);
    if (state.trackId == track.id && state.isReady) {
      state = state.copyWith(queue: list, queueIndex: index);
      if (!state.isPlaying) _play();
      return;
    }
    await _playAt(list, index);
  }

  /// The next track of the queue, the first one after the last.
  Future<void> next() async {
    if (!state.hasQueue) return;
    await _playAt(state.queue, (state.queueIndex + 1) % state.queue.length);
  }

  /// Back to the start of the track if it played for more than [restartThreshold], otherwise the previous track
  /// of the queue (the last one before the first).
  Future<void> previous() async {
    if ((state.isReady && state.position > restartThreshold) || !state.hasQueue) {
      seek(Duration.zero);
      return;
    }
    final int length = state.queue.length;
    await _playAt(state.queue, (state.queueIndex - 1 + length) % length);
  }

  Future<void> _playAt(List<Track> queue, int index) async {
    final Track track = queue[index];
    state = state.copyWith(queue: queue, queueIndex: index);
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

  /// Pauses if playing, e.g. when the remix editor starts playing.
  void pause() {
    if (state.isPlaying) _pause();
  }

  void seek(Duration position) {
    if (!state.isReady) return;
    _engine.seek(position);
    state = state.copyWith(position: position);
  }

  /// Returns true when [track] is loaded and still the latest request.
  Future<bool> _load(Track track) async {
    _stopTicker();
    // The queue stays: only the track changes
    state = PlaybackState(
      status: PlaybackStatus.loading,
      trackId: track.id,
      queue: state.queue,
      queueIndex: state.queueIndex,
    );
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
      // With a queue the next track starts, the first one after the last
      if (state.hasQueue) unawaited(next());
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
