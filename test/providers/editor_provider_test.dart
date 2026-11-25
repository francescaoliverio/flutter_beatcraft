import 'dart:async';

import 'package:flutter_beatcraft/models/timeline_clip.dart';
import 'package:flutter_beatcraft/providers/editor_provider.dart';
import 'package:flutter_beatcraft/providers/local_storage_provider.dart';
import 'package:flutter_beatcraft/providers/playback_provider.dart';
import 'package:flutter_beatcraft/providers/player_provider.dart';
import 'package:flutter_beatcraft/providers/remix_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'playback_provider_test.dart' show FakeAudioEngine, FakeLocalStorage, track;

void main() {
  late FakeAudioEngine playerEngine;
  late FakeAudioEngine editorEngine;
  late ProviderContainer container;

  setUp(() async {
    playerEngine = FakeAudioEngine();
    editorEngine = FakeAudioEngine();
    container = ProviderContainer.test(
      overrides: [
        audioEngineProvider.overrideWithValue(playerEngine),
        editorEngineProvider.overrideWithValue(editorEngine),
        localStorageProvider.overrideWithValue(FakeLocalStorage()),
      ],
    );
    await container.read(currentTrackProvider.future);
    // Keeps the editor alive between reads
    container.listen(editorProvider, (_, _) {});
  });

  /// Chooses track 1 for remixing and finishes its load.
  Future<EditorState> openEditor() async {
    container.read(remixTrackProvider.notifier).select(track('1'));
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

    test('a moved clip keeps its audio and goes on top', () {
      editor
        ..seek(s(60))
        ..split();
      final int leftId = current().clips.first.id;

      editor.move(leftId, s(150));

      final TimelineClip moved = current().clips.last;
      expect(moved.id, leftId);
      expect((moved.sourceStart, moved.timelineStart), (s(0), s(150)));
      expect(current().length, s(210));
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
}
