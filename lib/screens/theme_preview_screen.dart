import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
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
            Text('Display'.toUpperCase(), style: AppTextStyles.display),
            Text('Heading 1'.toUpperCase(), style: AppTextStyles.h1),
            Text('Heading 2'.toUpperCase(), style: AppTextStyles.h2),
            Text('Heading 3'.toUpperCase(), style: AppTextStyles.h3),
            Text('Heading 4'.toUpperCase(), style: AppTextStyles.h4),
            Text('Heading 5'.toUpperCase(), style: AppTextStyles.h5),
            const SizedBox(height: AppSpacing.paddingMd),
            const Text('P bold: the quick brown fox', style: AppTextStyles.pBold),
            const Text('P regular: the quick brown fox', style: AppTextStyles.p),
            const Text('P light: the quick brown fox', style: AppTextStyles.pLight),
            const Text('P italic: the quick brown fox', style: AppTextStyles.pItalic),
            const Text('P italic light: the quick brown fox', style: AppTextStyles.pItalicLight),
            const Text('Secondary text in greyLight',style: TextStyle(color: AppColors.greyLight)),
            const SizedBox(height: AppSpacing.paddingLg),
            // Buttons: one row per color
            for (final color in AppButtonColor.values) ...[
              Wrap(
                spacing: AppSpacing.paddingMd,
                runSpacing: AppSpacing.paddingMd,
                children: [
                  AppButton(
                    label: 'Filled',
                    icon: Icons.send,
                    color: color,
                    onPressed: () {},
                  ),
                  AppButton(
                    label: 'Outline',
                    icon: Icons.save,
                    color: color,
                    variant: AppButtonVariant.outline,
                    onPressed: () {},
                  ),
                  AppButton(
                    icon: Icons.play_arrow,
                    color: color,
                    variant: AppButtonVariant.outline,
                    onPressed: () {},
                  ),
                  AppButton(label: 'Disabled', color: color, onPressed: null),
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
