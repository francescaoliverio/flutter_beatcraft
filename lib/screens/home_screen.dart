import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/jamendo_provider.dart';
import '../providers/playback_provider.dart';
import '../services/jamendo_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/error_box.dart';
import '../widgets/heading.dart';
import '../widgets/media_card.dart';
import '../widgets/media_section.dart';
import '../widgets/skeleton.dart';
import 'player_screen.dart';

/// Home feed: new releases, trending artists, playlists from Jamendo.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Plays [track] with the row it is in as the queue, and opens the player.
  void _openTrack(BuildContext context, WidgetRef ref, Track track, List<Track>? row) {
    ref.read(playbackProvider.notifier).playTrack(track, queue: row);
    showPlayer(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ListView(
        // No side padding: MediaSection rows reach the screen edges and add their own margin
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingLg),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.paddingLg),
            child: Heading('Home'),
          ),
          const SizedBox(height: AppSpacing.paddingLg),
          MediaSection<Track>(
            title: 'New releases',
            items: ref.watch(newReleasesProvider),
            itemBuilder: (track) => MediaCard(
              image: NetworkImage(track.image),
              fallbackImage: AssetImage(track.fallbackCoverAsset),
              title: track.name,
              subtitle: track.artistName,
              onTap: () => _openTrack(context, ref, track, ref.read(newReleasesProvider).value),
            ),
            errorBuilder: (error) => _ErrorForSection(
              error: error,
              title: "Couldn't load new releases",
              onRetry: () => ref.invalidate(newReleasesProvider),
            ),
          ),
          const SizedBox(height: AppSpacing.paddingLg),
          MediaSection<Track>(
            title: 'Ready to remix',
            items: ref.watch(readyToRemixProvider),
            itemBuilder: (track) => MediaCard(
              image: NetworkImage(track.image),
              fallbackImage: AssetImage(track.fallbackCoverAsset),
              title: track.name,
              subtitle: track.artistName,
              onTap: () => _openTrack(context, ref, track, ref.read(readyToRemixProvider).value),
            ),
            errorBuilder: (error) => _ErrorForSection(
              error: error,
              title: "Couldn't load tracks to remix",
              onRetry: () => ref.invalidate(readyToRemixProvider),
            ),
          ),
          const SizedBox(height: AppSpacing.paddingLg),
          MediaSection<Artist>(
            title: 'Trending artists',
            items: ref.watch(trendingArtistsProvider),
            skeletonShape: SkeletonShape.circle,
            itemBuilder: (artist) =>
                MediaCard(image: NetworkImage(artist.image), title: artist.name, shape: MediaCardShape.circle),
            errorBuilder: (error) => _ErrorForSection(
              error: error,
              title: "Couldn't load artists",
              onRetry: () => ref.invalidate(trendingArtistsProvider),
            ),
          ),
          const SizedBox(height: AppSpacing.paddingLg),
          MediaSection<Playlist>(
            title: 'Playlists',
            items: ref.watch(playlistsProvider),
            // TODO: tappable when the playlist screen exists
            itemBuilder: (playlist) => MediaCard(image: AssetImage(playlist.coverAsset), title: playlist.name),
            errorBuilder: (error) => _ErrorForSection(
              error: error,
              title: "Couldn't load playlists",
              onRetry: () => ref.invalidate(playlistsProvider),
            ),
          ),
        ],
      ),
    );
  }
}

/// ErrorBox with the texts for the kind of Jamendo failure.
class _ErrorForSection extends StatelessWidget {
  const _ErrorForSection({required this.error, required this.title, required this.onRetry});

  final Object error;

  /// Used for network and API errors.
  final String title;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final JamendoFailure failure = error is JamendoException
        ? (error as JamendoException).failure
        : JamendoFailure.other;
    return switch (failure) {
      JamendoFailure.missingClientId => ErrorBox(
        title: 'Jamendo key missing',
        description: 'Add JAMENDO_CLIENT_ID to .env and run with --dart-define-from-file=.env.',
        onRetry: onRetry,
      ),
      JamendoFailure.invalidClientId => ErrorBox(
        title: 'Jamendo key not valid',
        description: 'Check JAMENDO_CLIENT_ID in .env.',
        onRetry: onRetry,
      ),
      JamendoFailure.empty => ErrorBox(
        title: 'Nothing to show right now',
        description: 'Try again in a moment.',
        onRetry: onRetry,
      ),
      JamendoFailure.other => ErrorBox(
        title: title,
        description: 'Check your connection and try again.',
        onRetry: onRetry,
      ),
    };
  }
}
