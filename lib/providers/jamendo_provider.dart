import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/jamendo_service.dart';
import 'http_client_provider.dart';

/// Items per Home section.
const int homeSectionLength = 7;

/// Playlist keyword and how many playlists to take for each cover mood. The counts add up to [homeSectionLength].
const Map<CoverMood, ({String query, int count})> _playlistMoods = {
  CoverMood.bright: (query: 'happy', count: 2),
  CoverMood.calm: (query: 'chill', count: 2),
  CoverMood.dark: (query: 'dark', count: 2),
  CoverMood.punchy: (query: 'energy', count: 1),
};

/// JamendoService already retries empty results: Riverpod's automatic retry is turned off.
Duration? _noRetry(int _, Object _) => null;

final jamendoServiceProvider = Provider<JamendoService>((ref) {
  return JamendoService(ref.watch(httpClientProvider), const String.fromEnvironment('JAMENDO_CLIENT_ID'));
});

final newReleasesProvider = FutureProvider<List<Track>>(
  (ref) => ref.watch(jamendoServiceProvider).newReleases(limit: homeSectionLength),
  retry: _noRetry,
);

final readyToRemixProvider = FutureProvider<List<Track>>(
  (ref) => ref.watch(jamendoServiceProvider).readyToRemix(limit: homeSectionLength),
  retry: _noRetry,
);

final trendingArtistsProvider = FutureProvider<List<Artist>>(
  (ref) => ref.watch(jamendoServiceProvider).trendingArtists(limit: homeSectionLength),
  retry: _noRetry,
);

/// One search per mood, in parallel. Playlists with the same name (case-insensitive) are shown once.
final playlistsProvider = FutureProvider<List<Playlist>>((ref) async {
  final JamendoService service = ref.watch(jamendoServiceProvider);

  // Fetch a few more than needed, to have spares after removing duplicates
  final List<List<Playlist>> perMood = await Future.wait(
    _playlistMoods.entries.map((entry) async {
      try {
        return await service.searchPlaylists(entry.value.query, entry.key, limit: entry.value.count + 3);
      } on JamendoException catch (e) {
        // A mood without results doesn't hide the other moods
        if (e.failure == JamendoFailure.empty) return <Playlist>[];
        rethrow;
      }
    }),
  );

  final Set<String> seenNames = {};
  final List<Playlist> playlists = [];
  for (final (int i, List<Playlist> candidates) in perMood.indexed) {
    final int count = _playlistMoods.values.elementAt(i).count;
    playlists.addAll(candidates.where((p) => seenNames.add(p.name.toLowerCase())).take(count));
  }

  if (playlists.isEmpty) throw const JamendoException(JamendoFailure.empty);
  return playlists;
}, retry: _noRetry);
