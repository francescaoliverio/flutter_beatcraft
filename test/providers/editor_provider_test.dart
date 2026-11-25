import 'dart:async';

import 'package:flutter_beatcraft/models/remix_project.dart';
import 'package:flutter_beatcraft/models/timeline_clip.dart';
import 'package:flutter_beatcraft/providers/auth_provider.dart';
import 'package:flutter_beatcraft/providers/editor_provider.dart';
import 'package:flutter_beatcraft/providers/jamendo_provider.dart';
import 'package:flutter_beatcraft/providers/local_storage_provider.dart';
import 'package:flutter_beatcraft/providers/playback_provider.dart';
import 'package:flutter_beatcraft/providers/player_provider.dart';
import 'package:flutter_beatcraft/providers/remix_provider.dart';
import 'package:flutter_beatcraft/services/jamendo_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../models/jamendo_models_test.dart' show trackJson;
import '../services/jamendo_service_test.dart' show body;

import 'playback_provider_test.dart' show FakeAudioEngine, FakeLocalStorage, track;

void main() {
  late FakeAudioEngine playerEngine;
  late FakeAudioEngine editorEngine;
  late FakeLocalStorage storage;
  late ProviderContainer container;

  setUp(() async {
    playerEngine = FakeAudioEngine();
    editorEngine = FakeAudioEngine();
    storage = FakeLocalStorage();
    container = ProviderContainer.test(
      overrides: [
        audioEngineProvider.overrideWithValue(playerEngine),
        editorEngineProvider.overrideWithValue(editorEngine),
        localStorageProvider.overrideWithValue(storage),
        loggedUserIdProvider.overrideWithValue(1),
      ],
    );
    await container.read(currentTrackProvider.future);
    // Keeps the editor alive between reads
    container.listen(editorProvider, (_, _) {});
  });

  /// Chooses track 1 for remixing and finishes its load.
  Future<EditorState> openEditor() async {
    container.read(remixProvider.notifier).newRemix(track('1'));
    final Future<EditorState?> loaded = container.read(editorProvider.future);
    await Future<void>.delayed(Duration.zero);
    editorEngine.finish('https://example.com/1.mp3');
    return (await loaded)!;
  }

  test('without a track to remix there is no editor', () async {
    expect(await container.read(editorProvider.future), isNull);
  });

  test('a new remix starts with the whole track as one clip', () async {
    final EditorState editor = await openEditor();

    final TimelineClip clip = editor.clips.single;
    expect(clip.sourceStart, Duration.zero);
    expect(clip.sourceEnd, const Duration(minutes: 3));
    expect(clip.timelineStart, Duration.zero);
    expect(editor.length, const Duration(minutes: 3));
  });

  test('play starts the timeline from the playhead and pauses the player', () async {
    await openEditor();
    final PlaybackNotifier player = container.read(playbackProvider.notifier);
    unawaited(player.playTrack(track('2')));
    playerEngine.finish('https://example.com/2.mp3');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(playbackProvider).isPlaying, isTrue);

    container.read(editorProvider.notifier)
      ..seek(const Duration(seconds: 30))
      ..play();

    expect(editorEngine.timelineFrom, const Duration(seconds: 30));
    expect(editorEngine.timelineClips, hasLength(1));
    expect(container.read(playbackProvider).isPlaying, isFalse);
  });

  test('the player starting pauses the timeline', () async {
    await openEditor();
    container.read(editorProvider.notifier).play();

    unawaited(container.read(playbackProvider.notifier).playTrack(track('2')));
    playerEngine.finish('https://example.com/2.mp3');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(editorProvider).value!.isPlaying, isFalse);
    expect(editorEngine.timelineClips, isNull);
  });

  group('editing', () {
    late EditorNotifier editor;

    EditorState current() => container.read(editorProvider).value!;

    Duration s(int seconds) => Duration(seconds: seconds);

    setUp(() async {
      await openEditor();
      editor = container.read(editorProvider.notifier);
    });

    test('split cuts the clip at the playhead and selects the right part', () {
      editor
        ..seek(s(60))
        ..split();

      final List<TimelineClip> clips = current().clips;
      expect(clips, hasLength(2));
      expect((clips[0].sourceStart, clips[0].sourceEnd, clips[0].timelineStart), (s(0), s(60), s(0)));
      expect((clips[1].sourceStart, clips[1].sourceEnd, clips[1].timelineStart), (s(60), s(180), s(60)));
      expect(current().selectedClipId, clips[1].id);
    });

    test('split does nothing at the very edge of a clip', () {
      editor.split();

      expect(current().clips, hasLength(1));
      expect(current().canUndo, isFalse);
    });

    test('a clip moved to a free space keeps its audio and goes on top', () {
      editor
        ..seek(s(60))
        ..split();
      final int leftId = current().clips.first.id;

      editor.move(leftId, s(200));

      final TimelineClip moved = current().clips.last;
      expect(moved.id, leftId);
      expect((moved.sourceStart, moved.timelineStart), (s(0), s(200)));
      expect(current().length, s(260));
    });

    test('dropped on the second half of a clip, a clip is inserted after it', () {
      editor
        ..seek(s(60))
        ..split();
      final int leftId = current().clips.first.id;

      // Right part is 60-180: 150 is in its second half
      editor.move(leftId, s(150));

      expect(current().clips.firstWhere((c) => c.id == leftId).timelineStart, s(180));
    });

    test('dropped on the first half of a clip, a clip is inserted before it and the rest moves right', () {
      // Three clips of 60 s back to back: A 0-60, B 60-120, C 120-180
      editor
        ..seek(s(60))
        ..split()
        ..seek(s(120))
        ..split();
      final [TimelineClip a, TimelineClip b, TimelineClip c] = current().clips;

      // C dropped on the first half of A
      editor.move(c.id, s(10));

      TimelineClip byId(int id) => current().clips.firstWhere((clip) => clip.id == id);
      expect(byId(c.id).timelineStart, s(0));
      expect(byId(a.id).timelineStart, s(60));
      expect(byId(b.id).timelineStart, s(120));
      // C left 120-180 free and B moved into it: still a row without gaps
      expect(current().hasGaps, isFalse);
    });

    test('close gaps puts the clips in a row from the start, in timeline order', () {
      editor
        ..seek(s(60))
        ..split();
      final [TimelineClip left, TimelineClip right] = current().clips;
      editor.move(left.id, s(200));
      expect(current().hasGaps, isTrue);

      editor.closeGaps();

      TimelineClip byId(int id) => current().clips.firstWhere((clip) => clip.id == id);
      expect(byId(right.id).timelineStart, Duration.zero);
      expect(byId(left.id).timelineStart, s(120));
      expect(current().hasGaps, isFalse);

      editor.undo();
      expect(byId(left.id).timelineStart, s(200));
    });

    test('nudge stops against the next clip instead of pushing it', () {
      editor
        ..seek(s(60))
        ..split();
      final [TimelineClip left, TimelineClip right] = current().clips;

      editor.nudge(left.id, s(1));

      expect(current().clips.firstWhere((c) => c.id == left.id).timelineStart, Duration.zero);
      expect(current().clips.firstWhere((c) => c.id == right.id).timelineStart, s(60));

      editor.nudge(right.id, s(1));
      expect(current().clips.firstWhere((c) => c.id == right.id).timelineStart, s(61));
    });

    test('a clip cannot move before the start', () {
      editor.move(current().clips.single.id, -s(5));

      // Already at 0: nothing changed, nothing to undo
      expect(current().clips.single.timelineStart, Duration.zero);
      expect(current().canUndo, isFalse);
    });

    test('duplicate puts a copy at the end, delete removes the selection', () {
      editor
        ..select(current().clips.single.id)
        ..duplicateSelected();

      expect(current().clips, hasLength(2));
      expect(current().clips.last.timelineStart, s(180));
      expect(current().length, s(360));

      editor.deleteSelected();

      expect(current().clips, hasLength(1));
      expect(current().selectedClipId, isNull);
    });

    test('undo and redo walk through the edits', () {
      editor
        ..seek(s(60))
        ..split()
        ..deleteSelected();
      expect(current().clips, hasLength(1));

      editor.undo();
      expect(current().clips, hasLength(2));
      expect(current().canRedo, isTrue);

      editor.undo();
      expect(current().clips, hasLength(1));
      expect(current().canUndo, isFalse);

      editor
        ..redo()
        ..redo();
      expect(current().clips, hasLength(1));
      expect(current().clips.single.sourceEnd, s(60));
    });

    test('an edit while playing is heard at once', () {
      editor
        ..play()
        ..seek(s(60))
        ..split()
        ..select(current().clips.first.id)
        ..deleteSelected();

      // Only the right part is left, still playing from the playhead
      expect(editorEngine.timelineClips, hasLength(1));
      expect(editorEngine.timelineClips!.single.sourceStart, s(60));
      expect(editorEngine.timelineFrom, s(60));
      expect(current().isPlaying, isTrue);
    });

    test('deleting every clip stops the timeline', () {
      editor
        ..play()
        ..select(current().clips.single.id)
        ..deleteSelected();

      expect(current().isPlaying, isFalse);
      expect(current().length, Duration.zero);
      expect(editorEngine.timelineClips, isNull);
    });
  });

  group('projects', () {
    test('a new remix is unsaved and named after its track', () async {
      final EditorState editor = await openEditor();

      expect(editor.name, 'Track 1 remix');
      expect(editor.projectId, isNull);
      expect(editor.hasUnsavedChanges, isTrue);
    });

    test('save stores track id and clips, then edits mark it unsaved again', () async {
      await openEditor();
      final EditorNotifier editor = container.read(editorProvider.notifier)..rename('  Night remix ');

      await editor.save();

      final RemixProject saved = storage.remixProjects[1]!.single;
      expect((saved.name, saved.trackId, saved.clips.length), ('Night remix', '1', 1));
      expect(container.read(editorProvider).value!.projectId, saved.id);
      expect(container.read(editorProvider).value!.hasUnsavedChanges, isFalse);

      editor
        ..seek(const Duration(seconds: 60))
        ..split();
      expect(container.read(editorProvider).value!.hasUnsavedChanges, isTrue);

      // Saving again updates the same project
      await editor.save();
      expect(storage.remixProjects[1]!.single.clips, hasLength(2));
    });

    /// A saved project of the track in [trackJson], with one clip.
    RemixProject savedProject() => RemixProject(
      id: '42',
      name: 'Saved remix',
      trackId: '2353774',
      clips: const [
        TimelineClip(id: 7, sourceStart: Duration.zero, sourceEnd: Duration(seconds: 10), timelineStart: Duration.zero),
      ],
      updatedAt: DateTime.utc(2026, 11, 25),
    );

    /// Jamendo answering with [trackJson] built from [json].
    void jamendoReturns(Map<String, dynamic> json) {
      container = ProviderContainer.test(
        overrides: [
          audioEngineProvider.overrideWithValue(playerEngine),
          editorEngineProvider.overrideWithValue(editorEngine),
          localStorageProvider.overrideWithValue(storage),
          loggedUserIdProvider.overrideWithValue(1),
          jamendoServiceProvider.overrideWithValue(
            JamendoService(MockClient((_) async => http.Response(body(results: [json]), 200)), 'test-id'),
          ),
        ],
      );
      container.listen(editorProvider, (_, _) {});
    }

    test('a saved project reopens with its name, clips and track', () async {
      jamendoReturns(trackJson());
      container.read(remixProvider.notifier).open(savedProject());
      final Future<EditorState?> loaded = container.read(editorProvider.future);
      // Jamendo answers (a few async steps through the mock client), then the engine starts loading the track
      for (int i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      editorEngine.finish(trackJson()['audio'] as String);

      final EditorState editor = (await loaded)!;
      expect((editor.name, editor.projectId, editor.hasUnsavedChanges), ('Saved remix', '42', false));
      expect(editor.clips.single.id, 7);
      expect(editor.track.id, '2353774');

      // New clips get ids after the saved ones
      container.read(editorProvider.notifier)
        ..seek(const Duration(seconds: 5))
        ..split();
      expect(container.read(editorProvider).value!.clips.last.id, 8);
    });

    test('a project whose track can no longer be remixed does not open', () async {
      jamendoReturns(trackJson(license: 'http://creativecommons.org/licenses/by-nd/3.0/'));
      container.read(remixProvider.notifier).open(savedProject());

      await expectLater(container.read(editorProvider.future), throwsA(isA<RemixUnavailableException>()));
    });
  });
}
