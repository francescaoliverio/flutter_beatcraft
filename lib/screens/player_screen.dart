import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../models/track.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/button.dart';
import '../widgets/heading.dart';

/// Now playing: cover, track info, progress, controls, remix.
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Track? track = ref.watch(currentTrackProvider).value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.caretDown),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // Opened only after a track is selected, so track is null only for an instant
      body: track == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.paddingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Image.network(
                        track.image,
                        fit: BoxFit.cover,
                        // Cover is decorative: title and artist are read below
                        excludeFromSemantics: true,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset(track.fallbackCoverAsset, fit: BoxFit.cover, excludeFromSemantics: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.paddingLg),
                  Heading(track.name, style: HeadingStyle.h3, uppercase: false),
                  Text(
                    '${track.artistName} · via Jamendo',
                    style: AppTextStyles.p.copyWith(color: AppColors.greyLight),
                  ),
                  const SizedBox(height: AppSpacing.paddingMd),
                  // TODO: real position and duration
                  Slider(value: 0.3, onChanged: (_) {}),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1:24', style: AppTextStyles.pSm),
                      Text('3:48', style: AppTextStyles.pSm),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.paddingMd),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: AppSpacing.paddingLg,
                    children: [
                      IconButton(
                        icon: const Icon(PhosphorIconsRegular.skipBack),
                        tooltip: 'Previous',
                        onPressed: () {},
                      ),
                      Button(icon: PhosphorIconsRegular.play, onPressed: () {}),
                      IconButton(icon: const Icon(PhosphorIconsRegular.skipForward), tooltip: 'Next', onPressed: () {}),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
