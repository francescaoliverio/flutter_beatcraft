import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// Puts all the tokens together in one ThemeData.
/// Use it in MaterialApp: theme: AppTheme.dark
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: AppTextStyles.fontFamily,
      scaffoldBackgroundColor: AppColors.bgDark,

      // Main colors. "on..." = color of text/icons placed on that color:
      // dark on brand colors, light on the background.
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.textDark,
        secondary: AppColors.secondary,
        onSecondary: AppColors.textDark,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.textDark,
        surface: AppColors.bgDark,
        onSurface: AppColors.textLight,
        error: AppColors.error,
        onError: AppColors.textDark,
      ),

      // Maps Flutter's text roles,
      // so Theme.of(context).textTheme.headlineLarge = h1, and so on.
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.display,
        headlineLarge: AppTextStyles.h1,
        headlineMedium: AppTextStyles.h2,
        headlineSmall: AppTextStyles.h3,
        titleLarge: AppTextStyles.h4,
        titleMedium: AppTextStyles.h5,
        bodyLarge: AppTextStyles.pLg,
        bodyMedium: AppTextStyles.p,
        bodySmall: AppTextStyles.pSm,
        labelLarge: AppTextStyles.pBold,
      ).apply(
        bodyColor: AppColors.textLight,
        displayColor: AppColors.textLight,
      ),

      // Filled button: primary background, dark text,
      // with the pressed and disabled colors.
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.primaryDisabled;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primaryPressed;
            }
            return AppColors.primary;
          }),
          foregroundColor: const WidgetStatePropertyAll(AppColors.textDark),
          textStyle: const WidgetStatePropertyAll(AppTextStyles.pBold),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.paddingLg,
              vertical: AppSpacing.paddingMd,
            ),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(AppSpacing.radiusMd),
              ),
            ),
          ),
        ),
      ),
    );
  }
}