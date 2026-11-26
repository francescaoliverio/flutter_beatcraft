import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'button.dart';

/// Message for a list with nothing in it yet, with an optional call to action.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.actionLabel, this.actionIcon, this.onAction})
    : assert(actionLabel == null || onAction != null, 'An action label needs onAction');

  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.paddingMd),
      decoration: BoxDecoration(
        color: AppColors.greyDarker,
        border: Border.all(color: AppColors.greyDark),
        borderRadius: const BorderRadius.all(Radius.circular(AppSpacing.radiusMd)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppTextStyles.p.copyWith(color: AppColors.textLight)),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.paddingMd),
            Button(label: actionLabel, icon: actionIcon, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
