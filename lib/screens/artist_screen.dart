import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../models/artist.dart';
import '../providers/jamendo_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/heading.dart';
import '../widgets/jamendo_link.dart';
import '../widgets/track_list.dart';

/// A Jamendo artist: picture, name, since when on Jamendo, their website and their most popular tracks.
class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.artist});

  final Artist artist;

  static const double _pictureSize = 160;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime? joined = artist.joinDate;
    final String? website = artist.website;

    return TrackListScreen(
      tracks: ref.watch(artistTracksProvider(artist.id)),
      emptyMessage: 'This artist has no tracks on Jamendo yet.',
      onRetry: () => ref.invalidate(artistTracksProvider(artist.id)),
      header: Column(
        children: [
          ExcludeSemantics(
            child: ClipOval(
              child: Image.network(
                artist.image,
                width: _pictureSize,
                height: _pictureSize,
                fit: BoxFit.cover,
                cacheWidth: (_pictureSize * MediaQuery.devicePixelRatioOf(context)).round(),
                errorBuilder: (_, _, _) => const SizedBox(
                  width: _pictureSize,
                  height: _pictureSize,
                  child: ColoredBox(color: AppColors.greyDarker),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.paddingMd),
          Heading(artist.name, style: HeadingStyle.h2, uppercase: false, textAlign: TextAlign.center),
          if (joined != null)
            Text(
              'On Jamendo since ${joined.year}',
              style: AppTextStyles.p.copyWith(color: AppColors.greyLight),
              textAlign: TextAlign.center,
            ),
          if (website != null)
            ExternalLink(
              text: 'Website',
              url: website,
              semanticLabel: 'Website of ${artist.name}',
              alignment: Alignment.center,
            ),
        ],
      ),
    );
  }
}
