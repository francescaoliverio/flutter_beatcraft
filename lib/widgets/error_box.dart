import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'button.dart';
import 'heading.dart';

/// Error message with a title, a description and a Retry button.
class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.title, required this.description, required this.onRetry});

  final String title;
  final String description;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // liveRegion: screen readers announce the error when it appears
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.paddingMd),
        decoration: const BoxDecoration(
          color: AppColors.greyDarker,
          borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusMd)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Heading(title, style: HeadingStyle.h5, uppercase: false, color: AppColors.error),
            const SizedBox(height: AppSpacing.paddingSm),
            Text(description, style: AppTextStyles.p.copyWith(color: AppColors.textLight)),
            const SizedBox(height: AppSpacing.paddingMd),
            Button(
              label: 'Retry',
              icon: PhosphorIconsRegular.arrowClockwise,
              color: ButtonColor.error,
              variant: ButtonVariant.outline,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
