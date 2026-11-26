import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_effects.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// [error] has no pressed or disabled color and no glow: use it with the outline variant.
enum ButtonColor { primary, secondary, tertiary, error }

enum ButtonVariant { filled, outline }

/// [vertical]: icon above a smaller label, for rows of equal buttons (e.g. like, remix, share).
enum ButtonLayout { horizontal, vertical }

/// Button
/// - With [label]: icon (optional) + text.
/// - Without [label]: square icon-only button ([icon] required), described to screen readers by [semanticLabel].
/// - [semanticLabel] with [label]: read instead of a short visible label.
/// - [onPressed] null = disabled, as in Flutter's own buttons.

class Button extends StatefulWidget {
  const Button({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.color = ButtonColor.primary,
    this.variant = ButtonVariant.filled,
    this.layout = ButtonLayout.horizontal,
    this.semanticLabel,
  }) : assert(label != null || icon != null, 'Button needs a label, an icon, or both');

  final String? label;

  /// What screen readers announce, when there is no [label] or it is too short to be clear alone.
  final String? semanticLabel;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ButtonColor color;
  final ButtonVariant variant;
  final ButtonLayout layout;

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
      case ButtonColor.error:
        return AppColors.error;
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
      case ButtonColor.error:
        return const [];
    }
  }

  /// With a [Button.semanticLabel] the visible text is hidden from screen readers, so it isn't read twice.
  Widget _visibleLabel(TextStyle style) => ExcludeSemantics(
    excluding: widget.semanticLabel != null,
    child: Text(widget.label!, textAlign: TextAlign.center, style: style),
  );

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
      // Its own element for screen readers, never merged with the text next to it
      container: true,
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.label,
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
          duration: AppEffects.durationShort,
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
          // Centered and with the label wrapping, for when the button is stretched or narrow (e.g. in Expanded)
          child: widget.layout == ButtonLayout.vertical && !iconOnly
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: AppSpacing.paddingSm,
                  children: [
                    if (widget.icon != null) Icon(widget.icon, size: 24, color: contentColor),
                    _visibleLabel(AppTextStyles.pSm.copyWith(color: contentColor)),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) Icon(widget.icon, size: 18, color: contentColor),
                    if (widget.icon != null && !iconOnly) const SizedBox(width: AppSpacing.paddingSm),
                    if (!iconOnly) Flexible(child: _visibleLabel(AppTextStyles.pBold.copyWith(color: contentColor))),
                  ],
                ),
        ),
      ),
    );
  }
}
