import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_spacing.dart';
import 'heading.dart';
import 'skeleton.dart';

/// Titled horizontal row of cards: skeletons while loading, an error widget on failure, the cards when ready.
/// Place it without horizontal padding: the row scrolls up to the screen edges and applies the side margin itself.
class MediaSection<T> extends StatelessWidget {
  const MediaSection({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.errorBuilder,
    this.skeletonShape = SkeletonShape.rectangle,
    this.skeletonCount = 7,
  });

  final String title;
  final AsyncValue<List<T>> items;
  final Widget Function(T item) itemBuilder;
  final Widget Function(Object error) errorBuilder;
  final SkeletonShape skeletonShape;
  final int skeletonCount;

  static const EdgeInsets _sideMargin = EdgeInsets.symmetric(horizontal: AppSpacing.paddingLg);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: _sideMargin,
          child: Heading(title, style: HeadingStyle.h4),
        ),
        const SizedBox(height: AppSpacing.paddingMd),
        // isLoading first: after Retry the value can still hold the previous error while reloading
        if (items.isLoading)
          Semantics(label: 'Loading $title', child: _row(List.generate(skeletonCount, (_) => _skeletonCard())))
        else if (items.hasError)
          Padding(padding: _sideMargin, child: errorBuilder(items.error!))
        else
          _row((items.value ?? []).map(itemBuilder).toList()),
      ],
    );
  }

  // A Row inside a scroll view sizes itself to the cards, so text scaling never cuts them.
  // The margin is inside the scroll view, so cards scroll up to the screen edge.
  Widget _row(List<Widget> children) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: _sideMargin,
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: AppSpacing.paddingMd, children: children),
  );

  Widget _skeletonCard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: AppSpacing.paddingSm,
    children: [
      Skeleton(width: AppSpacing.mediaCard, height: AppSpacing.mediaCard, shape: skeletonShape),
      const Skeleton(width: AppSpacing.mediaCard, height: AppSpacing.paddingMd),
    ],
  );
}
