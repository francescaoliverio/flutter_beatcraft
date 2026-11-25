import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timeline_clip.dart';
import '../models/track.dart';
import '../services/audio_engine.dart';
import 'http_client_provider.dart';
import 'playback_provider.dart';
import 'remix_provider.dart';

/// Engine of the remix editor, separate from the player's: each keeps its own track loaded.
final editorEngineProvider = Provider<AudioEngine>((ref) {
  final AudioEngine engine = SoLoudAudioEngine(ref.watch(httpClientProvider));
  ref.onDispose(engine.dispose);
  return engine;
});

/// Waveform resolution for the whole track.
const int _waveformPoints = 400;

/// How often the playhead moves while playing.
const Duration _tick = Duration(milliseconds: 50);

/// The remix being edited.
class EditorState {
  const EditorState({
    required this.track,
    required this.trackLength,
    required this.waveform,
    required this.clips,
    this.isPlaying = false,
    this.position = Duration.zero,
  });

  final Track track;
  final Duration trackLength;

  /// Loudness of the whole original track, from 0 to 1.
  final Float32List waveform;

  final List<TimelineClip> clips;
  final bool isPlaying;

  /// Playhead position on the timeline.
  final Duration position;

  /// End of the last clip.
  Duration get length =>
      clips.fold(Duration.zero, (Duration end, TimelineClip clip) => clip.timelineEnd > end ? clip.timelineEnd : end);

  EditorState copyWith({List<TimelineClip>? clips, bool? isPlaying, Duration? position}) {
    return EditorState(
      track: track,
      trackLength: trackLength,
      waveform: waveform,
      clips: clips ?? this.clips,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
    );
  }
}

/// Loads the track of [remixTrackProvider] and plays its timeline. Null while no track was chosen for remixing.
class EditorNotifier extends AsyncNotifier<EditorState?> {
  Timer? _ticker;

  AudioEngine get _engine => ref.read(editorEngineProvider);

  @override
  Future<EditorState?> build() async {
    final Track? track = ref.watch(remixTrackProvider);
    // Read before onDispose: Riverpod forbids using ref inside life-cycle callbacks
    final AudioEngine engine = _engine;
    ref.onDispose(() {
      _stopTicker();
      engine.stopTimeline();
    });
    if (track == null) return null;

    // Only one plays at a time: the player starting stops the timeline
    ref.listen(playbackProvider.select((p) => p.isPlaying), (_, bool playing) {
      if (playing) pause();
    });

    final Duration length = await _engine.load(track.audio);
    final Float32List waveform = await _engine.waveform(_waveformPoints);
    return EditorState(
      track: track,
      trackLength: length,
      waveform: waveform,
      // A new remix starts with the whole track as one clip
      clips: [TimelineClip(sourceStart: Duration.zero, sourceEnd: length, timelineStart: Duration.zero)],
    );
  }

  /// Plays from the playhead, or from the start if the playhead is at the end.
  void play() {
    final EditorState? editor = state.value;
    if (editor == null || editor.isPlaying) return;
    ref.read(playbackProvider.notifier).pause();
    final Duration from = editor.position >= editor.length ? Duration.zero : editor.position;
    _engine.playTimeline(editor.clips, from);
    state = AsyncData(editor.copyWith(isPlaying: true, position: from));
    _ticker = Timer.periodic(_tick, (_) => _onTick());
  }

  void pause() {
    final EditorState? editor = state.value;
    if (editor == null || !editor.isPlaying) return;
    _stopTicker();
    _engine.stopTimeline();
    state = AsyncData(editor.copyWith(isPlaying: false, position: _engine.timelinePosition));
  }

  void toggle() => state.value?.isPlaying ?? false ? pause() : play();

  /// Moves the playhead. While playing, the timeline continues from there.
  void seek(Duration position) {
    final EditorState? editor = state.value;
    if (editor == null) return;
    final Duration clamped = position < Duration.zero
        ? Duration.zero
        : (position > editor.length ? editor.length : position);
    if (editor.isPlaying) _engine.playTimeline(editor.clips, clamped);
    state = AsyncData(editor.copyWith(position: clamped));
  }

  void _onTick() {
    final EditorState? editor = state.value;
    if (editor == null) return;
    final Duration position = _engine.timelinePosition;
    if (position >= editor.length) {
      _stopTicker();
      _engine.stopTimeline();
      state = AsyncData(editor.copyWith(isPlaying: false, position: editor.length));
      return;
    }
    state = AsyncData(editor.copyWith(position: position));
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}

final editorProvider = AsyncNotifierProvider<EditorNotifier, EditorState?>(
  EditorNotifier.new,
  // Retried only with the Retry button
  retry: (_, _) => null,
);
