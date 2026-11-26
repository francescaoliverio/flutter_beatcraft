import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_beatcraft/models/remix_project.dart';
import 'package:flutter_beatcraft/models/timeline_clip.dart';
import 'package:flutter_beatcraft/models/track.dart';
import 'package:flutter_beatcraft/providers/auth_provider.dart';
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

  /// Per-user values, keyed by user id.
  final Map<int, String> lastTrackIds = {};
  final Map<int, List<String>> favoriteTrackIds = {};
  final Map<int, List<RemixProject>> remixProjects = {};

  @override
  Future<int?> readUserId() async => userId;

  @override
  Future<void> saveUserId(int id) async => userId = id;

  @override
  Future<void> clearUserId() async => userId = null;

  @override
  Future<String?> readLastTrackId(int userId) async => lastTrackIds[userId];

  @override
  Future<void> saveLastTrackId(int userId, String id) async => lastTrackIds[userId] = id;

  @override
  Future<List<String>> readFavoriteTrackIds(int userId) async => favoriteTrackIds[userId] ?? [];

  @override
  Future<void> saveFavoriteTrackIds(int userId, List<String> ids) async => favoriteTrackIds[userId] = ids;

  @override
  Future<List<RemixProject>> readRemixProjects(int userId) async => remixProjects[userId] ?? [];

  @override
  Future<void> saveRemixProjects(int userId, List<RemixProject> projects) async => remixProjects[userId] = projects;
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

  /// Set by a test to make the loaded track end.
  bool ended = false;

  @override
  bool get hasEnded => ended;

  @override
  Future<Float32List> waveform(int points) async => Float32List(points);

  /// Clips and start of the last [playTimeline], null when the timeline is stopped.
  List<TimelineClip>? timelineClips;
  Duration timelineFrom = Duration.zero;

  @override
  void playTimeline(List<TimelineClip> clips, Duration from) {
    timelineClips = clips;
    timelineFrom = from;
  }

  @override
  void stopTimeline() => timelineClips = null;

  @override
  Duration get timelinePosition => timelineFrom;

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
      overrides: [
        audioEngineProvider.overrideWithValue(engine),
        localStorageProvider.overrideWithValue(storage),
        loggedUserIdProvider.overrideWithValue(1),
      ],
    );
    // No saved track: the current track starts as null without calling Jamendo
    await container.read(currentTrackProvider.future);
  });

  group('playbackProvider', () {
    group('queue', () {
      final List<Track> queue = [track('1'), track('2'), track('3')];

      /// Plays track [id] of [queue] and finishes its load.
      Future<void> playFromQueue(String id) async {
        final Future<void> playing = container
            .read(playbackProvider.notifier)
            .playTrack(queue.firstWhere((t) => t.id == id), queue: queue);
        engine.finish('https://example.com/$id.mp3');
        await playing;
      }

      /// Runs [move] and finishes the load of track [id] it starts.
      Future<void> moveTo(Future<void> Function(PlaybackNotifier controls) move, String id) async {
        final Future<void> moving = move(container.read(playbackProvider.notifier));
        await Future<void>.delayed(Duration.zero);
        engine.finish('https://example.com/$id.mp3');
        await moving;
      }

      test('next goes through the queue and starts again from the first after the last', () async {
        await playFromQueue('2');
        expect((container.read(playbackProvider).queueIndex, container.read(playbackProvider).hasQueue), (1, true));

        await moveTo((controls) => controls.next(), '3');
        expect(container.read(currentTrackProvider).value?.id, '3');

        await moveTo((controls) => controls.next(), '1');
        expect(container.read(playbackProvider).trackId, '1');
        expect(container.read(playbackProvider).status, PlaybackStatus.playing);
      });

      test('previous goes back, from the first to the last', () async {
        await playFromQueue('2');

        await moveTo((controls) => controls.previous(), '1');
        expect(container.read(playbackProvider).trackId, '1');

        await moveTo((controls) => controls.previous(), '3');
        expect(container.read(playbackProvider).trackId, '3');
      });

      test('after 3 seconds previous starts the track again', () async {
        await playFromQueue('2');
        container.read(playbackProvider.notifier).seek(const Duration(seconds: 10));

        await container.read(playbackProvider.notifier).previous();

        expect(container.read(playbackProvider).trackId, '2');
        expect(engine.seekedTo, Duration.zero);
      });

      test('the next track starts when one ends', () async {
        await playFromQueue('3');

        engine.ended = true;
        // The position is checked every 200 ms
        await Future<void>.delayed(const Duration(milliseconds: 250));
        engine.ended = false;
        engine.finish('https://example.com/1.mp3');
        await Future<void>.delayed(Duration.zero);

        expect(container.read(playbackProvider).trackId, '1');
        expect(container.read(playbackProvider).status, PlaybackStatus.playing);
      });

      test('a track played without a list has no queue to move through', () async {
        final Future<void> playing = container.read(playbackProvider.notifier).playTrack(track('1'));
        engine.finish('https://example.com/1.mp3');
        await playing;

        expect(container.read(playbackProvider).hasQueue, isFalse);
        await container.read(playbackProvider.notifier).next();
        expect(container.read(playbackProvider).trackId, '1');
      });
    });

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
      expect(storage.lastTrackIds[1], '1');
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
