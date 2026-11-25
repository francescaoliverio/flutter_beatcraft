import 'dart:math';
import 'dart:typed_data';

// SemanticsProperties for the clips drawn on the timeline: material_ui doesn't export it
import 'package:flutter/semantics.dart' show SemanticsProperties;
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
        // Scrolls on small screens and with large text; horizontal drags still reach the timeline
        child: SingleChildScrollView(
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
                const SizedBox(height: 240, child: Placeholder(color: AppColors.greyDark))
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
    final bool hasSelection = editor.selectedClip != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: AppSpacing.paddingMd,
          children: [
            Button(
              icon: editor.isPlaying ? PhosphorIconsRegular.pause : PhosphorIconsRegular.play,
              semanticLabel: editor.isPlaying ? 'Pause' : 'Play',
              onPressed: editor.clips.isEmpty ? null : controls.toggle,
            ),
            Expanded(
              child: Text(
                '${_formatTime(editor.position)} / ${_formatTime(editor.length)}',
                style: AppTextStyles.pBold.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
            IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowUUpLeft),
              tooltip: 'Undo',
              onPressed: editor.canUndo ? controls.undo : null,
            ),
            IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowUUpRight),
              tooltip: 'Redo',
              onPressed: editor.canRedo ? controls.redo : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.paddingMd),
        _Timeline(editor: editor, controls: controls),
        const SizedBox(height: AppSpacing.paddingMd),
        // Same pattern as the player actions: equal widths and heights
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.paddingSm,
            children: [
              _Tool(
                label: 'Split',
                semanticLabel: 'Split at playhead',
                icon: PhosphorIconsRegular.scissors,
                onPressed: editor.clipToSplit == null ? null : controls.split,
              ),
              _Tool(
                label: 'Duplicate',
                icon: PhosphorIconsRegular.copy,
                onPressed: hasSelection ? controls.duplicateSelected : null,
              ),
              _Tool(
                label: 'Delete',
                icon: PhosphorIconsRegular.trash,
                onPressed: hasSelection ? controls.deleteSelected : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.paddingMd),
        Text(
          editor.clips.isEmpty
              ? 'No clips left. Undo to bring them back.'
              : 'Tap a clip to select it, drag it to move it. Split cuts at the playhead.',
          style: AppTextStyles.pSm.copyWith(color: AppColors.greyLight),
        ),
      ],
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.label, required this.icon, required this.onPressed, this.semanticLabel});

  final String label;
  final String? semanticLabel;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Button(
        label: label,
        semanticLabel: semanticLabel,
        icon: icon,
        color: ButtonColor.secondary,
        variant: ButtonVariant.outline,
        layout: ButtonLayout.vertical,
        onPressed: onPressed,
      ),
    );
  }
}

/// Ruler, clips with their waveform and the playhead.
/// Tap: moves the playhead and selects the clip under the finger.
/// Drag a clip: moves it. Drag elsewhere: moves the playhead.
class _Timeline extends StatefulWidget {
  const _Timeline({required this.editor, required this.controls});

  final EditorState editor;
  final EditorNotifier controls;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  static const double _rulerHeight = 24;
  static const double _laneHeight = 120;

  /// Distance in px within which a dragged clip snaps to 0, the playhead or the edges of other clips.
  static const double _snapDistance = 12;

  /// Playhead step for screen reader swipes up and down.
  static const Duration _playheadStep = Duration(seconds: 5);

  /// Clip step for screen reader swipes up and down on a clip.
  static const Duration _clipStep = Duration(seconds: 1);

  /// Clip being dragged and where it would land. Applied to the remix only when the finger lifts.
  int? _dragClipId;
  Duration _dragStart = Duration.zero;

  /// Time between the clip start and the finger when the drag began.
  Duration _grabOffset = Duration.zero;

  /// Timeline scale frozen during a drag, so the timeline doesn't rescale under the finger.
  double? _dragPxPerMs;

  /// Latest start that keeps the dragged clip inside the visible timeline.
  Duration _dragMaxStart = Duration.zero;

  EditorState get _editor => widget.editor;

  /// The visible timeline: the longer of track and remix, plus a quarter of the track of free space to drag into.
  Duration get _viewLength {
    final Duration longest = _editor.length > _editor.trackLength ? _editor.length : _editor.trackLength;
    return longest + _editor.trackLength * 0.25;
  }

  /// Clips with the dragged one at its preview position.
  List<TimelineClip> get _shownClips => _dragClipId == null
      ? _editor.clips
      : [
          for (final TimelineClip clip in _editor.clips)
            if (clip.id == _dragClipId) clip.copyWith(timelineStart: _dragStart) else clip,
        ];

  Duration _timeAt(double x, double pxPerMs) => Duration(milliseconds: max(0, x / pxPerMs).round());

  /// The selected clip if it is under [time], otherwise the topmost clip there.
  TimelineClip? _clipAt(Duration time) {
    final TimelineClip? selected = _editor.selectedClip;
    if (selected != null && selected.covers(time)) return selected;
    return _editor.clips.reversed.where((clip) => clip.covers(time)).firstOrNull;
  }

  void _onTapUp(TapUpDetails details, double pxPerMs) {
    final Duration time = _timeAt(details.localPosition.dx, pxPerMs);
    if (details.localPosition.dy > _rulerHeight) widget.controls.select(_clipAt(time)?.id);
    widget.controls.seek(time);
  }

  void _onDragStart(DragStartDetails details, double pxPerMs, double width) {
    if (details.localPosition.dy <= _rulerHeight) return;
    final Duration time = _timeAt(details.localPosition.dx, pxPerMs);
    final TimelineClip? clip = _clipAt(time);
    if (clip == null) return;
    widget.controls.select(clip.id);
    setState(() {
      _dragClipId = clip.id;
      _dragStart = clip.timelineStart;
      _grabOffset = time - clip.timelineStart;
      _dragPxPerMs = pxPerMs;
      final Duration maxStart = _timeAt(width, pxPerMs) - clip.length;
      _dragMaxStart = maxStart < Duration.zero ? Duration.zero : maxStart;
    });
  }

  void _onDragUpdate(DragUpdateDetails details, double pxPerMs) {
    final double? dragPxPerMs = _dragPxPerMs;
    if (dragPxPerMs == null) {
      widget.controls.seek(_timeAt(details.localPosition.dx, pxPerMs));
      return;
    }
    final TimelineClip clip = _editor.clips.firstWhere((c) => c.id == _dragClipId);
    final Duration wanted = _timeAt(details.localPosition.dx, dragPxPerMs) - _grabOffset;
    final Duration inside = wanted < Duration.zero ? Duration.zero : (wanted > _dragMaxStart ? _dragMaxStart : wanted);
    setState(() => _dragStart = _snap(clip, inside, dragPxPerMs));
  }

  void _onDragEnd() {
    final int? clipId = _dragClipId;
    if (clipId == null) return;
    widget.controls.move(clipId, _dragStart);
    setState(() {
      _dragClipId = null;
      _dragPxPerMs = null;
    });
  }

  /// Moves [start] onto a nearby edge, so clips can sit back to back without gaps.
  Duration _snap(TimelineClip clip, Duration start, double pxPerMs) {
    final List<Duration> edges = [
      Duration.zero,
      _editor.position,
      for (final TimelineClip other in _editor.clips)
        if (other.id != clip.id) ...[other.timelineStart, other.timelineEnd],
    ];
    final Duration end = start + clip.length;
    Duration best = start;
    double bestDistance = _snapDistance;
    void consider(Duration candidate, Duration gap) {
      final double distance = gap.inMilliseconds.abs() * pxPerMs;
      if (candidate >= Duration.zero && distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }

    for (final Duration edge in edges) {
      // The start of the dragged clip on the edge, or its end
      consider(edge, start - edge);
      consider(edge - clip.length, end - edge);
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double pxPerMs = _dragPxPerMs ?? width / max(1, _viewLength.inMilliseconds);

        return Semantics(
          container: true,
          label: 'Timeline, playhead',
          value: '${_formatTime(_editor.position)} of ${_formatTime(_editor.length)}',
          onIncrease: () => widget.controls.seek(_editor.position + _playheadStep),
          onDecrease: () => widget.controls.seek(_editor.position - _playheadStep),
          child: GestureDetector(
            // Screen readers use the explicit actions of the timeline and of each clip instead
            excludeFromSemantics: true,
            onTapUp: (details) => _onTapUp(details, pxPerMs),
            onHorizontalDragStart: (details) => _onDragStart(details, pxPerMs, width),
            onHorizontalDragUpdate: (details) => _onDragUpdate(details, pxPerMs),
            onHorizontalDragEnd: (_) => _onDragEnd(),
            onHorizontalDragCancel: _onDragEnd,
            child: CustomPaint(
              size: Size(width, _rulerHeight + _laneHeight),
              painter: _TimelinePainter(
                clips: _shownClips,
                selectedClipId: _editor.selectedClipId,
                waveform: _editor.waveform,
                trackLength: _editor.trackLength,
                pxPerMs: pxPerMs,
                position: _editor.position,
                rulerHeight: _rulerHeight,
                onSelect: widget.controls.select,
                onNudge: (clip, step) => widget.controls.move(clip.id, clip.timelineStart + step),
                nudgeStep: _clipStep,
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
    required this.selectedClipId,
    required this.waveform,
    required this.trackLength,
    required this.pxPerMs,
    required this.position,
    required this.rulerHeight,
    required this.onSelect,
    required this.onNudge,
    required this.nudgeStep,
  });

  final List<TimelineClip> clips;
  final int? selectedClipId;
  final Float32List waveform;
  final Duration trackLength;
  final double pxPerMs;
  final Duration position;
  final double rulerHeight;

  /// For screen readers, which select and move clips without dragging.
  final ValueChanged<int?> onSelect;
  final void Function(TimelineClip clip, Duration step) onNudge;
  final Duration nudgeStep;

  /// Horizontal distance between waveform bars.
  static const double _barStep = 3;

  static const Radius _radius = Radius.circular(AppSpacing.radiusMd);

  Rect _clipRect(TimelineClip clip, Size size) => Rect.fromLTRB(
    clip.timelineStart.inMilliseconds * pxPerMs,
    rulerHeight,
    clip.timelineEnd.inMilliseconds * pxPerMs,
    size.height,
  );

  /// Clips in drawing order, the selected one last so it is on top.
  Iterable<TimelineClip> get _ordered => [
    ...clips.where((clip) => clip.id != selectedClipId),
    ...clips.where((clip) => clip.id == selectedClipId),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (trackLength <= Duration.zero) return;
    _paintRuler(canvas, size);
    // The loudest point fills the clip height
    final double peak = waveform.isEmpty ? 1 : max(waveform.reduce(max), 0.0001);
    for (final TimelineClip clip in _ordered) {
      _paintClip(canvas, size, clip, peak);
    }
    _paintPlayhead(canvas, size);
  }

  void _paintRuler(Canvas canvas, Size size) {
    final Paint tickPaint = Paint()
      ..color = AppColors.greyDark
      ..strokeWidth = 1;
    final int msTotal = (size.width / pxPerMs).floor();
    // A tick every 5 seconds, a label every 30
    for (int ms = 0; ms <= msTotal; ms += 5000) {
      final double x = ms * pxPerMs;
      final bool labelled = ms % 30000 == 0;
      canvas.drawLine(Offset(x, rulerHeight - (labelled ? 10 : 5)), Offset(x, rulerHeight), tickPaint);
      if (!labelled) continue;
      final TextPainter label = TextPainter(
        text: TextSpan(
          text: '${ms ~/ 60000}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}',
          style: AppTextStyles.pSm.copyWith(color: AppColors.greyLight),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (x + 2 + label.width <= size.width) label.paint(canvas, Offset(x + 2, 0));
    }
  }

  void _paintClip(Canvas canvas, Size size, TimelineClip clip, double peak) {
    final Rect rect = _clipRect(clip, size);
    final bool selected = clip.id == selectedClipId;
    final RRect shape = RRect.fromRectAndRadius(rect, _radius);
    canvas.drawRRect(shape, Paint()..color = selected ? AppColors.greyDark : AppColors.greyDarker);

    if (waveform.isNotEmpty) {
      final Paint barPaint = Paint()
        ..color = AppColors.secondary
        ..strokeWidth = 2;
      final double middle = rect.center.dy;
      for (double x = rect.left + _barStep / 2; x < rect.right; x += _barStep) {
        // Point of the original track under this bar
        final double sourceMs = clip.sourceStart.inMilliseconds + (x - rect.left) / pxPerMs;
        final int index = (sourceMs / trackLength.inMilliseconds * waveform.length).floor().clamp(
          0,
          waveform.length - 1,
        );
        final double halfBar = waveform[index] / peak * rect.height * 0.45;
        canvas.drawLine(Offset(x, middle - halfBar), Offset(x, middle + halfBar), barPaint);
      }
    }

    // Outline so back-to-back clips stay distinguishable; thicker and lime when selected
    canvas.drawRRect(
      shape.deflate(selected ? 1 : 0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2 : 1
        ..color = selected ? AppColors.primary : AppColors.bgDark,
    );
  }

  void _paintPlayhead(Canvas canvas, Size size) {
    final double x = position.inMilliseconds * pxPerMs;
    final Paint paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    canvas.drawPath(
      Path()
        ..moveTo(x - 6, 0)
        ..lineTo(x + 6, 0)
        ..lineTo(x, 8)
        ..close(),
      paint,
    );
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (Size size) => [
        for (final (int i, TimelineClip clip) in clips.indexed)
          CustomPainterSemantics(
            key: ValueKey<int>(clip.id),
            rect: _clipRect(clip, size),
            properties: SemanticsProperties(
              label: 'Clip ${i + 1}',
              value: '${_formatTime(clip.timelineStart)} to ${_formatTime(clip.timelineEnd)}',
              hint: 'Swipe up or down to move it by one second',
              selected: clip.id == selectedClipId,
              button: true,
              textDirection: TextDirection.ltr,
              onTap: () => onSelect(clip.id),
              onIncrease: () => onNudge(clip, nudgeStep),
              onDecrease: () => onNudge(clip, -nudgeStep),
            ),
          ),
      ];

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.position != position ||
      old.clips != clips ||
      old.selectedClipId != selectedClipId ||
      old.waveform != waveform ||
      old.pxPerMs != pxPerMs ||
      old.trackLength != trackLength;

  @override
  bool shouldRebuildSemantics(_TimelinePainter old) =>
      old.clips != clips || old.selectedClipId != selectedClipId || old.pxPerMs != pxPerMs;
}
