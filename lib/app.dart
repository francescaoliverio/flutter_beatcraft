import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

/// Root widget: shows the login or the main shell depending on the session.
class BeatCraftApp extends ConsumerWidget {
  const BeatCraftApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool loggedIn = ref.watch(authProvider) != null;

    return MaterialApp(
      title: 'BeatCraft',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // No stretch effect when a list is scrolled past its ends (Android)
      scrollBehavior: const MaterialScrollBehavior().copyWith(overscroll: false),
      home: loggedIn ? const MainShell() : const LoginScreen(),
    );
  }
}
