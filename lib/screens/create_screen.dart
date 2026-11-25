import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../models/timeline_clip.dart';
import '../providers/editor_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/button.dart';
import '../widgets/error_box.dart';
import '../widgets/heading.dart';

/// Minutes, seconds and tenths, e.g. 1:08.4.
String _formatTime(Duration time) {
  final String seconds = (time.inSeconds % 60).toString().padLeft(2, '0');
  return '${time.inMinutes}:$seconds.${time.inMilliseconds % 1000 ~/ 100}';
}

/// Remix editor: timeline with clips, playback and editing tools.
class CreateScreen extends ConsumerWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EditorState?> editor = ref.watch(editorProvider);
    final EditorState? loaded = editor.value;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.paddingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Heading('Create')),
                  Button(label: 'Save', icon: PhosphorIconsRegular.floppyDisk, onPressed: () {}),
                ],
              ),
              const SizedBox(height: AppSpacing.paddingMd),
              const Heading('Remix name', style: HeadingStyle.h4, uppercase: false),
              // Credits the original track, as its Creative Commons license requires
              if (loaded != null)
                Text(
                  'From ${loaded.track.name} by ${loaded.track.artistName} · via Jamendo',
                  style: AppTextStyles.p.copyWith(color: AppColors.greyLight),
                ),
              const SizedBox(height: AppSpacing.paddingLg),
              // isLoading first: after Retry the value can still hold the previous error while reloading
              if (editor.isLoading)
                Semantics(
                  label: 'Loading track',
                  child: const Center(child: CircularProgressIndicator(color: AppColors.secondary)),
                )
              else if (editor.hasError)
                ErrorBox(
                  title: "Couldn't load the track",
                  description: 'Check your connection and try again.',
                  onRetry: () => ref.invalidate(editorProvider),
                )
              else if (loaded == null)
                // TODO: initial state of Create without a track
                const Expanded(child: Placeholder(color: AppColors.greyDark))
              else
                _Editor(editor: loaded),
            ],
          ),
        ),
      ),
    );
  }
}

class _Editor extends ConsumerWidget {
  const _Editor({required this.editor});

  final EditorState editor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EditorNotifier controls = ref.read(editorProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: AppSpacing.paddingMd,
          children: [
            Button(
              icon: editor.isPlaying ? PhosphorIconsRegular.pause : PhosphorIconsRegular.play,
              semanticLabel: editor.isPlaying ? 'Pause' : 'Play',
              onPressed: controls.toggle,
            ),
            Text(
              '${_formatTime(editor.position)} / ${_formatTime(editor.length)}',
              style: AppTextStyles.pBold.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.paddingMd),
        _Timeline(editor: editor, onSeek: controls.seek),
      ],
    );
  }
}

/// Clips with their waveform and the playhead. Tap or drag to move the playhead.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.editor, required this.onSeek});

  final EditorState editor;
  final ValueChanged<Duration> onSeek;

  static const double _height = 120;

  /// Playhead step for screen reader swipes up and down.
  static const Duration _semanticStep = Duration(seconds: 5);

  @override
  Widget build(BuildContext context) {
    final String position = _formatTime(editor.position);
    final String length = _formatTime(editor.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        void seekToX(double x) {
          final double fraction = (x / constraints.maxWidth).clamp(0.0, 1.0);
          onSeek(editor.length * fraction);
        }

        return Semantics(
          label: 'Timeline',
          value: '$position of $length',
          onIncrease: () => onSeek(editor.position + _semanticStep),
          onDecrease: () => onSeek(editor.position - _semanticStep),
          child: GestureDetector(
            onTapDown: (details) => seekToX(details.localPosition.dx),
            onHorizontalDragUpdate: (details) => seekToX(details.localPosition.dx),
            child: CustomPaint(
              size: Size(constraints.maxWidth, _height),
              painter: _TimelinePainter(
                clips: editor.clips,
                waveform: editor.waveform,
                trackLength: editor.trackLength,
                length: editor.length,
                position: editor.position,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.clips,
    required this.waveform,
    required this.trackLength,
    required this.length,
    required this.position,
  });

  final List<TimelineClip> clips;
  final Float32List waveform;
  final Duration trackLength;
  final Duration length;
  final Duration position;

  /// Horizontal distance between waveform bars.
  static const double _barStep = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (length <= Duration.zero || trackLength <= Duration.zero) return;
    final double pxPerMs = size.width / length.inMilliseconds;
    // The loudest point fills the clip height
    final double peak = waveform.isEmpty ? 1 : max(waveform.reduce(max), 0.0001);

    final Paint clipPaint = Paint()..color = AppColors.greyDarker;
    final Paint barPaint = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 2;

    for (final TimelineClip clip in clips) {
      final double left = clip.timelineStart.inMilliseconds * pxPerMs;
      final double right = clip.timelineEnd.inMilliseconds * pxPerMs;
      canvas.drawRRect(
        RRect.fromLTRBR(left, 0, right, size.height, const Radius.circular(AppSpacing.radiusMd)),
        clipPaint,
      );
      if (waveform.isEmpty) continue;
      for (double x = left + _barStep / 2; x < right; x += _barStep) {
        // Point of the original track under this bar
        final double sourceMs = clip.sourceStart.inMilliseconds + (x - left) / pxPerMs;
        final int index = (sourceMs / trackLength.inMilliseconds * waveform.length).floor().clamp(
          0,
          waveform.length - 1,
        );
        final double halfBar = waveform[index] / peak * size.height * 0.45;
        canvas.drawLine(Offset(x, size.height / 2 - halfBar), Offset(x, size.height / 2 + halfBar), barPaint);
      }
    }

    final double playheadX = position.inMilliseconds * pxPerMs;
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.position != position ||
      old.clips != clips ||
      old.waveform != waveform ||
      old.length != length ||
      old.trackLength != trackLength;
}
