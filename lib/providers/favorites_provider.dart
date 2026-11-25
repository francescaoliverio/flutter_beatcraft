import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/track.dart';
import 'jamendo_provider.dart';
import 'local_storage_provider.dart';

/// Ids of the liked tracks, newest first, saved on the device.
class FavoritesNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() => ref.read(localStorageProvider).readFavoriteTrackIds();

  /// Likes the track, or removes the like if it is already there.
  Future<void> toggle(String trackId) async {
    // state.value is read synchronously once loaded, so quick taps don't work on the same old list
    final List<String> ids = state.value ?? await future;
    final List<String> updated = ids.contains(trackId) ? ids.where((id) => id != trackId).toList() : [trackId, ...ids];
    state = AsyncData(updated);
    await ref.read(localStorageProvider).saveFavoriteTrackIds(updated);
  }
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, List<String>>(FavoritesNotifier.new);

/// Liked tracks for the profile, fetched again from Jamendo when the likes change.
final favoriteTracksProvider = FutureProvider<List<Track>>(
  (ref) async => ref.watch(jamendoServiceProvider).tracksByIds(await ref.watch(favoritesProvider.future)),
  // JamendoService already retries empty results
  retry: (_, _) => null,
);
