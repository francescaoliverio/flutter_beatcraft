import 'package:flutter_beatcraft/models/playlist.dart';
import 'package:flutter_beatcraft/providers/auth_provider.dart';
import 'package:flutter_beatcraft/providers/editor_provider.dart';
import 'package:flutter_beatcraft/providers/favorites_provider.dart';
import 'package:flutter_beatcraft/providers/jamendo_provider.dart';
import 'package:flutter_beatcraft/providers/local_storage_provider.dart';
import 'package:flutter_beatcraft/providers/playback_provider.dart';
import 'package:flutter_beatcraft/screens/main_shell.dart';
import 'package:flutter_beatcraft/screens/playlist_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/playback_provider_test.dart' show FakeAudioEngine, FakeLocalStorage, track;

/// Lets loads and page transitions finish. Not pumpAndSettle: a tab keeps a loading animation running.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  const Playlist playlist = Playlist(id: '11696', name: 'Instrumental', mood: CoverMood.calm);

  testWidgets('a playlist opens inside the Home tab and stays there when another tab is chosen', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playlistsProvider.overrideWith((ref) async => [playlist]),
          newReleasesProvider.overrideWith((ref) async => []),
          readyToRemixProvider.overrideWith((ref) async => []),
          trendingArtistsProvider.overrideWith((ref) async => []),
          playlistTracksProvider(playlist.id).overrideWith((ref) async => [track('1')]),
          favoriteTracksProvider.overrideWith((ref) async => []),
          audioEngineProvider.overrideWithValue(FakeAudioEngine()),
          editorEngineProvider.overrideWithValue(FakeAudioEngine()),
          localStorageProvider.overrideWithValue(FakeLocalStorage()),
          loggedUserIdProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Instrumental'));
    await settle(tester);
    expect(find.byType(PlaylistScreen), findsOneWidget);
    // The bottom navigation stays below the playlist
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Create'));
    await settle(tester);
    // Kept in the Home tab, not drawn over Create
    expect(find.byType(PlaylistScreen, skipOffstage: true), findsNothing);
    expect(find.byType(PlaylistScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Home'));
    await settle(tester);
    expect(find.byType(PlaylistScreen), findsOneWidget);
  });
}
