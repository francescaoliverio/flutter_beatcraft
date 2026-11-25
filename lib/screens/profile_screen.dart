import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../models/track.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/playback_provider.dart';
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
                  // Neutral colors from the icon button theme
                  onPressed: () => ref.read(authProvider.notifier).logout(),
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
                // TODO: show saved remix projects; for now there are none
                EmptyState(
                  message: "You don't have any remixes yet.",
                  actionLabel: 'Make your first remix',
                  actionIcon: PhosphorIconsRegular.waveform,
                  onAction: () => ref.read(shellTabProvider.notifier).select(ShellTab.create),
                ),
              ],
            ),
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
