import 'package:material_ui/material_ui.dart';

/// Glow shadows and animation durations.
/// Each glow is two shadows: one towards bottom-right, one towards top-left.
class AppEffects {
  AppEffects._();

  // Durations
  /// Pressed state of buttons.
  static const Duration durationShort = Duration(milliseconds: 100);

  /// One half of the skeleton pulse.
  static const Duration durationLong = Duration(milliseconds: 900);

  static const List<BoxShadow> glowPrimary = [
    BoxShadow(color: Color.fromRGBO(199, 245, 61, 0.4), offset: Offset(1, 1), blurRadius: 4),
    BoxShadow(color: Color.fromRGBO(199, 245, 61, 0.3), offset: Offset(-1, -1), blurRadius: 4),
  ];

  static const List<BoxShadow> glowSecondary = [
    BoxShadow(color: Color.fromRGBO(193, 85, 246, 0.4), offset: Offset(1, 1), blurRadius: 4),
    BoxShadow(color: Color.fromRGBO(193, 85, 246, 0.3), offset: Offset(-1, -1), blurRadius: 4),
  ];

  static const List<BoxShadow> glowTertiary = [
    BoxShadow(color: Color.fromRGBO(225, 66, 240, 0.4), offset: Offset(1, 1), blurRadius: 4),
    BoxShadow(color: Color.fromRGBO(225, 66, 240, 0.3), offset: Offset(-1, -1), blurRadius: 4),
  ];
}
