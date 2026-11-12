import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../screens/player_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Current track above the bottom navigation. Tap to open the player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: show only when a track is playing, with real data
    return Material(
      color: AppColors.greyDarker,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlayerScreen())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLg, vertical: AppSpacing.paddingSm),
          child: Row(
            children: [
              const SizedBox(width: 40, height: 40, child: Placeholder(color: AppColors.greyDark)),
              const SizedBox(width: AppSpacing.paddingMd),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Track title', style: AppTextStyles.pBold),
                    Text('Artist', style: TextStyle(color: AppColors.greyLight)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(PhosphorIconsRegular.play), tooltip: 'Play', onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }
}
