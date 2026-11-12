import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/button.dart';
import '../widgets/heading.dart';
import 'create_screen.dart';

/// Now playing: cover, track info, progress, controls, remix.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  // TODO: false when audiodownload_allowed is false or the license is ND
  final bool _remixAllowed = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.caretDown),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.paddingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TODO: cover from Jamendo
            const AspectRatio(aspectRatio: 1, child: Placeholder(color: AppColors.greyDark)),
            const SizedBox(height: AppSpacing.paddingLg),
            const Heading('Track title', style: HeadingStyle.h3, uppercase: false),
            const Text('Artist · via Jamendo', style: TextStyle(color: AppColors.greyLight)),
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
                IconButton(icon: const Icon(PhosphorIconsRegular.skipBack), tooltip: 'Previous', onPressed: () {}),
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
