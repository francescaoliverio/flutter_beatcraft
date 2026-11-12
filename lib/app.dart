import 'package:material_ui/material_ui.dart';

import 'screens/theme_preview_screen.dart';
import 'theme/app_theme.dart';

class BeatCraftApp extends StatelessWidget {
  const BeatCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeatCraft',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // Temporary
      home: const ThemePreviewScreen(),
    );
  }
}