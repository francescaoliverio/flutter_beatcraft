import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/heading.dart';

/// Logged user: avatar, name, stats, saved remixes.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.paddingLg),
        children: [
          // TODO: name and image from DummyJSON /auth/me
          const Row(
            children: [
              CircleAvatar(radius: 40, backgroundColor: AppColors.greyDarker),
              SizedBox(width: AppSpacing.paddingLg),
              Expanded(child: Heading('User name', style: HeadingStyle.h3, uppercase: false)),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingLg),
          // Mock stats
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(value: '123', label: 'Followers'),
              _Stat(value: '456', label: 'Following'),
              _Stat(value: '78.9K', label: 'Listens'),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingLg),
          const Heading('My remixes', style: HeadingStyle.h4),
          const SizedBox(height: AppSpacing.paddingMd),
          // TODO: saved remix projects
          const SizedBox(height: 200, child: Placeholder(color: AppColors.greyDark)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.pBold),
        Text(label, style: AppTextStyles.pSm.copyWith(color: AppColors.greyLight)),
      ],
    );
  }
}
