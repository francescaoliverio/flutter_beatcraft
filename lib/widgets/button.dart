import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_effects.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum ButtonColor { primary, secondary, tertiary }

enum ButtonVariant { filled, outline }

/// Button
/// - With [label]: icon (optional) + text.
/// - Without [label]: square icon-only button ([icon] required).
/// - [onPressed] null = disabled, as in Flutter's own buttons.

class Button extends StatefulWidget {
  const Button({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.color = ButtonColor.primary,
    this.variant = ButtonVariant.filled,
  }) : assert(
          label != null || icon != null,
          'Button needs a label, an icon, or both',
        );

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ButtonColor color;
  final ButtonVariant variant;

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  /// Picks the color for the current state: disabled, pressed or default.
  Color get _stateColor {
    switch (widget.color) {
      case ButtonColor.primary:
        if (!_enabled) return AppColors.primaryDisabled;
        return _pressed ? AppColors.primaryPressed : AppColors.primary;
      case ButtonColor.secondary:
        if (!_enabled) return AppColors.secondaryDisabled;
        return _pressed ? AppColors.secondaryPressed : AppColors.secondary;
      case ButtonColor.tertiary:
        if (!_enabled) return AppColors.tertiaryDisabled;
        return _pressed ? AppColors.tertiaryPressed : AppColors.tertiary;
    }
  }

  List<BoxShadow> get _glow {
    switch (widget.color) {
      case ButtonColor.primary:
        return AppEffects.glowPrimary;
      case ButtonColor.secondary:
        return AppEffects.glowSecondary;
      case ButtonColor.tertiary:
        return AppEffects.glowTertiary;
    }
  }

  void _setPressed(bool value) {
    if (_enabled) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool filled = widget.variant == ButtonVariant.filled;
    final bool iconOnly = widget.label == null;
    final Color color = _stateColor;

    // Filled: dark content on color. Outline: colored content on background.
    final Color contentColor = filled ? AppColors.textDark : color;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      // GestureDetector: detects touches on its child.
      // Used instead of Flutter's ready-made buttons to have full control
      // over the look (glow, pressed colors from design system).
      // onTapDown/onTapUp/onTapCancel tell when the finger is on the button,
      // so we can show the pressed color. onTap runs the button's action.
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        // AnimatedContainer: a Container that animates its changes.
        // When the color, border or shadow change (default -> pressed),
        // it moves between the two values in 100 ms instead of jumping,
        // so the press feels smooth.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: EdgeInsets.symmetric(
            horizontal: iconOnly ? AppSpacing.paddingSm : AppSpacing.paddingMd,
            vertical: AppSpacing.paddingSm,
          ),
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            // Glow only on enabled filled buttons
            boxShadow: filled && _enabled ? _glow : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null)
                Icon(widget.icon, size: 18, color: contentColor),
              if (widget.icon != null && !iconOnly)
                const SizedBox(width: AppSpacing.paddingSm),
              if (!iconOnly)
                Text(
                  widget.label!,
                  style: AppTextStyles.pBold.copyWith(color: contentColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}