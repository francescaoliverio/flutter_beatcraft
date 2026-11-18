import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_effects.dart';
import '../theme/app_spacing.dart';

enum SkeletonShape { rectangle, circle }

/// Grey placeholder shown while content loads.
/// It pulses, but stays still when the system asks to reduce animations.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height, this.shape = SkeletonShape.rectangle});

  /// Null fills the available space.
  final double? width;
  final double? height;
  final SkeletonShape shape;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: AppEffects.durationLong);

  // Runs again when the system setting changes while the skeleton is visible
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool circle = widget.shape == SkeletonShape.circle;

    // Decorative: the section that shows skeletons announces the loading state
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(AppColors.greyDarker, AppColors.greyDark, _controller.value),
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circle ? null : BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
    );
  }
}
