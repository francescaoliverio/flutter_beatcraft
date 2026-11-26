import 'package:flutter_beatcraft/models/playlist.dart';
import 'package:flutter_beatcraft/models/track.dart';
import 'package:flutter_beatcraft/providers/auth_provider.dart';
import 'package:flutter_beatcraft/providers/jamendo_provider.dart';
import 'package:flutter_beatcraft/providers/local_storage_provider.dart';
import 'package:flutter_beatcraft/providers/playback_provider.dart';
import 'package:flutter_beatcraft/screens/playlist_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/playback_provider_test.dart' show FakeAudioEngine, FakeLocalStorage, track;

void main() {
  const Playlist playlist = Playlist(id: '11696', name: 'Instrumental', mood: CoverMood.calm);
  late ProviderContainer container;

  Future<void> showPlaylist(WidgetTester tester, List<Track> tracks) async {
    tester.view.physicalSize = const Size(1200, 2600);
    addTearDown(tester.view.resetPhysicalSize);
    container = ProviderContainer.test(
      overrides: [
        playlistTracksProvider(playlist.id).overrideWith((ref) async => tracks),
        audioEngineProvider.overrideWithValue(FakeAudioEngine()),
        localStorageProvider.overrideWithValue(FakeLocalStorage()),
        loggedUserIdProvider.overrideWithValue(1),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlaylistScreen(playlist: playlist)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the tracks with their count, and a track plays with the playlist as the queue', (tester) async {
    await showPlaylist(tester, [track('1'), track('2'), track('3')]);

    expect(find.text('Instrumental'), findsOneWidget);
    expect(find.text('3 tracks'), findsOneWidget);

    await tester.tap(find.text('Track 2'));
    await tester.pump();

    final PlaybackState playback = container.read(playbackProvider);
    expect(playback.queue.map((t) => t.id), ['1', '2', '3']);
    expect(playback.queueIndex, 1);
  });

  testWidgets('Play starts from the first track', (tester) async {
    await showPlaylist(tester, [track('1'), track('2')]);

    // Read as "Play all" by screen readers
    expect(find.bySemanticsLabel('Play all'), findsOneWidget);
    await tester.tap(find.text('Play'));
    await tester.pump();

    expect(container.read(playbackProvider).trackId, '1');
  });

  testWidgets('an empty playlist says so', (tester) async {
    await showPlaylist(tester, []);

    expect(find.text('This playlist has no tracks yet.'), findsOneWidget);
    expect(find.bySemanticsLabel('Play all'), findsNothing);
  });
}
