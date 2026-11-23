import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import '../services/jamendo_service.dart';
import '../services/local_storage.dart';
import 'jamendo_provider.dart';

final localStorageProvider = Provider<LocalStorage>((ref) => LocalStorage(SharedPreferencesAsync()));

/// Track shown in the player and mini player: null when nothing was played yet.
/// Only its id is saved on the device; at launch the track is fetched again from Jamendo.
class CurrentTrackNotifier extends AsyncNotifier<Track?> {
  @override
  Future<Track?> build() async {
    final String? id = await ref.read(localStorageProvider).readLastTrackId();
    if (id == null) return null;
    try {
      return await ref.read(jamendoServiceProvider).trackById(id);
    } on JamendoException {
      // The last track can't be restored: start with nothing playing
      return null;
    }
  }

  Future<void> select(Track track) async {
    state = AsyncData(track);
    await ref.read(localStorageProvider).saveLastTrackId(track.id);
  }
}

final currentTrackProvider = AsyncNotifierProvider<CurrentTrackNotifier, Track?>(
  CurrentTrackNotifier.new,
  // Failures already end in null, nothing to retry
  retry: (_, _) => null,
);
