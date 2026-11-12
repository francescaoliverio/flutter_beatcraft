import 'package:material_ui/material_ui.dart';

/// Glow shadows
/// Each glow is two shadows: one towards bottom-right, one towards top-left.
class AppEffects {
  AppEffects._();

  static const List<BoxShadow> glowPrimary = [
    BoxShadow(
      color: Color.fromRGBO(199, 245, 61, 0.4),
      offset: Offset(1, 1),
      blurRadius: 4,
    ),
    BoxShadow(
      color: Color.fromRGBO(199, 245, 61, 0.3),
      offset: Offset(-1, -1),
      blurRadius: 4,
    ),
  ];

  static const List<BoxShadow> glowSecondary = [
    BoxShadow(
      color: Color.fromRGBO(193, 85, 246, 0.4),
      offset: Offset(1, 1),
      blurRadius: 4,
    ),
    BoxShadow(
      color: Color.fromRGBO(193, 85, 246, 0.3),
      offset: Offset(-1, -1),
      blurRadius: 4,
    ),
  ];

  static const List<BoxShadow> glowTertiary = [
    BoxShadow(
      color: Color.fromRGBO(225, 66, 240, 0.4),
      offset: Offset(1, 1),
      blurRadius: 4,
    ),
    BoxShadow(
      color: Color.fromRGBO(225, 66, 240, 0.3),
      offset: Offset(-1, -1),
      blurRadius: 4,
    ),
  ];
}