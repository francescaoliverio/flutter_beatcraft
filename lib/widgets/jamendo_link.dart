import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../models/track.dart';
import '../providers/link_launcher_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Opens the page of [track] on Jamendo in the browser, or says it couldn't.
Future<void> openOnJamendo(BuildContext context, WidgetRef ref, Track track) async {
  final String? url = track.shareUrl;
  final bool opened = url != null && await ref.read(linkLauncherProvider).open(url);
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text("Couldn't open the track on Jamendo."), showCloseIcon: true));
}

/// Credits the original track, as its Creative Commons license requires, and links to its page on Jamendo.
/// One link for screen readers, at least 44 px tall to tap.
class TrackCredit extends ConsumerStatefulWidget {
  const TrackCredit({super.key, required this.track});

  final Track track;

  @override
  ConsumerState<TrackCredit> createState() => _TrackCreditState();
}

class _TrackCreditState extends ConsumerState<TrackCredit> {
  static const double _minHeight = 44;

  bool _pressed = false;

  void _setPressed(bool pressed) => setState(() => _pressed = pressed);

  @override
  Widget build(BuildContext context) {
    final Track track = widget.track;
    final TextStyle style = AppTextStyles.p.copyWith(color: _pressed ? AppColors.greyLighter : AppColors.greyLight);
    return Semantics(
      link: true,
      label: 'From ${track.name} by ${track.artistName} via Jamendo',
      hint: 'Opens the track page on Jamendo',
      excludeSemantics: true,
      onTap: () => openOnJamendo(context, ref, track),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () => openOnJamendo(context, ref, track),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: 'From ',
                children: [
                  TextSpan(
                    text: '${track.name} by ${track.artistName} · via Jamendo',
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
