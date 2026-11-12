import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../widgets/mini_player.dart';
import 'create_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Bottom navigation with Home, Create and Profile, and the mini player above it.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const List<Widget> _screens = [HomeScreen(), CreateScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab alive, so it doesn't reload when you switch back
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
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
