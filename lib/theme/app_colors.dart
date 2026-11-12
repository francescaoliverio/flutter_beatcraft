import 'package:material_ui/material_ui.dart';

class AppColors {
  AppColors._(); // prevents creating instances: use AppColors.primary

  // Brand: default / pressed / disabled
  static const Color primary = Color(0xFFC7F53D);
  static const Color primaryPressed = Color(0xFFD5F76E);
  static const Color primaryDisabled = Color(0xFF93A659);

  static const Color secondary = Color(0xFFC155F6);
  static const Color secondaryPressed = Color(0xFFC96EF7);
  static const Color secondaryDisabled = Color(0xFF9D59C0);

  static const Color tertiary = Color(0xFFE142F0);
  static const Color tertiaryPressed = Color(0xFFE55AF2);
  static const Color tertiaryDisabled = Color(0xFFAF46B9);

  // Backgrounds
  static const Color bgDark = Color(0xFF0E0E0E);
  static const Color bgLight = Color(0xFFFFFFFF);

  // Text
  // Rule: white text only on bgDark, never on brand colors.
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF000000);

  // Greys
  // greyLighter and greyLight are for texts and icons on bgDark.
  // greyDark and greyDarker are for borders, dividers and surfaces.
  static const Color greyLighter = Color(0xFFE2E2E2);
  static const Color greyLight = Color(0xFFA2A2A2);
  static const Color greyDark = Color(0xFF4A4A4A);
  static const Color greyDarker = Color(0xFF2A2A2A);

  // Feedback
  static const Color warning = Color(0xFFF5F53D);
  static const Color error = Color(0xFFFF8833);

  // Gradient: primary at 25%, secondary at 75%, top left to bottom right
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
    stops: [0.25, 0.75],
  );
}
