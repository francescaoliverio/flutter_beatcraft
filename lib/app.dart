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
    final auth = ref.watch(authProvider);

    return MaterialApp(
      title: 'BeatCraft',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // No stretch effect when a list is scrolled past its ends (Android)
      scrollBehavior: const MaterialScrollBehavior().copyWith(overscroll: false),
      home: switch (auth) {
        // Saved user being restored at launch: empty dark screen, like the Android launch screen
        AsyncLoading() when !auth.hasValue => const Scaffold(),
        _ when auth.value != null => const MainShell(),
        _ => const LoginScreen(),
      },
    );
  }
}
