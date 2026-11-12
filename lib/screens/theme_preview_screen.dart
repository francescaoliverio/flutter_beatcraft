import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/heading.dart';
import '../widgets/button.dart';

/// Temporary screen to check theme, font and buttons on a device.
class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.paddingLg),
          children: [
            // Typography
            const Heading('Display', style: HeadingStyle.display),
            const Heading('Heading 1', style: HeadingStyle.h1),
            const Heading('Heading 2', style: HeadingStyle.h2),
            const Heading('Heading 3', style: HeadingStyle.h3),
            const Heading('Heading 4', style: HeadingStyle.h4),
            const Heading('Heading 5', style: HeadingStyle.h5),
            const Heading('Track name', style: HeadingStyle.h3, uppercase: false),
            const SizedBox(height: AppSpacing.paddingMd),
            const Text('P bold: the quick brown fox', style: AppTextStyles.pBold),
            const Text('P regular: the quick brown fox', style: AppTextStyles.p),
            const Text('P light: the quick brown fox', style: AppTextStyles.pLight),
            const Text('P italic: the quick brown fox', style: AppTextStyles.pItalic),
            const Text('P italic light: the quick brown fox', style: AppTextStyles.pItalicLight),
            const Text('Secondary text in greyLight', style: TextStyle(color: AppColors.greyLight)),
            const SizedBox(height: AppSpacing.paddingLg),
            // Buttons: one row per color
            for (final color in ButtonColor.values) ...[
              Wrap(
                spacing: AppSpacing.paddingMd,
                runSpacing: AppSpacing.paddingMd,
                children: [
                  Button(label: 'Filled', icon: Icons.send, color: color, onPressed: () {}),
                  Button(
                    label: 'Outline',
                    icon: Icons.save,
                    color: color,
                    variant: ButtonVariant.outline,
                    onPressed: () {},
                  ),
                  Button(icon: Icons.play_arrow, color: color, variant: ButtonVariant.outline, onPressed: () {}),
                  Button(label: 'Disabled', color: color, onPressed: null),
                ],
              ),
              const SizedBox(height: AppSpacing.paddingMd),
            ],
            // Gradient
            Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
