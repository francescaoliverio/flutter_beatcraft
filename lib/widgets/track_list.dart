import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../models/track.dart';
import '../providers/playback_provider.dart';
import '../screens/player_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'button.dart';
import 'empty_state.dart';
import 'error_box.dart';
import 'skeleton.dart';

/// Minutes and seconds, e.g. 3:08.
String _formatTime(Duration time) => '${time.inMinutes}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';

/// Number of tracks and their total time, e.g. "35 tracks · 2 h 10 min".
String trackListSummary(List<Track> tracks) {
  final String count = '${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'}';
  final Duration total = tracks.fold(Duration.zero, (sum, track) => sum + (track.duration ?? Duration.zero));
  if (total == Duration.zero) return count;
  final int minutes = total.inMinutes % 60;
  return total.inHours > 0 ? '$count · ${total.inHours} h $minutes min' : '$count · ${total.inMinutes} min';
}

/// Plays [track] with [tracks] as the queue, and opens the player.
void _play(BuildContext context, WidgetRef ref, Track track, List<Track> tracks) {
  ref.read(playbackProvider.notifier).playTrack(track, queue: tracks);
  showPlayer(context);
}

/// A screen with a header and a list of tracks (a playlist, an artist): back arrow, [header], count and length
/// next to Play, and the tracks. A track plays with the whole list as the queue.
/// Opened inside the Home tab, so the mini player and the bottom navigation stay below it.
class TrackListScreen extends ConsumerWidget {
  const TrackListScreen({
    super.key,
    required this.header,
    required this.tracks,
    required this.emptyMessage,
    required this.onRetry,
  });

  final Widget header;
  final AsyncValue<List<Track>> tracks;
  final String emptyMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Track>? loaded = tracks.isLoading ? null : tracks.value;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.paddingLg, 0, AppSpacing.paddingLg, AppSpacing.paddingLg),
        children: [
          header,
          const SizedBox(height: AppSpacing.paddingMd),
          if (tracks.isLoading)
            Semantics(
              label: 'Loading tracks',
              child: Column(
                spacing: AppSpacing.paddingSm,
                children: [for (int i = 0; i < 5; i++) const Skeleton(height: _TrackRow.coverSize)],
              ),
            )
          else if (tracks.hasError)
            ErrorBox(
              title: "Couldn't load the tracks",
              description: 'Check your connection and try again.',
              onRetry: onRetry,
            )
          else if (loaded == null || loaded.isEmpty)
            EmptyState(message: emptyMessage)
          else ...[
            Row(
              spacing: AppSpacing.paddingMd,
              children: [
                Expanded(
                  child: Text(trackListSummary(loaded), style: AppTextStyles.p.copyWith(color: AppColors.greyLight)),
                ),
                Button(
                  label: 'Play',
                  semanticLabel: 'Play all',
                  icon: PhosphorIconsRegular.play,
                  onPressed: () => _play(context, ref, loaded.first, loaded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.paddingMd),
            for (final Track track in loaded) _TrackRow(track: track, onTap: () => _play(context, ref, track, loaded)),
          ],
        ],
      ),
    );
  }
}

/// A track of the list: cover, title, artist and length. The one playing now has its title in primary.
class _TrackRow extends ConsumerStatefulWidget {
  const _TrackRow({required this.track, required this.onTap});

  static const double coverSize = 48;

  final Track track;
  final VoidCallback onTap;

  @override
  ConsumerState<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends ConsumerState<_TrackRow> {
  bool _pressed = false;

  void _setPressed(bool pressed) => setState(() => _pressed = pressed);

  @override
  Widget build(BuildContext context) {
    final Track track = widget.track;
    // select: rebuilt only when the playing track changes
    final bool current = ref.watch(playbackProvider.select((p) => p.trackId == track.id));
    final Duration? duration = track.duration;
    final String time = duration == null ? '' : _formatTime(duration);

    return Semantics(
      button: true,
      selected: current,
      label: [track.name, track.artistName, if (duration != null) time, if (current) 'now playing'].join(', '),
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: Container(
          // No ripple: a surface while pressed
          decoration: BoxDecoration(
            color: _pressed ? AppColors.greyDarker : Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(AppSpacing.radiusMd)),
          ),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingSm),
          child: Row(
            spacing: AppSpacing.paddingMd,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Image.network(
                  track.image,
                  width: _TrackRow.coverSize,
                  height: _TrackRow.coverSize,
                  fit: BoxFit.cover,
                  cacheWidth: (_TrackRow.coverSize * MediaQuery.devicePixelRatioOf(context)).round(),
                  errorBuilder: (_, _, _) => Image.asset(
                    track.fallbackCoverAsset,
                    width: _TrackRow.coverSize,
                    height: _TrackRow.coverSize,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      style: AppTextStyles.pBold.copyWith(color: current ? AppColors.primary : AppColors.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      track.artistName,
                      style: AppTextStyles.pSm.copyWith(color: AppColors.greyLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                time,
                style: AppTextStyles.pSm.copyWith(
                  color: AppColors.greyLight,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
