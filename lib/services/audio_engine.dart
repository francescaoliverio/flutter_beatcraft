import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:http/http.dart' as http;

import '../models/timeline_clip.dart';

/// Loading a track failed: network error, HTTP status other than 200, engine not available or audio not decodable.
class AudioLoadException implements Exception {
  const AudioLoadException(this.message);

  final String message;

  @override
  String toString() => 'AudioLoadException: $message';
}

/// A newer [AudioEngine.load] started before this one finished: its result is dropped.
class AudioLoadCancelled implements Exception {
  const AudioLoadCancelled();
}

/// The part of a [TimelineClip] that plays when the timeline starts from a given position.
class TimelinePart {
  const TimelinePart({required this.delay, required this.sourceStart, required this.length});

  /// Time from the timeline start to the moment this part begins.
  final Duration delay;

  /// Where the part begins in the original track.
  final Duration sourceStart;

  final Duration length;
}

/// What plays when the timeline starts from [from]: clips that end before it are skipped,
/// a clip that contains it plays only its remaining part.
List<TimelinePart> planTimeline(List<TimelineClip> clips, Duration from) {
  final List<TimelinePart> parts = [];
  for (final TimelineClip clip in clips) {
    if (clip.timelineEnd <= from) continue;
    final Duration skipped = from > clip.timelineStart ? from - clip.timelineStart : Duration.zero;
    parts.add(
      TimelinePart(
        delay: clip.timelineStart + skipped - from,
        sourceStart: clip.sourceStart + skipped,
        length: clip.length - skipped,
      ),
    );
  }
  return parts;
}

/// Plays one track at a time, whole or as a timeline of clips.
/// Abstract so tests can replace the real engine with a fake.
abstract class AudioEngine {
  /// Downloads [url] and replaces the current track, paused at the start. Returns the track length.
  Future<Duration> load(String url);

  void play();

  void pause();

  void seek(Duration position);

  /// Current position. After the end of the track it equals the track length.
  Duration get position;

  /// True from the end of the track until the next [play] or [seek].
  bool get hasEnded;

  /// Loudness of the current track in [points] equal slices, from 0 to 1. Empty if no track is loaded.
  Future<Float32List> waveform(int points);

  /// Pauses the whole track and plays [clips] from the timeline position [from].
  void playTimeline(List<TimelineClip> clips, Duration from);

  void stopTimeline();

  /// Time played on the timeline since [playTimeline], added to its `from`. It keeps growing after the last clip
  /// and stays still after [stopTimeline].
  Duration get timelinePosition;

  Future<void> dispose();
}

/// [AudioEngine] on flutter_soloud. Each instance has its own track: the player and the editor use one each.
/// The track stays in memory and is never written to disk, as the Jamendo terms require:
/// loadUrl would save a temporary copy, so the bytes are downloaded here and passed to loadMem.
class SoLoudAudioEngine implements AudioEngine {
  SoLoudAudioEngine(this._client);

  /// Time between [playTimeline] and the first sound, so every clip is scheduled and seeked before it starts.
  static const Duration _scheduleLead = Duration(milliseconds: 100);

  /// The default is 16 and, when it is reached, the engine stops the oldest voice of the same track:
  /// with one voice per clip, a longer remix would lose its first clips.
  static const int _maxVoices = 128;

  /// Shared by every engine instance (player and editor), so SoLoud is initialized only once.
  static Future<void>? _initialization;

  static Future<void> _initialize() async {
    final SoLoud soloud = SoLoud.instance;
    if (soloud.isInitialized) return;
    await soloud.init();
    soloud.setMaxActiveVoiceCount(_maxVoices);
  }

  final http.Client _client;
  final SoLoud _soloud = SoLoud.instance;

  AudioSource? _source;
  SoundHandle? _handle;
  Duration _length = Duration.zero;

  /// Compressed bytes of the current track, kept for [waveform].
  Uint8List? _bytes;

  final List<SoundHandle> _timelineHandles = [];
  Duration? _timelineStartedAt;
  Duration _timelineFrom = Duration.zero;

  /// Incremented by every [load], to recognize loads overtaken by a newer one.
  int _loadId = 0;

  @override
  Future<Duration> load(String url) async {
    final int loadId = ++_loadId;

    try {
      await (_initialization ??= _initialize());
    } on SoLoudException catch (e) {
      // The next load tries again
      _initialization = null;
      throw AudioLoadException(e.toString());
    }

    final http.Response response;
    try {
      response = await _client.get(Uri.parse(url));
    } on http.ClientException catch (e) {
      throw AudioLoadException(e.message);
    }
    if (response.statusCode != 200) throw AudioLoadException('HTTP ${response.statusCode}');
    if (loadId != _loadId) throw const AudioLoadCancelled();

    await _unload();

    final AudioSource source;
    try {
      // LoadMode.memory decodes the whole track into memory: about 20 MB per minute of stereo audio.
      // With LoadMode.disk an MP3 seek is delayed, and the timeline seeks at the start of every clip.
      source = await _soloud.loadMem(url, response.bodyBytes, mode: LoadMode.memory);
    } on SoLoudException catch (e) {
      throw AudioLoadException(e.toString());
    }
    if (loadId != _loadId) {
      await _soloud.disposeSource(source);
      throw const AudioLoadCancelled();
    }

    _source = source;
    _bytes = response.bodyBytes;
    _handle = _soloud.play(source, paused: true);
    _length = _soloud.getLength(source);
    return _length;
  }

  bool get _hasValidHandle {
    final SoundHandle? handle = _handle;
    return handle != null && _soloud.getIsValidVoiceHandle(handle);
  }

  @override
  void play() {
    final AudioSource? source = _source;
    if (source == null) return;
    if (_hasValidHandle) {
      _soloud.setPause(_handle!, false);
    } else {
      // The track ended and its handle is no longer valid: start it again from the beginning
      _handle = _soloud.play(source);
    }
  }

  @override
  void pause() {
    if (_hasValidHandle) _soloud.setPause(_handle!, true);
  }

  @override
  void seek(Duration position) {
    final AudioSource? source = _source;
    if (source == null) return;
    if (!_hasValidHandle) _handle = _soloud.play(source, paused: true);
    _soloud.seek(_handle!, position);
  }

  @override
  Duration get position {
    if (_hasValidHandle) return _soloud.getPosition(_handle!);
    return _source == null ? Duration.zero : _length;
  }

  @override
  bool get hasEnded => _source != null && !_hasValidHandle;

  @override
  Future<Float32List> waveform(int points) async {
    final Uint8List? bytes = _bytes;
    if (bytes == null) return Float32List(0);
    try {
      // average: true gives the RMS of each slice instead of its first sample
      return await _soloud.readSamplesFromMem(bytes, points, average: true);
    } on SoLoudException catch (e) {
      throw AudioLoadException(e.toString());
    }
  }

  @override
  void playTimeline(List<TimelineClip> clips, Duration from) {
    final AudioSource? source = _source;
    if (source == null) return;
    stopTimeline();
    pause();

    final Duration start = _soloud.getEngineTime() + _scheduleLead;
    for (final TimelinePart part in planTimeline(clips, from)) {
      final SoundHandle handle = _soloud.playScheduled(source, start + part.delay, duration: part.length);
      // A scheduled voice doesn't read the track before its start time, so this seek sets where it begins
      _soloud.seek(handle, part.sourceStart);
      _timelineHandles.add(handle);
    }
    _timelineStartedAt = start;
    _timelineFrom = from;
  }

  @override
  void stopTimeline() {
    // Keeps the reached position, so playing again from timelinePosition resumes where it stopped
    _timelineFrom = timelinePosition;
    for (final SoundHandle handle in _timelineHandles) {
      if (_soloud.getIsValidVoiceHandle(handle)) unawaited(_soloud.stop(handle));
    }
    _timelineHandles.clear();
    _timelineStartedAt = null;
  }

  @override
  Duration get timelinePosition {
    final Duration? startedAt = _timelineStartedAt;
    if (startedAt == null) return _timelineFrom;
    final Duration elapsed = _soloud.getEngineTime() - startedAt;
    return _timelineFrom + (elapsed.isNegative ? Duration.zero : elapsed);
  }

  Future<void> _unload() async {
    final AudioSource? source = _source;
    _source = null;
    _handle = null;
    _length = Duration.zero;
    _bytes = null;
    _timelineHandles.clear();
    _timelineStartedAt = null;
    _timelineFrom = Duration.zero;
    // disposeSource also stops every handle of the source
    if (source != null) await _soloud.disposeSource(source);
  }

  /// Frees the current track. SoLoud stays initialized: other instances may be using it.
  @override
  Future<void> dispose() => _unload();
}
