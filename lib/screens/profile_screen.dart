import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../providers/auth_provider.dart';
import '../providers/shell_tab_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';
import '../widgets/heading.dart';

/// Logged user: avatar, name, stats, saved remixes.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value?.user;
    // Only shown while logged in, but the session can become null during logout
    if (user == null) return const SizedBox.shrink();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.paddingLg),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.greyDarker,
                backgroundImage: NetworkImage(user.image),
              ),
              const SizedBox(width: AppSpacing.paddingLg),
              Expanded(child: Heading(user.fullName, style: HeadingStyle.h3, uppercase: false)),
              IconButton(
                // tooltip is also the screen reader label
                tooltip: 'Log out',
                icon: const Icon(PhosphorIconsRegular.signOut),
                onPressed: () => ref.read(authProvider.notifier).logout(),
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.pressed) ? AppColors.secondaryPressed : AppColors.secondary,
                  ),
                ),
              ),
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
          // TODO: show saved remix projects; for now there are none
          EmptyState(
            message: "You don't have any remixes yet.",
            actionLabel: 'Make your first remix',
            actionIcon: PhosphorIconsRegular.waveform,
            onAction: () => ref.read(shellTabProvider.notifier).select(ShellTab.create),
          ),
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
