import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../providers/shell_tab_provider.dart';
import '../widgets/mini_player.dart';
import 'create_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Bottom navigation with Home, Create and Profile, and the mini player above it.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  // Same order as ShellTab
  static const List<Widget> _screens = [HomeScreen(), CreateScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ShellTab tab = ref.watch(shellTabProvider);

    return Scaffold(
      // IndexedStack keeps each tab alive, so it doesn't reload when you switch back
      body: IndexedStack(index: tab.index, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: tab.index,
            onDestinationSelected: (i) => ref.read(shellTabProvider.notifier).select(ShellTab.values[i]),
            destinations: const [
              NavigationDestination(icon: Icon(PhosphorIconsRegular.house), label: 'Home'),
              NavigationDestination(icon: Icon(PhosphorIconsRegular.plus), label: 'Create'),
              NavigationDestination(icon: Icon(PhosphorIconsRegular.user), label: 'Profile'),
            ],
          ),
        ],
      ),
    );
  }
}
