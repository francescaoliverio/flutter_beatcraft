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

  test('the playhead goes into the free space after the content, not past it', () async {
    final EditorState opened = await openEditor();
    final EditorNotifier editor = container.read(editorProvider.notifier);
    // 3 min track: a quarter of it, 45 s, of free space after the end
    expect(opened.timelineLength, const Duration(minutes: 3, seconds: 45));

    editor.seek(const Duration(minutes: 3, seconds: 20));
    expect(container.read(editorProvider).value!.position, const Duration(minutes: 3, seconds: 20));

    editor.seek(const Duration(minutes: 10));
    expect(container.read(editorProvider).value!.position, const Duration(minutes: 3, seconds: 45));
  });

  test('a seek after the last clip while playing stops the timeline there', () async {
    await openEditor();
    final EditorNotifier editor = container.read(editorProvider.notifier)..play();

    editor.seek(const Duration(minutes: 3, seconds: 20));

    final EditorState state = container.read(editorProvider).value!;
    expect((state.isPlaying, state.position), (false, const Duration(minutes: 3, seconds: 20)));
    expect(editorEngine.timelineClips, isNull);
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

    test('paste puts a copy of the copied clip at the playhead, delete removes the selection', () {
      editor
        ..seek(s(60))
        ..split();
      final TimelineClip right = current().clips.last;
      editor
        ..select(right.id)
        ..copySelected();
      // Copying is not an edit
      expect(current().canPaste, isTrue);

      // In the free space after the content: the copy goes exactly there
      editor
        ..seek(s(200))
        ..paste();

      final TimelineClip copy = current().clips.last;
      expect((copy.sourceStart, copy.sourceEnd, copy.timelineStart), (s(60), s(180), s(200)));
      expect(copy.id, isNot(right.id));
      expect(current().selectedClipId, copy.id);

      editor.deleteSelected();

      expect(current().clips, hasLength(2));
      expect(current().selectedClipId, isNull);
    });

    test('pasted on a clip, the copy goes before or after it and the following clips move to make room', () {
      // A 0-60, B 60-180
      editor
        ..seek(s(60))
        ..split();
      final [TimelineClip a, TimelineClip b] = current().clips;
      editor
        ..select(a.id)
        ..copySelected()
        // 100 is in the first half of B: the copy goes at 60 and B moves right by 60
        ..seek(s(100))
        ..paste();

      TimelineClip byId(int id) => current().clips.firstWhere((clip) => clip.id == id);
      expect(current().clips.last.timelineStart, s(60));
      expect(byId(b.id).timelineStart, s(120));
      expect(current().hasGaps, isFalse);
    });

    test('a clip that only reaches the next ones pushes them just enough, keeping their gaps', () {
      // A 0-20, then B 30-50 and C 60-180 with gaps, built by splitting and moving
      editor
        ..seek(s(20))
        ..split()
        ..seek(s(40))
        ..split();
      final [TimelineClip a, TimelineClip b, TimelineClip c] = current().clips;
      editor
        ..move(c.id, s(60))
        ..move(b.id, s(30));
      TimelineClip byId(int id) => current().clips.firstWhere((clip) => clip.id == id);
      expect((byId(b.id).timelineStart, byId(c.id).timelineStart), (s(30), s(60)));

      // A copy of A (20 s) pasted at 25, in the gap: it would cover B by 15 s, so B and C move right by 15
      editor
        ..select(a.id)
        ..copySelected()
        ..seek(s(25))
        ..paste();

      expect(current().clips.last.timelineStart, s(25));
      expect(byId(b.id).timelineStart, s(45));
      expect(byId(c.id).timelineStart, s(75));

      // A copy pasted where it covers nothing moves nothing
      editor
        ..seek(s(200))
        ..paste();
      expect(byId(c.id).timelineStart, s(75));
    });

    test('a dragged clip that only reaches the next one pushes it just enough', () {
      // A 0-60, B 60-180, then A moved away to 200: B 60-180 is alone
      editor
        ..seek(s(60))
        ..split();
      final [TimelineClip a, TimelineClip b] = current().clips;
      editor.move(a.id, s(200));

      // A (60 s) dropped at 10, in the free space before B: it would cover B by 10 s
      editor.move(a.id, s(10));

      TimelineClip byId(int id) => current().clips.firstWhere((clip) => clip.id == id);
      expect(byId(a.id).timelineStart, s(10));
      expect(byId(b.id).timelineStart, s(70));
    });

    test('a copied clip is not kept for another remix', () async {
      editor
        ..select(current().clips.single.id)
        ..copySelected();

      await openEditor();

      expect(current().canPaste, isFalse);
      container.read(editorProvider.notifier).paste();
      expect(current().clips, hasLength(1));
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
      cover: 4,
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
      expect((editor.name, editor.projectId, editor.cover, editor.hasUnsavedChanges), ('Saved remix', '42', 4, false));
      expect(editor.clips.single.id, 7);
      expect(editor.track.id, '2353774');

      // New clips get ids after the saved ones
      container.read(editorProvider.notifier)
        ..seek(const Duration(seconds: 5))
        ..split();
      expect(container.read(editorProvider).value!.clips.last.id, 8);
    });

    test('deleting the open remix makes it unsaved, Undo makes it saved again', () async {
      await openEditor();
      final EditorNotifier editor = container.read(editorProvider.notifier);
      await editor.save();
      final RemixProject saved = storage.remixProjects[1]!.single;
      final RemixProjectsNotifier projects = container.read(remixProjectsProvider.notifier);

      await projects.delete(saved.id);
      expect(container.read(editorProvider).value!.hasUnsavedChanges, isTrue);

      // Undo in the profile saves the same project back
      await projects.save(saved);
      expect(container.read(editorProvider).value!.hasUnsavedChanges, isFalse);

      // Edited after the delete, it stays unsaved when the old version comes back
      await projects.delete(saved.id);
      editor
        ..seek(const Duration(seconds: 60))
        ..split();
      await projects.save(saved);
      expect(container.read(editorProvider).value!.hasUnsavedChanges, isTrue);
    });

    test('undo of a first save removes the project, undo of a later save puts the old version back', () async {
      await openEditor();
      final EditorNotifier editor = container.read(editorProvider.notifier);
      final RemixProjectsNotifier projects = container.read(remixProjectsProvider.notifier);

      final SavedRemix first = (await editor.save())!;
      expect(first.previous, isNull);
      await projects.revert(first.projectId, first.previous);
      expect(storage.remixProjects[1], isEmpty);
      expect(container.read(editorProvider).value!.hasUnsavedChanges, isTrue);

      await editor.save();
      editor
        ..seek(const Duration(seconds: 60))
        ..split();
      final SavedRemix second = (await editor.save())!;
      expect(second.previous!.clips, hasLength(1));
      await projects.revert(second.projectId, second.previous);
      expect(storage.remixProjects[1]!.single.clips, hasLength(1));
      // The editor still has two clips, so it is no longer saved
      expect(container.read(editorProvider).value!.hasUnsavedChanges, isTrue);
    });

    test('a second remix of the same track gets the first free number', () async {
      await openEditor();
      await container.read(editorProvider.notifier).save();

      expect((await openEditor()).name, 'Track 1 remix 2');
      await container.read(editorProvider.notifier).save();

      expect((await openEditor()).name, 'Track 1 remix 3');
    });

    test('a name used by another remix of the user is not saved', () async {
      await openEditor();
      await container.read(editorProvider.notifier).save();
      await openEditor();
      // As if a rename had skipped the dialog check
      final EditorNotifier editor = container.read(editorProvider.notifier)..rename(' TRACK 1 remix');

      expect(await editor.save(), isNull);
      expect(storage.remixProjects[1], hasLength(1));
    });

    test('the cover is saved, and changing it makes the remix unsaved', () async {
      final EditorState opened = await openEditor();
      expect(opened.cover, inInclusiveRange(1, RemixProject.coverCount));
      final EditorNotifier editor = container.read(editorProvider.notifier);
      await editor.save();

      final int other = opened.cover % RemixProject.coverCount + 1;
      editor.setCover(other);
      expect(container.read(editorProvider).value!.hasUnsavedChanges, isTrue);
      await editor.save();
      expect(storage.remixProjects[1]!.single.cover, other);
    });

    test('a project whose track can no longer be remixed does not open', () async {
      jamendoReturns(trackJson(license: 'http://creativecommons.org/licenses/by-nd/3.0/'));
      container.read(remixProvider.notifier).open(savedProject());

      await expectLater(container.read(editorProvider.future), throwsA(isA<RemixUnavailableException>()));
    });
  });
}
