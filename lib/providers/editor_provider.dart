import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/remix_project.dart';
import '../models/timeline_clip.dart';
import '../models/track.dart';
import '../services/audio_engine.dart';
import 'http_client_provider.dart';
import 'jamendo_provider.dart';
import 'playback_provider.dart';
import 'remix_provider.dart';

/// A saved remix can't be opened: its track is not on Jamendo anymore, or can't be remixed anymore.
class RemixUnavailableException implements Exception {
  const RemixUnavailableException();
}

/// Engine of the remix editor, separate from the player's: each keeps its own track loaded.
final editorEngineProvider = Provider<AudioEngine>((ref) {
  final AudioEngine engine = SoLoudAudioEngine(ref.watch(httpClientProvider));
  ref.onDispose(engine.dispose);
  return engine;
});

/// Waveform points per second of track, enough for the closest zoom (1 s across the screen).
const int _waveformPointsPerSecond = 50;

/// Limits on the waveform points of a whole track, for very short and very long tracks.
const int _minWaveformPoints = 400;
const int _maxWaveformPoints = 30000;

/// How often the playhead moves while playing.
const Duration _tick = Duration(milliseconds: 50);

/// Shortest clip a split can leave on either side.
const Duration minClipLength = Duration(milliseconds: 100);

/// Where a clip of [length] dropped at [start] is inserted, or null if it fits there without covering [others].
/// Dropped over a clip, it goes before it (first half) or after it (second half); otherwise it goes at [start].
Duration? insertionPoint(List<TimelineClip> others, Duration start, Duration length) {
  final Duration end = start + length;
  if (!others.any((c) => c.timelineStart < end && c.timelineEnd > start)) return null;
  final TimelineClip? under = others.where((c) => c.timelineStart < start && c.timelineEnd > start).lastOrNull;
  if (under == null) return start;
  return start < under.timelineStart + under.length ~/ 2 ? under.timelineStart : under.timelineEnd;
}

/// [clips] one after the other from 0, in timeline order (list order for equal starts). Drawing order is kept.
List<TimelineClip> packClips(List<TimelineClip> clips) {
  final List<int> order = List.generate(clips.length, (i) => i)
    ..sort((a, b) {
      final int byStart = clips[a].timelineStart.compareTo(clips[b].timelineStart);
      return byStart != 0 ? byStart : a.compareTo(b);
    });
  final Map<int, Duration> starts = {};
  Duration cursor = Duration.zero;
  for (final int i in order) {
    starts[clips[i].id] = cursor;
    cursor += clips[i].length;
  }
  return [for (final TimelineClip clip in clips) clip.copyWith(timelineStart: starts[clip.id])];
}

/// A save that can be undone: the saved project and the version it replaced, null on its first save.
typedef SavedRemix = ({String projectId, RemixProject? previous});

/// The remix being edited.
class EditorState {
  const EditorState({
    required this.track,
    required this.trackLength,
    required this.waveform,
    required this.clips,
    required this.name,
    required this.cover,
    this.projectId,
    this.hasUnsavedChanges = false,
    this.selectedClipId,
    this.canUndo = false,
    this.canRedo = false,
    this.isPlaying = false,
    this.position = Duration.zero,
  });

  final Track track;
  final Duration trackLength;

  /// Loudness of the whole original track, from 0 to 1, with the loudest point at 1.
  final Float32List waveform;

  /// In drawing order: when clips overlap, the later one is on top.
  final List<TimelineClip> clips;

  final String name;

  /// Cover number, from 1 to [RemixProject.coverCount].
  final int cover;

  /// Null until the remix is saved for the first time.
  final String? projectId;

  final bool hasUnsavedChanges;

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

  /// True if Close gaps would move something: a gap, an overlap or a first clip not at 0.
  bool get hasGaps {
    final List<TimelineClip> packed = packClips(clips);
    return packed.indexed.any((entry) => entry.$2.timelineStart != clips[entry.$1].timelineStart);
  }

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
    String? name,
    int? cover,
    String? projectId,
    bool? hasUnsavedChanges,
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
      name: name ?? this.name,
      cover: cover ?? this.cover,
      projectId: projectId ?? this.projectId,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      selectedClipId: clearSelection ? null : (selectedClipId ?? this.selectedClipId),
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
    );
  }
}

/// Opens what [remixProvider] asks for, edits its clips, plays the timeline and saves it as a project.
/// Null while nothing was chosen for remixing.
class EditorNotifier extends AsyncNotifier<EditorState?> {
  Timer? _ticker;

  /// Clip lists before each edit, for undo, and after each undo, for redo.
  final List<List<TimelineClip>> _undo = [];
  final List<List<TimelineClip>> _redo = [];

  int _nextClipId = 0;

  AudioEngine get _engine => ref.read(editorEngineProvider);

  @override
  Future<EditorState?> build() async {
    final RemixRequest? request = ref.watch(remixProvider);
    // Read before onDispose: Riverpod forbids using ref inside life-cycle callbacks
    final AudioEngine engine = _engine;
    ref.onDispose(() {
      _stopTicker();
      engine.stopTimeline();
    });
    _undo.clear();
    _redo.clear();
    _nextClipId = 0;
    if (request == null) return null;
    final RemixProject? project = request.project;

    // Only one plays at a time: the player starting stops the timeline
    ref.listen(playbackProvider.select((p) => p.isPlaying), (_, bool playing) {
      if (playing) pause();
    });
    // The open remix deleted from the profile (or brought back with Undo) changes its saved state
    ref.listen(remixProjectsProvider, (_, AsyncValue<List<RemixProject>> projects) {
      final List<RemixProject>? saved = projects.value;
      if (saved != null) _onProjectsChanged(saved);
    });

    final Track track = request.track ?? await _projectTrack(project!);
    final Duration length = await _engine.load(track.audio);
    final int points = (length.inSeconds * _waveformPointsPerSecond).clamp(_minWaveformPoints, _maxWaveformPoints);
    final Float32List waveform = _normalized(await _engine.waveform(points));

    if (project != null) {
      _nextClipId = project.clips.fold(0, (int next, TimelineClip clip) => clip.id >= next ? clip.id + 1 : next);
      return EditorState(
        track: track,
        trackLength: length,
        waveform: waveform,
        clips: project.clips,
        name: project.name,
        cover: project.cover,
        projectId: project.id,
      );
    }
    return EditorState(
      track: track,
      trackLength: length,
      waveform: waveform,
      // A new remix starts with the whole track as one clip
      clips: [
        TimelineClip(id: _nextClipId++, sourceStart: Duration.zero, sourceEnd: length, timelineStart: Duration.zero),
      ],
      name: await _freeName('${track.name} remix'),
      cover: Random().nextInt(RemixProject.coverCount) + 1,
      hasUnsavedChanges: true,
    );
  }

  /// [loudness] scaled so the loudest point is 1, so the timeline draws it at full height.
  Float32List _normalized(Float32List loudness) {
    final double peak = loudness.fold(0, max);
    if (peak <= 0) return loudness;
    return Float32List.fromList([for (final double value in loudness) value / peak]);
  }

  /// The track of a saved remix, fetched again from Jamendo and checked against the remix rule.
  Future<Track> _projectTrack(RemixProject project) async {
    final Track? track = await ref.read(jamendoServiceProvider).trackById(project.trackId);
    if (track == null || !track.canRemix) throw const RemixUnavailableException();
    return track;
  }

  // Project

  /// [name], or [name] followed by the first free number, so the user's remixes never share a name.
  Future<String> _freeName(String name) async {
    final List<RemixProject> projects = await ref.read(remixProjectsProvider.future);
    String candidate = name;
    for (int number = 2; isRemixNameTaken(projects, candidate); number++) {
      candidate = '$name $number';
    }
    return candidate;
  }

  /// Ignored if [name] is empty: the rename dialog checks it, and that no other remix of the user has it.
  void rename(String name) {
    final EditorState? editor = state.value;
    final String trimmed = name.trim();
    if (editor == null || trimmed.isEmpty || trimmed == editor.name) return;
    state = AsyncData(editor.copyWith(name: trimmed, hasUnsavedChanges: true));
  }

  void setCover(int cover) {
    final EditorState? editor = state.value;
    if (editor == null || cover == editor.cover) return;
    state = AsyncData(editor.copyWith(cover: cover, hasUnsavedChanges: true));
  }

  /// Saves the remix as a project: the first time it gets an id, then it is updated in place.
  /// Returns what an undo of this save needs, null if nothing was open or another remix has its name.
  Future<SavedRemix?> save() async {
    final EditorState? editor = state.value;
    if (editor == null) return null;
    final String projectId = editor.projectId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final List<RemixProject> projects =
        ref.read(remixProjectsProvider).value ?? await ref.read(remixProjectsProvider.future);
    if (isRemixNameTaken(projects, editor.name, exceptId: projectId)) return null;
    final RemixProject? previous = projects.where((p) => p.id == projectId).firstOrNull;
    await ref
        .read(remixProjectsProvider.notifier)
        .save(
          RemixProject(
            id: projectId,
            name: editor.name,
            trackId: editor.track.id,
            clips: editor.clips,
            cover: editor.cover,
            updatedAt: DateTime.now(),
          ),
        );
    // Edits made while saving are kept: only the project id and the saved flag change
    final EditorState? current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(projectId: projectId, hasUnsavedChanges: !identical(current.clips, editor.clips)),
      );
    }
    return (projectId: projectId, previous: previous);
  }

  /// Saved only while its project holds the same content: deleting it or putting back an older version
  /// (undo of a delete or of a save) changes the Save button.
  void _onProjectsChanged(List<RemixProject> projects) {
    final EditorState? editor = state.value;
    final String? projectId = editor?.projectId;
    if (editor == null || projectId == null) return;
    final RemixProject? project = projects.where((p) => p.id == projectId).firstOrNull;
    final bool unsaved = project == null || !_matches(project, editor);
    if (unsaved != editor.hasUnsavedChanges) state = AsyncData(editor.copyWith(hasUnsavedChanges: unsaved));
  }

  bool _matches(RemixProject project, EditorState editor) =>
      project.name == editor.name &&
      project.cover == editor.cover &&
      project.trackId == editor.track.id &&
      jsonEncode(project.clips) == jsonEncode(editor.clips);

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

  /// Drops a clip at [timelineStart] (not before 0) and selects it.
  /// In a free space it stays there. Over other clips it is inserted (see [insertionPoint])
  /// and every clip from that point moves right by its length.
  void move(int clipId, Duration timelineStart) {
    final EditorState? editor = state.value;
    if (editor == null) return;
    final Duration start = timelineStart < Duration.zero ? Duration.zero : timelineStart;
    final TimelineClip? clip = editor.clips.where((c) => c.id == clipId).firstOrNull;
    if (clip == null || clip.timelineStart == start) return;
    final List<TimelineClip> others = editor.clips.where((c) => c.id != clipId).toList();
    final Duration? insertAt = insertionPoint(others, start, clip.length);
    // The moved clip goes last, so it is drawn on top
    _edit(editor, [
      for (final TimelineClip c in others)
        if (insertAt != null && c.timelineStart >= insertAt)
          c.copyWith(timelineStart: c.timelineStart + clip.length)
        else
          c,
      clip.copyWith(timelineStart: insertAt ?? start),
    ], selectedClipId: clipId);
  }

  /// Moves a clip by [step], stopping against its neighbours instead of pushing them. For screen readers.
  void nudge(int clipId, Duration step) {
    final EditorState? editor = state.value;
    final TimelineClip? clip = editor?.clips.where((c) => c.id == clipId).firstOrNull;
    if (editor == null || clip == null) return;
    final Iterable<TimelineClip> others = editor.clips.where((c) => c.id != clipId);
    Duration start = clip.timelineStart + step;
    if (step > Duration.zero) {
      for (final TimelineClip next in others.where((c) => c.timelineStart >= clip.timelineEnd)) {
        final Duration limit = next.timelineStart - clip.length;
        if (start > limit) start = limit;
      }
    } else {
      for (final TimelineClip previous in others.where((c) => c.timelineEnd <= clip.timelineStart)) {
        if (start < previous.timelineEnd) start = previous.timelineEnd;
      }
      if (start < Duration.zero) start = Duration.zero;
    }
    if (start == clip.timelineStart) return;
    _edit(editor, [for (final TimelineClip c in editor.clips) c.id == clipId ? c.copyWith(timelineStart: start) : c]);
  }

  /// Puts the clips one after the other from the start, in their timeline order.
  void closeGaps() {
    final EditorState? editor = state.value;
    if (editor == null || !editor.hasGaps) return;
    _edit(editor, packClips(editor.clips));
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
      hasUnsavedChanges: true,
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
