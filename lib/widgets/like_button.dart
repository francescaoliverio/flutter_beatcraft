import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../providers/favorites_provider.dart';
import '../theme/app_colors.dart';

/// Heart over a card image that likes or unlikes a track. Same labels as the Like button in the player.
class LikeButton extends ConsumerWidget {
  const LikeButton({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String>? favorites = ref.watch(favoritesProvider).value;
    final bool isLiked = favorites?.contains(trackId) ?? false;

    return IconButton(
      isSelected: isLiked,
      // tooltip is also the screen reader label
      tooltip: isLiked ? 'Remove like' : 'Like',
      icon: const Icon(PhosphorIconsRegular.heart, color: AppColors.textLight),
      selectedIcon: const Icon(PhosphorIconsFill.heart, color: AppColors.tertiary),
      // Disabled until the saved likes are read
      onPressed: favorites == null ? null : () => ref.read(favoritesProvider.notifier).toggle(trackId),
    );
  }
}
