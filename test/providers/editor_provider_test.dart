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
}
