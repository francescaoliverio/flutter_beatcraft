import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/heading.dart';
import 'player_screen.dart';

/// Home feed: new releases, trending artists, playlists.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.paddingLg),
        children: [
          const Heading('Home'),
          const SizedBox(height: AppSpacing.paddingLg),
          const Heading('New releases', style: HeadingStyle.h4),
          const SizedBox(height: AppSpacing.paddingMd),
          // TODO: tracks from Jamendo
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.paddingMd),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlayerScreen())),
                child: const SizedBox(width: 120, child: Placeholder(color: AppColors.greyDark)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.paddingLg),
          const Heading('Trending artists', style: HeadingStyle.h4),
          const SizedBox(height: AppSpacing.paddingMd),
          // TODO: artists from Random User Generator
          const SizedBox(height: 100, child: Placeholder(color: AppColors.greyDark)),
          const SizedBox(height: AppSpacing.paddingLg),
          const Heading('Playlists', style: HeadingStyle.h4),
          const SizedBox(height: AppSpacing.paddingMd),
          // TODO: playlists from Jamendo
          const SizedBox(height: 120, child: Placeholder(color: AppColors.greyDark)),
        ],
      ),
    );
  }
}
