import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/button.dart';
import '../widgets/heading.dart';

/// Remix editor: timeline with clips, playback and editing tools.
class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.paddingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Heading('Create')),
                  Button(label: 'Save', icon: PhosphorIconsRegular.floppyDisk, onPressed: () {}),
                ],
              ),
              const SizedBox(height: AppSpacing.paddingMd),
              const Heading('Remix name', style: HeadingStyle.h4, uppercase: false),
              const SizedBox(height: AppSpacing.paddingLg),
              // TODO: waveform and clips
              const Expanded(child: Placeholder(color: AppColors.greyDark)),
            ],
          ),
        ),
      ),
    );
  }
}
