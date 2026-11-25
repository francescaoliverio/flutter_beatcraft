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

/// Shortest clip a split can leave on either side.
const Duration minClipLength = Duration(milliseconds: 100);

/// The remix being edited.
class EditorState {
  const EditorState({
    required this.track,
    required this.trackLength,
    required this.waveform,
    required this.clips,
    this.selectedClipId,
    this.canUndo = false,
    this.canRedo = false,
    this.isPlaying = false,
    this.position = Duration.zero,
  });

  final Track track;
  final Duration trackLength;

  /// Loudness of the whole original track, from 0 to 1.
  final Float32List waveform;

  /// In drawing order: when clips overlap, the later one is on top.
  final List<TimelineClip> clips;

  final int? selectedClipId;
  final bool canUndo;
  final bool canRedo;
  final bool isPlaying;

  /// Playhead position on the timeline.
  final Duration position;

  /// End of the last clip.
  Duration get length =>
      clips.fold(Duration.zero, (Duration end, TimelineClip clip) => clip.timelineEnd > end ? clip.timelineEnd : end);

  TimelineClip? get selectedClip => clips.where((clip) => clip.id == selectedClipId).firstOrNull;

  /// The clip a split cuts: the selected one if the playhead is on it, otherwise the topmost under the playhead.
  /// Null if the cut would leave a piece shorter than [minClipLength].
  TimelineClip? get clipToSplit {
    bool fits(TimelineClip clip) =>
        position - clip.timelineStart >= minClipLength && clip.timelineEnd - position >= minClipLength;
    final TimelineClip? selected = selectedClip;
    if (selected != null && fits(selected)) return selected;
    return clips.reversed.where(fits).firstOrNull;
  }

  EditorState copyWith({
    List<TimelineClip>? clips,
    int? selectedClipId,
    bool clearSelection = false,
    bool? canUndo,
    bool? canRedo,
    bool? isPlaying,
    Duration? position,
  }) {
    return EditorState(
      track: track,
      trackLength: trackLength,
      waveform: waveform,
      clips: clips ?? this.clips,
      selectedClipId: clearSelection ? null : (selectedClipId ?? this.selectedClipId),
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
    );
  }
}

/// Loads the track of [remixTrackProvider], edits its clips and plays the timeline.
/// Null while no track was chosen for remixing.
class EditorNotifier extends AsyncNotifier<EditorState?> {
  Timer? _ticker;

  /// Clip lists before each edit, for undo, and after each undo, for redo.
  final List<List<TimelineClip>> _undo = [];
  final List<List<TimelineClip>> _redo = [];

  int _nextClipId = 0;

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
    _undo.clear();
    _redo.clear();
    _nextClipId = 0;
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
      clips: [
        TimelineClip(id: _nextClipId++, sourceStart: Duration.zero, sourceEnd: length, timelineStart: Duration.zero),
      ],
    );
  }

  // Playback

  /// Plays from the playhead, or from the start if the playhead is at the end.
  void play() {
    final EditorState? editor = state.value;
    if (editor == null || editor.isPlaying || editor.clips.isEmpty) return;
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
    state = AsyncData(editor.copyWith(isPlaying: false, position: _clamp(_engine.timelinePosition, editor)));
  }

  void toggle() => state.value?.isPlaying ?? false ? pause() : play();

  /// Moves the playhead. While playing, the timeline continues from there.
  void seek(Duration position) {
    final EditorState? editor = state.value;
    if (editor == null) return;
    final Duration clamped = _clamp(position, editor);
    if (editor.isPlaying) _engine.playTimeline(editor.clips, clamped);
    state = AsyncData(editor.copyWith(position: clamped));
  }

  // Selection and edits

  /// Selects a clip, or clears the selection with null.
  void select(int? clipId) {
    final EditorState? editor = state.value;
    if (editor == null) return;
    state = AsyncData(editor.copyWith(selectedClipId: clipId, clearSelection: clipId == null));
  }

  /// Cuts [EditorState.clipToSplit] in two at the playhead and selects the right part.
  void split() {
    final EditorState? editor = state.value;
    final TimelineClip? clip = editor?.clipToSplit;
    if (editor == null || clip == null) return;
    final Duration cut = clip.sourceStart + (editor.position - clip.timelineStart);
    final TimelineClip right = TimelineClip(
      id: _nextClipId++,
      sourceStart: cut,
      sourceEnd: clip.sourceEnd,
      timelineStart: editor.position,
    );
    _edit(editor, [
      for (final TimelineClip c in editor.clips)
        if (c.id == clip.id) ...[c.copyWith(sourceEnd: cut), right] else c,
    ], selectedClipId: right.id);
  }

  /// Copies the selected clip to the end of the timeline and selects the copy.
  void duplicateSelected() {
    final EditorState? editor = state.value;
    final TimelineClip? clip = editor?.selectedClip;
    if (editor == null || clip == null) return;
    final TimelineClip copy = clip.copyWith(id: _nextClipId++, timelineStart: editor.length);
    _edit(editor, [...editor.clips, copy], selectedClipId: copy.id);
  }

  void deleteSelected() {
    final EditorState? editor = state.value;
    final TimelineClip? clip = editor?.selectedClip;
    if (editor == null || clip == null) return;
    _edit(editor, editor.clips.where((c) => c.id != clip.id).toList(), clearSelection: true);
  }

  /// Places a clip at [timelineStart] (not before 0) and selects it. Overlapping clips play together.
  void move(int clipId, Duration timelineStart) {
    final EditorState? editor = state.value;
    if (editor == null) return;
    final Duration start = timelineStart < Duration.zero ? Duration.zero : timelineStart;
    final TimelineClip? clip = editor.clips.where((c) => c.id == clipId).firstOrNull;
    if (clip == null || clip.timelineStart == start) return;
    // The moved clip goes last, so it is drawn on top
    _edit(editor, [
      ...editor.clips.where((c) => c.id != clipId),
      clip.copyWith(timelineStart: start),
    ], selectedClipId: clipId);
  }

  void undo() {
    final EditorState? editor = state.value;
    if (editor == null || _undo.isEmpty) return;
    _redo.add(editor.clips);
    _apply(editor, _undo.removeLast());
  }

  void redo() {
    final EditorState? editor = state.value;
    if (editor == null || _redo.isEmpty) return;
    _undo.add(editor.clips);
    _apply(editor, _redo.removeLast());
  }

  /// An edit made by the user: it can be undone, and it clears what could be redone.
  void _edit(EditorState editor, List<TimelineClip> clips, {int? selectedClipId, bool clearSelection = false}) {
    _undo.add(editor.clips);
    _redo.clear();
    _apply(editor, clips, selectedClipId: selectedClipId, clearSelection: clearSelection);
  }

  /// Shows [clips] and, while playing, makes them heard at once from where the timeline is.
  void _apply(EditorState editor, List<TimelineClip> clips, {int? selectedClipId, bool clearSelection = false}) {
    EditorState next = editor.copyWith(
      clips: clips,
      selectedClipId: selectedClipId,
      // After undo or redo the selected clip may not exist anymore
      clearSelection: clearSelection || !clips.any((c) => c.id == (selectedClipId ?? editor.selectedClipId)),
      canUndo: _undo.isNotEmpty,
      canRedo: _redo.isNotEmpty,
    );
    if (editor.isPlaying) {
      final Duration from = _engine.timelinePosition;
      if (from >= next.length) {
        _stopTicker();
        _engine.stopTimeline();
        next = next.copyWith(isPlaying: false);
      } else {
        _engine.playTimeline(clips, from);
      }
    }
    state = AsyncData(next.copyWith(position: _clamp(next.position, next)));
  }

  Duration _clamp(Duration position, EditorState editor) {
    if (position < Duration.zero) return Duration.zero;
    return position > editor.length ? editor.length : position;
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
