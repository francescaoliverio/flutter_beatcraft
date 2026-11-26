import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../models/track.dart';
import '../providers/favorites_provider.dart';
import '../providers/playback_provider.dart';
import '../providers/player_provider.dart';
import '../providers/remix_provider.dart';
import '../providers/shell_tab_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/button.dart';
import '../widgets/error_box.dart';
import '../widgets/heading.dart';
import '../widgets/jamendo_link.dart';

/// Minutes and seconds, e.g. 3:08.
String _formatTime(Duration time) {
  final String seconds = (time.inSeconds % 60).toString().padLeft(2, '0');
  return '${time.inMinutes}:$seconds';
}

/// Opens the player as a full screen sheet: it slides up from the bottom, and slides down when closed
/// with the arrow or a swipe down.
Future<void> showPlayer(BuildContext context) {
  // The sheet removes the top padding: restated here so the app bar stays below the status bar.
  // Read from the root navigator: [context] may be inside a SafeArea, which has already removed it
  final MediaQueryData media = MediaQuery.of(Navigator.of(context, rootNavigator: true).context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.bgDark,
    // Square corners and no maximum width (Material 3 limits sheets to 640): the sheet covers the whole screen
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints(),
    builder: (_) => MediaQuery(data: media, child: const PlayerScreen()),
  );
}

/// Now playing: cover, track info, progress, controls. Opened with [showPlayer].
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  /// Slider position while it's being dragged: the seek happens only on release.
  double? _dragSeconds;

  /// How far a swipe down at the top of the content closes the player.
  static const double _pullToClose = 80;

  /// Pull down beyond the top so far, and whether the player is already closing.
  double _pulled = 0;
  bool _closing = false;

  /// When the content is taller than the screen the swipe scrolls it instead of moving the sheet:
  /// pulling down at the top closes the player, as the sheet would.
  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) _pulled = 0;
    // iOS bounces past the top, Android reports the pull as overscroll
    if (notification is ScrollUpdateNotification && notification.dragDetails != null) {
      if (notification.metrics.pixels < 0) _pulled = -notification.metrics.pixels;
    } else if (notification is OverscrollNotification && notification.dragDetails != null) {
      if (notification.overscroll < 0) _pulled -= notification.overscroll;
    }
    if (_pulled >= _pullToClose && !_closing) {
      _closing = true;
      Navigator.of(context).pop();
    }
    return false;
  }

  /// Closes the player on the Create tab, with [track] ready to remix.
  void _openInCreate(Track track) {
    ref.read(remixProvider.notifier).newRemix(track);
    ref.read(shellTabProvider.notifier).select(ShellTab.create);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Track? track = ref.watch(currentTrackProvider).value;
    final PlaybackState playback = ref.watch(playbackProvider);
    final PlaybackNotifier controls = ref.read(playbackProvider.notifier);
    final List<String>? favorites = ref.watch(favoritesProvider).value;
    final bool isLiked = track != null && (favorites?.contains(track.id) ?? false);

    // Playback refers to another track only while the restored track hasn't been loaded yet
    final bool isThisTrack = track != null && playback.trackId == track.id;
    final PlaybackStatus status = isThisTrack ? playback.status : PlaybackStatus.idle;
    // A Slider needs max > min: before the track is loaded the bar shows an empty 0..1 range
    final double maxSeconds = isThisTrack && playback.duration > Duration.zero
        ? playback.duration.inMilliseconds / 1000
        : 1;
    final double seconds = _dragSeconds ?? (isThisTrack ? playback.position.inMilliseconds / 1000 : 0);

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.caretDown),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        // Opened only after a track is selected, so track is null only for an instant
        body: track == null
            ? const SizedBox.shrink()
            // Scrolls on small screens and with large text instead of overflowing
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.paddingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        child: Image.network(
                          track.image,
                          fit: BoxFit.cover,
                          // Cover is decorative: title and artist are read below
                          excludeFromSemantics: true,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(track.fallbackCoverAsset, fit: BoxFit.cover, excludeFromSemantics: true),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingLg),
                    Heading(track.name, style: HeadingStyle.h3, uppercase: false),
                    Text(
                      '${track.artistName} · via Jamendo',
                      style: AppTextStyles.p.copyWith(color: AppColors.greyLight),
                    ),
                    const SizedBox(height: AppSpacing.paddingMd),
                    // Equal widths from Expanded, equal heights from IntrinsicHeight (also if a label wraps)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        // Same gap as the cards in the Home rows
                        spacing: AppSpacing.paddingMd,
                        children: [
                          Expanded(
                            child: Button(
                              label: 'Share',
                              // Says where the button goes: it opens the track page, where Jamendo offers sharing
                              semanticLabel: 'Share, opens the track page on Jamendo',
                              icon: PhosphorIconsRegular.export,
                              color: ButtonColor.tertiary,
                              variant: ButtonVariant.outline,
                              layout: ButtonLayout.vertical,
                              onPressed: track.shareUrl == null ? null : () => openOnJamendo(context, ref, track),
                            ),
                          ),
                          Expanded(
                            child: Button(
                              label: track.canRemix ? 'Remix' : 'Not allowed',
                              semanticLabel: track.canRemix ? null : 'Remix not allowed',
                              icon: PhosphorIconsRegular.waveform,
                              color: ButtonColor.tertiary,
                              variant: ButtonVariant.outline,
                              layout: ButtonLayout.vertical,
                              onPressed: track.canRemix ? () => _openInCreate(track) : null,
                            ),
                          ),
                          Expanded(
                            child: Button(
                              label: isLiked ? 'Liked' : 'Like',
                              icon: isLiked ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                              color: ButtonColor.tertiary,
                              variant: ButtonVariant.outline,
                              layout: ButtonLayout.vertical,
                              // Disabled until the saved likes are read
                              onPressed: favorites == null
                                  ? null
                                  : () => ref.read(favoritesProvider.notifier).toggle(track.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingMd),
                    if (status == PlaybackStatus.error)
                      ErrorBox(
                        title: "Can't play this track",
                        description: 'Check your connection and try again.',
                        onRetry: controls.toggle,
                      )
                    else ...[
                      Slider(
                        value: seconds.clamp(0.0, maxSeconds),
                        max: maxSeconds,
                        // Disabled until the track is loaded
                        onChanged: isThisTrack && playback.isReady
                            ? (value) => setState(() => _dragSeconds = value)
                            : null,
                        onChangeEnd: (value) {
                          controls.seek(Duration(milliseconds: (value * 1000).round()));
                          setState(() => _dragSeconds = null);
                        },
                        // Screen readers announce the time instead of a percentage
                        semanticFormatterCallback: (value) =>
                            '${_formatTime(Duration(seconds: value.floor()))} of ${_formatTime(playback.duration)}',
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Truncated like the duration, so the end shows the same time on both sides
                          Text(_formatTime(Duration(seconds: seconds.floor())), style: AppTextStyles.pSm),
                          Text(_formatTime(isThisTrack ? playback.duration : Duration.zero), style: AppTextStyles.pSm),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.paddingMd),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: AppSpacing.paddingLg,
                      children: [
                        IconButton(
                          icon: const Icon(PhosphorIconsRegular.skipBack),
                          tooltip: 'Previous',
                          // Also without a queue: it starts the track again
                          onPressed: playback.hasQueue || (isThisTrack && playback.isReady) ? controls.previous : null,
                        ),
                        Button(
                          icon: status == PlaybackStatus.playing
                              ? PhosphorIconsRegular.pause
                              : PhosphorIconsRegular.play,
                          semanticLabel: switch (status) {
                            PlaybackStatus.playing => 'Pause',
                            PlaybackStatus.loading => 'Loading',
                            _ => 'Play',
                          },
                          onPressed: status == PlaybackStatus.loading ? null : controls.toggle,
                        ),
                        IconButton(
                          icon: const Icon(PhosphorIconsRegular.skipForward),
                          tooltip: 'Next',
                          onPressed: playback.hasQueue ? controls.next : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
