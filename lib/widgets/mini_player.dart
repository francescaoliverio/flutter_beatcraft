import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../models/track.dart';
import '../providers/player_provider.dart';
import '../screens/player_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Current track above the bottom navigation, hidden until a track is selected. Tap to open the player.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Track? track = ref.watch(currentTrackProvider).value;
    if (track == null) return const SizedBox.shrink();

    void openPlayer() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));

    return ColoredBox(
      color: AppColors.greyDarker,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLg, vertical: AppSpacing.paddingSm),
        child: Row(
          children: [
            // Title and artist are read as one button that opens the player
            Expanded(
              child: Semantics(
                button: true,
                onTap: openPlayer,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: openPlayer,
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        child: Image.network(
                          track.image,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            track.fallbackCoverAsset,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.paddingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(track.name, style: AppTextStyles.pBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              track.artistName,
                              style: AppTextStyles.p.copyWith(color: AppColors.greyLight),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // TODO: real playback
            IconButton(icon: const Icon(PhosphorIconsRegular.play), tooltip: 'Play', onPressed: () {}),
          ],
        ),
      ),
    );
  }
}
