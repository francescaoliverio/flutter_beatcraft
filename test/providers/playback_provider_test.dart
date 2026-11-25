import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_beatcraft/models/timeline_clip.dart';
import 'package:flutter_beatcraft/models/track.dart';
import 'package:flutter_beatcraft/providers/local_storage_provider.dart';
import 'package:flutter_beatcraft/providers/playback_provider.dart';
import 'package:flutter_beatcraft/providers/player_provider.dart';
import 'package:flutter_beatcraft/services/audio_engine.dart';
import 'package:flutter_beatcraft/services/local_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory storage, so tests don't touch the device preferences.
class FakeLocalStorage implements LocalStorage {
  int? userId;
  String? lastTrackId;
  List<String> favoriteTrackIds = [];

  @override
  Future<int?> readUserId() async => userId;

  @override
  Future<void> saveUserId(int id) async => userId = id;

  @override
  Future<void> clearUserId() async => userId = null;

  @override
  Future<String?> readLastTrackId() async => lastTrackId;

  @override
  Future<void> saveLastTrackId(String id) async => lastTrackId = id;

  @override
  Future<void> clearLastTrackId() async => lastTrackId = null;

  @override
  Future<List<String>> readFavoriteTrackIds() async => favoriteTrackIds;

  @override
  Future<void> saveFavoriteTrackIds(List<String> ids) async => favoriteTrackIds = ids;
}

/// Engine without audio: every load waits until the test calls [finish] or [fail].
class FakeAudioEngine implements AudioEngine {
  final Map<String, Completer<Duration>> _loads = {};
  bool isPlaying = false;
  Duration seekedTo = Duration.zero;

  void finish(String url) => _loads.remove(url)!.complete(const Duration(minutes: 3));

  void fail(String url) => _loads.remove(url)!.completeError(const AudioLoadException('test'));

  @override
  Future<Duration> load(String url) {
    final completer = Completer<Duration>();
    _loads[url] = completer;
    return completer.future;
  }

  @override
  void play() => isPlaying = true;

  @override
  void pause() => isPlaying = false;

  @override
  void seek(Duration position) => seekedTo = position;

  @override
  Duration get position => seekedTo;

  @override
  bool get hasEnded => false;

  @override
  Future<Float32List> waveform(int points) async => Float32List(points);

  @override
  void playTimeline(List<TimelineClip> clips, Duration from) {}

  @override
  void stopTimeline() {}

  @override
  Duration get timelinePosition => Duration.zero;

  @override
  Future<void> dispose() async {}
}

Track track(String id) => Track(
  id: id,
  name: 'Track $id',
  artistName: 'Artist',
  image: 'https://example.com/$id.jpg',
  audio: 'https://example.com/$id.mp3',
  audiodownloadAllowed: true,
  licenseCcurl: 'http://creativecommons.org/licenses/by/3.0/',
);

void main() {
  late FakeAudioEngine engine;
  late FakeLocalStorage storage;
  late ProviderContainer container;

  setUp(() async {
    engine = FakeAudioEngine();
    storage = FakeLocalStorage();
    container = ProviderContainer.test(
      overrides: [audioEngineProvider.overrideWithValue(engine), localStorageProvider.overrideWithValue(storage)],
    );
    // No saved track: the current track starts as null without calling Jamendo
    await container.read(currentTrackProvider.future);
  });

  group('playbackProvider', () {
    test('playTrack selects the track, loads it and plays it', () async {
      final Future<void> playing = container.read(playbackProvider.notifier).playTrack(track('1'));

      expect(container.read(playbackProvider).status, PlaybackStatus.loading);
      expect(container.read(currentTrackProvider).value?.id, '1');

      engine.finish('https://example.com/1.mp3');
      await playing;

      final PlaybackState state = container.read(playbackProvider);
      expect(state.status, PlaybackStatus.playing);
      expect(state.duration, const Duration(minutes: 3));
      expect(engine.isPlaying, isTrue);
      expect(storage.lastTrackId, '1');
    });

    test('toggle pauses and resumes', () async {
      final PlaybackNotifier controls = container.read(playbackProvider.notifier);
      final Future<void> playing = controls.playTrack(track('1'));
      engine.finish('https://example.com/1.mp3');
      await playing;

      await controls.toggle();
      expect(container.read(playbackProvider).status, PlaybackStatus.paused);
      expect(engine.isPlaying, isFalse);

      await controls.toggle();
      expect(container.read(playbackProvider).status, PlaybackStatus.playing);
      expect(engine.isPlaying, isTrue);
    });

    test('a failed load ends in the error status', () async {
      final Future<void> playing = container.read(playbackProvider.notifier).playTrack(track('1'));
      engine.fail('https://example.com/1.mp3');
      await playing;

      expect(container.read(playbackProvider).status, PlaybackStatus.error);
      expect(engine.isPlaying, isFalse);
    });

    test('the latest track wins when an older load finishes later', () async {
      final PlaybackNotifier controls = container.read(playbackProvider.notifier);
      final Future<void> first = controls.playTrack(track('1'));
      final Future<void> second = controls.playTrack(track('2'));

      engine.finish('https://example.com/2.mp3');
      await second;
      engine.finish('https://example.com/1.mp3');
      await first;

      final PlaybackState state = container.read(playbackProvider);
      expect(state.trackId, '2');
      expect(state.status, PlaybackStatus.playing);
    });

    test('seek is ignored until a track is loaded', () {
      container.read(playbackProvider.notifier).seek(const Duration(seconds: 30));

      expect(engine.seekedTo, Duration.zero);
    });
  });
}
