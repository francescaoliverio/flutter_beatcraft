import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_spacing.dart';
import 'heading.dart';
import 'skeleton.dart';

/// Titled horizontal row of cards: skeletons while loading, an error widget on failure, the cards when ready.
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Heading(title, style: HeadingStyle.h4),
        const SizedBox(height: AppSpacing.paddingMd),
        // isLoading first: after Retry the value can still hold the previous error while reloading
        if (items.isLoading)
          Semantics(label: 'Loading $title', child: _row(List.generate(skeletonCount, (_) => _skeletonCard())))
        else if (items.hasError)
          errorBuilder(items.error!)
        else
          _row((items.value ?? []).map(itemBuilder).toList()),
      ],
    );
  }

  // A Row inside a scroll view sizes itself to the cards, so text scaling never cuts them
  Widget _row(List<Widget> children) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
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
