import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../models/track.dart';
import '../providers/link_launcher_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Opens [url] in the browser, or shows [failure] if it can't.
Future<void> openLink(BuildContext context, WidgetRef ref, String? url, {required String failure}) async {
  final bool opened = url != null && await ref.read(linkLauncherProvider).open(url);
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(failure), showCloseIcon: true));
}

/// Opens the page of [track] on Jamendo in the browser, or says it couldn't.
Future<void> openOnJamendo(BuildContext context, WidgetRef ref, Track track) =>
    openLink(context, ref, track.shareUrl, failure: "Couldn't open the track on Jamendo.");

/// Underlined text that opens a web page: greyLight, lighter while pressed, at least 44 px tall to tap.
/// One link for screen readers, read as [semanticLabel].
class _Link extends StatefulWidget {
  const _Link({
    required this.text,
    required this.semanticLabel,
    required this.onTap,
    this.prefix = '',
    this.hint,
    this.alignment = Alignment.centerLeft,
  });

  /// Not underlined, before [text].
  final String prefix;
  final String text;
  final String semanticLabel;

  /// What the link opens, read after [semanticLabel].
  final String? hint;
  final VoidCallback onTap;
  final AlignmentGeometry alignment;

  @override
  State<_Link> createState() => _LinkState();
}

class _LinkState extends State<_Link> {
  static const double _minHeight = 44;

  bool _pressed = false;

  void _setPressed(bool pressed) => setState(() => _pressed = pressed);

  @override
  Widget build(BuildContext context) {
    final TextStyle style = AppTextStyles.p.copyWith(color: _pressed ? AppColors.greyLighter : AppColors.greyLight);
    return Semantics(
      link: true,
      label: widget.semanticLabel,
      hint: widget.hint,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Align(
            alignment: widget.alignment,
            child: Text.rich(
              TextSpan(
                text: widget.prefix,
                children: [
                  TextSpan(
                    text: widget.text,
                    style: style.copyWith(decoration: TextDecoration.underline, decorationColor: style.color),
                  ),
                ],
              ),
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

/// Credits the original track, as its Creative Commons license requires, and links to its page on Jamendo.
class TrackCredit extends ConsumerWidget {
  const TrackCredit({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Link(
      prefix: 'From ',
      text: '${track.name} by ${track.artistName} · via Jamendo',
      semanticLabel: 'From ${track.name} by ${track.artistName} via Jamendo',
      hint: 'Opens the track page on Jamendo',
      onTap: () => openOnJamendo(context, ref, track),
    );
  }
}

/// A link to a web page, such as an artist's page on Jamendo or their site.
class ExternalLink extends ConsumerWidget {
  const ExternalLink({
    super.key,
    required this.text,
    required this.url,
    required this.semanticLabel,
    this.alignment = Alignment.centerLeft,
  });

  final String text;
  final String url;
  final String semanticLabel;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Link(
      text: text,
      semanticLabel: semanticLabel,
      alignment: alignment,
      onTap: () => openLink(context, ref, url, failure: "Couldn't open the page."),
    );
  }
}
