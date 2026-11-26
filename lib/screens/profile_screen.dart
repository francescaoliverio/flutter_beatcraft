import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../models/remix_project.dart';
import '../models/track.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/playback_provider.dart';
import '../providers/remix_provider.dart';
import '../providers/shell_tab_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_box.dart';
import '../widgets/heading.dart';
import '../widgets/like_button.dart';
import '../widgets/media_card.dart';
import '../widgets/media_section.dart';
import '../widgets/undo_snack_bar.dart';
import 'player_screen.dart';

/// Logged user: avatar, name, stats, liked tracks, saved remixes.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const EdgeInsets _sideMargin = EdgeInsets.symmetric(horizontal: AppSpacing.paddingLg);

  void _openTrack(BuildContext context, WidgetRef ref, Track track) {
    ref.read(playbackProvider.notifier).playTrack(track);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value?.user;
    // Only shown while logged in, but the session can become null during logout
    if (user == null) return const SizedBox.shrink();
    final List<String>? favorites = ref.watch(favoritesProvider).value;
    final List<RemixProject> remixes = ref.watch(remixProjectsProvider).value ?? [];

    return SafeArea(
      child: ListView(
        // No side padding: the favorites row reaches the screen edges and adds its own margin
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingLg),
        children: [
          Padding(
            padding: _sideMargin,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.greyDarker,
                  backgroundImage: NetworkImage(user.image),
                ),
                const SizedBox(width: AppSpacing.paddingLg),
                Expanded(child: Heading(user.fullName, style: HeadingStyle.h3, uppercase: false)),
                IconButton(
                  // tooltip is also the screen reader label
                  tooltip: 'Log out',
                  icon: const Icon(PhosphorIconsRegular.signOut),
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  // Neutral colors from the icon button theme
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.paddingLg),
          // Mock stats
          const Padding(
            padding: _sideMargin,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(value: '123', label: 'Followers'),
                _Stat(value: '456', label: 'Following'),
                _Stat(value: '78.9K', label: 'Listens'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.paddingLg),
          if (favorites != null && favorites.isEmpty)
            const Padding(
              padding: _sideMargin,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Heading('Favorites', style: HeadingStyle.h4),
                  SizedBox(height: AppSpacing.paddingMd),
                  EmptyState(message: "You haven't liked any tracks yet."),
                ],
              ),
            )
          else
            MediaSection<Track>(
              title: 'Favorites',
              items: ref.watch(favoriteTracksProvider),
              itemBuilder: (track) => MediaCard(
                image: NetworkImage(track.image),
                fallbackImage: AssetImage(track.fallbackCoverAsset),
                title: track.name,
                subtitle: track.artistName,
                onTap: () => _openTrack(context, ref, track),
                imageAction: LikeButton(trackId: track.id),
              ),
              errorBuilder: (_) => ErrorBox(
                title: "Couldn't load your favorites",
                description: 'Check your connection and try again.',
                onRetry: () => ref.invalidate(favoriteTracksProvider),
              ),
            ),
          const SizedBox(height: AppSpacing.paddingLg),
          Padding(
            padding: _sideMargin,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Heading('My remixes', style: HeadingStyle.h4),
                const SizedBox(height: AppSpacing.paddingMd),
                if (remixes.isEmpty)
                  EmptyState(
                    message: "You don't have any remixes yet.",
                    actionLabel: 'Make your first remix',
                    actionIcon: PhosphorIconsRegular.waveform,
                    onAction: () => ref.read(shellTabProvider.notifier).select(ShellTab.create),
                  )
                else
                  for (final RemixProject remix in remixes) _RemixRow(remix: remix),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A saved remix: tap to open it in Create, trash to delete it (with Undo).
class _RemixRow extends ConsumerWidget {
  const _RemixRow({required this.remix});

  final RemixProject remix;

  static const double _coverSize = 48;

  void _open(WidgetRef ref) {
    ref.read(remixProvider.notifier).open(remix);
    ref.read(shellTabProvider.notifier).select(ShellTab.create);
  }

  void _delete(BuildContext context, WidgetRef ref) {
    final RemixProjectsNotifier projects = ref.read(remixProjectsProvider.notifier);
    projects.delete(remix.id);
    showUndoSnackBar(context, message: '${remix.name} deleted', onUndo: () => projects.save(remix));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int clips = remix.clips.length;
    final String seconds = (remix.length.inSeconds % 60).toString().padLeft(2, '0');
    final String details = '$clips ${clips == 1 ? 'clip' : 'clips'} · ${remix.length.inMinutes}:$seconds';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.paddingSm),
      child: Row(
        children: [
          Expanded(
            // One item for screen readers: name and details, opened with a tap
            child: Semantics(
              button: true,
              label: '${remix.name}, $details',
              excludeSemantics: true,
              onTap: () => _open(ref),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _open(ref),
                child: Row(
                  spacing: AppSpacing.paddingMd,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Image.asset(
                        remix.coverAsset,
                        width: _coverSize,
                        height: _coverSize,
                        fit: BoxFit.cover,
                        // Decode at the displayed size: the covers are 1024 px
                        cacheWidth: (_coverSize * MediaQuery.devicePixelRatioOf(context)).round(),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(remix.name, style: AppTextStyles.pBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(details, style: AppTextStyles.pSm.copyWith(color: AppColors.greyLight)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.trash),
            tooltip: 'Delete ${remix.name}',
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.pBold),
        Text(label, style: AppTextStyles.pSm.copyWith(color: AppColors.greyLight)),
      ],
    );
  }
}
