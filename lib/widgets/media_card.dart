import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'skeleton.dart';

enum MediaCardShape { square, circle }

/// Image with a title and an optional subtitle, for tracks, artists and playlists.
/// Screen readers read it as one item, and as a button only when [onTap] is set.
/// An optional [imageAction] sits on the top right of the image and is read as a separate control.
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    this.shape = MediaCardShape.square,
    this.fallbackImage,
    this.onTap,
    this.imageAction,
  });

  final ImageProvider image;
  final String title;
  final String? subtitle;
  final MediaCardShape shape;

  /// Shown if [image] fails to load.
  final ImageProvider? fallbackImage;

  final VoidCallback? onTap;

  /// Small control over the image, e.g. a like button.
  final Widget? imageAction;

  @override
  Widget build(BuildContext context) {
    final bool circle = shape == MediaCardShape.circle;
    // Decode at the displayed size, not at the file size (assets are 1024 px)
    final int cacheWidth = (AppSpacing.mediaCard * MediaQuery.devicePixelRatioOf(context)).round();

    Widget picture(ImageProvider provider) => Image(
      image: ResizeImage.resizeIfNeeded(cacheWidth, null, provider),
      width: AppSpacing.mediaCard,
      height: AppSpacing.mediaCard,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          frame == null && !wasSynchronouslyLoaded ? _placeholder(circle) : child,
      errorBuilder: (context, error, stackTrace) =>
          fallbackImage != null && provider != fallbackImage ? picture(fallbackImage!) : _emptyImage(),
    );

    final Widget card = Semantics(
      container: true,
      button: onTap != null,
      label: subtitle == null ? title : '$title, $subtitle',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: AppSpacing.mediaCard,
          child: Column(
            crossAxisAlignment: circle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(circle ? AppSpacing.radiusPill : AppSpacing.radiusMd),
                child: picture(image),
              ),
              const SizedBox(height: AppSpacing.paddingSm),
              Text(
                title,
                style: AppTextStyles.pBold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: circle ? TextAlign.center : TextAlign.start,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTextStyles.pSm.copyWith(color: AppColors.greyLight),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: circle ? TextAlign.center : TextAlign.start,
                ),
            ],
          ),
        ),
      ),
    );

    if (imageAction == null) return card;
    // Outside the card's Semantics, so screen readers don't merge it into the card label
    return Stack(
      children: [
        card,
        Positioned(top: 0, right: 0, child: imageAction!),
      ],
    );
  }

  Widget _placeholder(bool circle) => Skeleton(
    width: AppSpacing.mediaCard,
    height: AppSpacing.mediaCard,
    shape: circle ? SkeletonShape.circle : SkeletonShape.rectangle,
  );

  Widget _emptyImage() =>
      Container(width: AppSpacing.mediaCard, height: AppSpacing.mediaCard, color: AppColors.greyDarker);
}
