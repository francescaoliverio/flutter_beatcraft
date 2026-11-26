import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../providers/shell_tab_provider.dart';
import '../widgets/mini_player.dart';
import 'create_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Bottom navigation with Home, Create and Profile, and the mini player above it.
/// Home has its own navigator: the playlist and artist screens open inside the tab, under the bottom navigation,
/// and stay there when another tab is chosen.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ShellTab tab = ref.watch(shellTabProvider);

    return Scaffold(
      // IndexedStack keeps each tab alive, so it doesn't reload when you switch back. Same order as ShellTab
      body: IndexedStack(
        index: tab.index,
        children: [
          _TabNavigator(active: tab == ShellTab.home, child: const HomeScreen()),
          const CreateScreen(),
          const ProfileScreen(),
        ],
      ),
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

/// A navigator for the screens opened from a tab. The system back (Android) closes them first, only in the
/// [active] tab.
class _TabNavigator extends StatefulWidget {
  const _TabNavigator({required this.active, required this.child});

  final bool active;

  /// The first screen of the tab.
  final Widget child;

  @override
  State<_TabNavigator> createState() => _TabNavigatorState();
}

class _TabNavigatorState extends State<_TabNavigator> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler<void>(
      enabled: widget.active,
      onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => widget.child),
      ),
    );
  }
}
