import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../models/playlist.dart';
import '../providers/jamendo_provider.dart';
import '../theme/app_spacing.dart';
import '../widgets/heading.dart';
import '../widgets/track_list.dart';

/// A Jamendo playlist: cover, name and its tracks in order.
class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key, required this.playlist});

  final Playlist playlist;

  static const double _coverSize = 160;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TrackListScreen(
      tracks: ref.watch(playlistTracksProvider(playlist.id)),
      emptyMessage: 'This playlist has no tracks yet.',
      onRetry: () => ref.invalidate(playlistTracksProvider(playlist.id)),
      header: Column(
        spacing: AppSpacing.paddingMd,
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Image.asset(
                playlist.coverAsset,
                width: _coverSize,
                height: _coverSize,
                fit: BoxFit.cover,
                cacheWidth: (_coverSize * MediaQuery.devicePixelRatioOf(context)).round(),
              ),
            ),
          ),
          Heading(playlist.name, style: HeadingStyle.h2, uppercase: false, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
