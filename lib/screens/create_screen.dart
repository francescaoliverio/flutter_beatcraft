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
import '../widgets/empty_state.dart';
import '../widgets/error_box.dart';
import '../widgets/heading.dart';

/// Minutes, seconds and tenths, e.g. 1:08.4.
String _formatTime(Duration time) {
  final String seconds = (time.inSeconds % 60).toString().padLeft(2, '0');
  return '${time.inMinutes}:$seconds.${time.inMilliseconds % 1000 ~/ 100}';
}

/// Asks for a new remix name. Pops the name, or null if cancelled.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.current});

  final String current;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgDark,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.greyDark),
        borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusMd)),
      ),
      title: const Heading('Rename remix', style: HeadingStyle.h4, uppercase: false),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        Button(
          label: 'Cancel',
          color: ButtonColor.tertiary,
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
        Button(label: 'Rename', onPressed: () => Navigator.of(context).pop(_controller.text)),
      ],
    );
  }
}

/// Remix editor: timeline with clips, playback and editing tools.
class CreateScreen extends ConsumerWidget {
  const CreateScreen({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    await ref.read(editorProvider.notifier).save();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remix saved')));
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, String current) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(current: current),
    );
    if (name != null) ref.read(editorProvider.notifier).rename(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EditorState?> editor = ref.watch(editorProvider);
    // While another remix loads, the previous one is not shown
    final EditorState? loaded = editor.isLoading || editor.hasError ? null : editor.value;
    final bool canSave = loaded != null && loaded.hasUnsavedChanges;

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
                  Button(
                    // Saved: nothing changed since the last save
                    label: loaded != null && !loaded.hasUnsavedChanges ? 'Saved' : 'Save',
                    icon: PhosphorIconsRegular.floppyDisk,
                    onPressed: canSave ? () => _save(context, ref) : null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.paddingMd),
              if (loaded != null) ...[
                Row(
                  children: [
                    Flexible(child: Heading(loaded.name, style: HeadingStyle.h4, uppercase: false)),
                    IconButton(
                      icon: const Icon(PhosphorIconsRegular.pencilSimple),
                      tooltip: 'Rename remix',
                      onPressed: () => _rename(context, ref, loaded.name),
                    ),
                  ],
                ),
                // Credits the original track, as its Creative Commons license requires
                Text(
                  'From ${loaded.track.name} by ${loaded.track.artistName} · via Jamendo',
                  style: AppTextStyles.p.copyWith(color: AppColors.greyLight),
                ),
              ],
              const SizedBox(height: AppSpacing.paddingLg),
              // isLoading first: after Retry the value can still hold the previous error while reloading
              if (editor.isLoading)
                Semantics(
                  label: 'Loading track',
                  child: const Center(child: CircularProgressIndicator(color: AppColors.secondary)),
                )
              else if (editor.error is RemixUnavailableException)
                ErrorBox(
                  title: "This remix can't be opened",
                  description: 'Its track was removed from Jamendo or can no longer be remixed.',
                  onRetry: () => ref.invalidate(editorProvider),
                )
              else if (editor.hasError)
                ErrorBox(
                  title: "Couldn't load the track",
                  description: 'Check your connection and try again.',
                  onRetry: () => ref.invalidate(editorProvider),
                )
              else if (loaded == null)
                const EmptyState(
                  message: 'Open a track in the player and tap Remix, or open a saved remix from your profile.',
                )
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
              _Tool(
                label: 'Close gaps',
                icon: PhosphorIconsRegular.arrowsInLineHorizontal,
                onPressed: editor.hasGaps ? controls.closeGaps : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.paddingMd),
        Text(
          editor.clips.isEmpty
              ? 'No clips left. Undo to bring them back.'
              : 'Tap a clip to select it, drag it to move it. Dropped on another clip, it is inserted there. '
                    'Pinch to zoom, two fingers to scroll.',
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
        color: ButtonColor.tertiary,
        variant: ButtonVariant.outline,
        layout: ButtonLayout.vertical,
        onPressed: onPressed,
      ),
    );
  }
}

/// Ruler, clips with their waveform and the playhead.
/// Tap: moves the playhead and selects the clip under the finger.
/// Drag a clip: moves it. Drag elsewhere, on the ruler or near the playhead: moves the playhead.
/// Two fingers: pinch to zoom, move together to scroll.
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

  /// Distance in px from the playhead line within which a drag moves the playhead, also over a clip.
  static const double _playheadGrab = 20;

  /// Closest zoom: this much time across the whole width.
  static const Duration _minSpan = Duration(seconds: 1);

  /// Zoom step of the + and − buttons.
  static const double _zoomStep = 2;

  /// Playhead step for screen reader swipes up and down.
  static const Duration _playheadStep = Duration(seconds: 5);

  /// Clip step for screen reader swipes up and down on a clip.
  static const Duration _clipStep = Duration(seconds: 1);

  /// Visible time across the width, null when the whole timeline fits.
  Duration? _span;

  /// Time at the left edge.
  Duration _offset = Duration.zero;

  /// Width of the timeline at the last build, for the gesture callbacks.
  double _width = 1;

  /// Clip being dragged and where it would land. Applied to the remix only when the finger lifts.
  int? _dragClipId;
  Duration _dragStart = Duration.zero;

  /// Time between the clip start and the finger when the drag began.
  Duration _grabOffset = Duration.zero;

  /// Fingers on the timeline, to recognise a pinch.
  final Map<int, Offset> _pointers = {};

  /// True from the second finger down until every finger is up: one-finger gestures are ignored meanwhile.
  bool _pinched = false;

  EditorState get _editor => widget.editor;

  /// The whole timeline: the longer of track and remix, plus a quarter of the track of free space to drag into.
  Duration get _viewLength {
    final Duration longest = _editor.length > _editor.trackLength ? _editor.length : _editor.trackLength;
    return longest + _editor.trackLength * 0.25;
  }

  Duration get _visible {
    final Duration? span = _span;
    return span == null || span > _viewLength ? _viewLength : span;
  }

  double get _pxPerMs => _width / max(1, _visible.inMilliseconds);

  Duration _timeAt(double x) => Duration(milliseconds: max(0, _offset.inMilliseconds + x / _pxPerMs).round());

  double _xOf(Duration time) => (time - _offset).inMilliseconds * _pxPerMs;

  Duration _clampOffset(Duration offset) {
    final Duration maxOffset = _viewLength - _visible;
    if (offset < Duration.zero || maxOffset <= Duration.zero) return Duration.zero;
    return offset > maxOffset ? maxOffset : offset;
  }

  /// Zooms by [factor] (above 1: closer) keeping the time under [focalX] in place.
  void _zoom(double factor, double focalX) {
    final double focalMs = _offset.inMilliseconds + focalX / _pxPerMs;
    final int viewMs = _viewLength.inMilliseconds;
    final int spanMs = (_visible.inMilliseconds / factor).round().clamp(
      _minSpan.inMilliseconds,
      max(viewMs, _minSpan.inMilliseconds),
    );
    _span = spanMs >= viewMs ? null : Duration(milliseconds: spanMs);
    _offset = _clampOffset(Duration(milliseconds: (focalMs - focalX * spanMs / _width).round()));
  }

  /// Zoom buttons: around the playhead if it is visible, otherwise around the middle.
  void _zoomButton(double factor) {
    final double playheadX = _xOf(_editor.position);
    setState(() => _zoom(factor, playheadX >= 0 && playheadX <= _width ? playheadX : _width / 2));
  }

  bool get _canZoomIn => _visible > _minSpan;

  bool get _canZoomOut => _span != null && _span! < _viewLength;

  @override
  void didUpdateWidget(_Timeline old) {
    super.didUpdateWidget(old);
    // While playing, the view follows the playhead when it leaves the screen
    if (_editor.isPlaying && _span != null) {
      final double x = _xOf(_editor.position);
      if (x < 0 || x > _width) _offset = _clampOffset(_editor.position - _visible * 0.1);
    }
  }

  /// Where the dragged clip would be inserted if dropped now, null if it would stay where it is.
  Duration? get _insertAt {
    final int? clipId = _dragClipId;
    if (clipId == null) return null;
    final TimelineClip clip = _editor.clips.firstWhere((c) => c.id == clipId);
    return insertionPoint(_editor.clips.where((c) => c.id != clipId).toList(), _dragStart, clip.length);
  }

  /// Playhead value read by screen readers, kept between 0 and the end like a seek does.
  String _playheadValue(Duration position) {
    final Duration clamped = position < Duration.zero
        ? Duration.zero
        : (position > _editor.length ? _editor.length : position);
    return '${_formatTime(clamped)} of ${_formatTime(_editor.length)}';
  }

  /// Clips with the dragged one at its preview position.
  List<TimelineClip> get _shownClips => _dragClipId == null
      ? _editor.clips
      : [
          for (final TimelineClip clip in _editor.clips)
            if (clip.id == _dragClipId) clip.copyWith(timelineStart: _dragStart) else clip,
        ];

  /// The selected clip if it is under [time], otherwise the topmost clip there.
  TimelineClip? _clipAt(Duration time) {
    final TimelineClip? selected = _editor.selectedClip;
    if (selected != null && selected.covers(time)) return selected;
    return _editor.clips.reversed.where((clip) => clip.covers(time)).firstOrNull;
  }

  // Pinch, read from raw pointers so one-finger drags don't wait for a pinch to be ruled out

  void _onPointerDown(PointerDownEvent event) {
    if (_pointers.isEmpty) _pinched = false;
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      // A clip drag in progress is dropped where it started
      setState(() {
        _pinched = true;
        _dragClipId = null;
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    if (_pointers.length != 2) {
      _pointers[event.pointer] = event.localPosition;
      return;
    }
    final List<Offset> before = _pointers.values.toList();
    _pointers[event.pointer] = event.localPosition;
    final List<Offset> after = _pointers.values.toList();
    final double distanceBefore = (before[0] - before[1]).distance;
    final double distanceAfter = (after[0] - after[1]).distance;
    final double focalBefore = (before[0].dx + before[1].dx) / 2;
    final double focalAfter = (after[0].dx + after[1].dx) / 2;
    setState(() {
      if (distanceBefore > 0 && distanceAfter > 0) _zoom(distanceAfter / distanceBefore, focalBefore);
      // Both fingers moving together scroll the timeline
      _offset = _clampOffset(_offset - Duration(milliseconds: ((focalAfter - focalBefore) / _pxPerMs).round()));
    });
  }

  void _onPointerUp(PointerEvent event) => _pointers.remove(event.pointer);

  // One-finger gestures

  void _onTapUp(TapUpDetails details) {
    if (_pinched) return;
    final Duration time = _timeAt(details.localPosition.dx);
    if (details.localPosition.dy > _rulerHeight) widget.controls.select(_clipAt(time)?.id);
    widget.controls.seek(time);
  }

  void _onDragStart(DragStartDetails details) {
    if (_pinched) return;
    final Offset point = details.localPosition;
    final bool onPlayhead = (point.dx - _xOf(_editor.position)).abs() <= _playheadGrab;
    if (point.dy <= _rulerHeight || onPlayhead) return;
    final Duration time = _timeAt(point.dx);
    final TimelineClip? clip = _clipAt(time);
    if (clip == null) return;
    widget.controls.select(clip.id);
    setState(() {
      _dragClipId = clip.id;
      _dragStart = clip.timelineStart;
      _grabOffset = time - clip.timelineStart;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_pinched) return;
    final int? clipId = _dragClipId;
    if (clipId == null) {
      widget.controls.seek(_timeAt(details.localPosition.dx));
      return;
    }
    final TimelineClip clip = _editor.clips.firstWhere((c) => c.id == clipId);
    final Duration wanted = _timeAt(details.localPosition.dx) - _grabOffset;
    final Duration maxStart = _viewLength - clip.length;
    final Duration inside = wanted < Duration.zero ? Duration.zero : (wanted > maxStart ? maxStart : wanted);
    setState(() => _dragStart = _snap(clip, inside));
  }

  void _onDragEnd() {
    final int? clipId = _dragClipId;
    if (clipId == null) return;
    if (!_pinched) widget.controls.move(clipId, _dragStart);
    setState(() => _dragClipId = null);
  }

  /// Moves [start] onto a nearby edge, so clips can sit back to back without gaps.
  Duration _snap(TimelineClip clip, Duration start) {
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
      final double distance = gap.inMilliseconds.abs() * _pxPerMs;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(PhosphorIconsRegular.magnifyingGlassMinus),
              tooltip: 'Zoom out',
              onPressed: _canZoomOut ? () => _zoomButton(1 / _zoomStep) : null,
            ),
            IconButton(
              icon: const Icon(PhosphorIconsRegular.magnifyingGlassPlus),
              tooltip: 'Zoom in',
              onPressed: _canZoomIn ? () => _zoomButton(_zoomStep) : null,
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            _width = max(1, constraints.maxWidth);
            // The timeline may have become shorter since the last build
            _offset = _clampOffset(_offset);

            return Semantics(
              container: true,
              label: 'Timeline, playhead',
              value: _playheadValue(_editor.position),
              // Both or neither: with a value, Flutter requires the values after increase and decrease
              increasedValue: _playheadValue(_editor.position + _playheadStep),
              decreasedValue: _playheadValue(_editor.position - _playheadStep),
              onIncrease: () => widget.controls.seek(_editor.position + _playheadStep),
              onDecrease: () => widget.controls.seek(_editor.position - _playheadStep),
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerUp,
                child: GestureDetector(
                  // Screen readers use the explicit actions of the timeline and of each clip instead
                  excludeFromSemantics: true,
                  onTapUp: _onTapUp,
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: (_) => _onDragEnd(),
                  onHorizontalDragCancel: _onDragEnd,
                  child: CustomPaint(
                    size: Size(_width, _rulerHeight + _laneHeight),
                    painter: _TimelinePainter(
                      clips: _shownClips,
                      selectedClipId: _editor.selectedClipId,
                      waveform: _editor.waveform,
                      trackLength: _editor.trackLength,
                      pxPerMs: _pxPerMs,
                      offset: _offset,
                      position: _editor.position,
                      rulerHeight: _rulerHeight,
                      insertAt: _insertAt,
                      onSelect: widget.controls.select,
                      onNudge: (clip, step) => widget.controls.nudge(clip.id, step),
                      nudgeStep: _clipStep,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
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
    required this.offset,
    required this.position,
    required this.rulerHeight,
    required this.insertAt,
    required this.onSelect,
    required this.onNudge,
    required this.nudgeStep,
  });

  final List<TimelineClip> clips;
  final int? selectedClipId;

  /// Loudness of the whole track, from 0 to 1, with the loudest point at 1.
  final Float32List waveform;

  final Duration trackLength;
  final double pxPerMs;

  /// Time at the left edge.
  final Duration offset;

  final Duration position;
  final double rulerHeight;

  /// Insertion point of the clip being dragged, marked with a line.
  final Duration? insertAt;

  /// For screen readers, which select and move clips without dragging.
  final ValueChanged<int?> onSelect;
  final void Function(TimelineClip clip, Duration step) onNudge;
  final Duration nudgeStep;

  /// Clip value read by screen readers after moving it by [step].
  String _clipValue(TimelineClip clip, Duration step) {
    final Duration start = clip.timelineStart + step < Duration.zero ? Duration.zero : clip.timelineStart + step;
    return '${_formatTime(start)} to ${_formatTime(start + clip.length)}';
  }

  /// Horizontal distance between waveform bars.
  static const double _barStep = 3;

  static const Radius _radius = Radius.circular(AppSpacing.radiusMd);

  /// Possible distances between ruler ticks, in ms. Each label step is a multiple of the tick step it goes with.
  static const List<int> _rulerSteps = [100, 500, 1000, 5000, 10000, 30000, 60000, 300000];

  /// Smallest distance in px between two ticks, and between two labels.
  static const double _minTickGap = 8;
  static const double _minLabelGap = 64;

  double _x(Duration time) => (time - offset).inMilliseconds * pxPerMs;

  Rect _clipRect(TimelineClip clip, Size size) =>
      Rect.fromLTRB(_x(clip.timelineStart), rulerHeight, _x(clip.timelineEnd), size.height);

  /// Clips in drawing order, the selected one last so it is on top.
  Iterable<TimelineClip> get _ordered => [
    ...clips.where((clip) => clip.id != selectedClipId),
    ...clips.where((clip) => clip.id == selectedClipId),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (trackLength <= Duration.zero) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _paintRuler(canvas, size);
    for (final TimelineClip clip in _ordered) {
      final Rect rect = _clipRect(clip, size);
      if (rect.right >= 0 && rect.left <= size.width) _paintClip(canvas, size, clip, rect);
    }
    final Duration? insertAt = this.insertAt;
    if (insertAt != null) {
      final double x = _x(insertAt);
      canvas.drawLine(
        Offset(x, rulerHeight),
        Offset(x, size.height),
        Paint()
          ..color = AppColors.tertiary
          ..strokeWidth = 4,
      );
    }
    _paintPlayhead(canvas, size);
    canvas.restore();
  }

  void _paintRuler(Canvas canvas, Size size) {
    final int tickMs = _rulerSteps.firstWhere((step) => step * pxPerMs >= _minTickGap, orElse: () => _rulerSteps.last);
    final int labelMs = _rulerSteps.firstWhere(
      (step) => step * pxPerMs >= _minLabelGap && step % tickMs == 0,
      orElse: () => _rulerSteps.last,
    );
    final Paint tickPaint = Paint()
      ..color = AppColors.greyDark
      ..strokeWidth = 1;
    final int firstMs = (offset.inMilliseconds / tickMs).ceil() * tickMs;
    final int lastMs = offset.inMilliseconds + (size.width / pxPerMs).ceil();
    for (int ms = firstMs; ms <= lastMs; ms += tickMs) {
      final double x = _x(Duration(milliseconds: ms));
      final bool labelled = ms % labelMs == 0;
      canvas.drawLine(Offset(x, rulerHeight - (labelled ? 10 : 5)), Offset(x, rulerHeight), tickPaint);
      if (!labelled) continue;
      final String seconds = (ms ~/ 1000 % 60).toString().padLeft(2, '0');
      // Tenths only when labels are closer than a second
      final String tenths = labelMs < 1000 ? '.${ms % 1000 ~/ 100}' : '';
      final TextPainter label = TextPainter(
        text: TextSpan(
          text: '${ms ~/ 60000}:$seconds$tenths',
          style: AppTextStyles.pSm.copyWith(color: AppColors.greyLight),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (x + 2 + label.width <= size.width) label.paint(canvas, Offset(x + 2, 0));
    }
  }

  void _paintClip(Canvas canvas, Size size, TimelineClip clip, Rect rect) {
    final bool selected = clip.id == selectedClipId;
    final RRect shape = RRect.fromRectAndRadius(rect, _radius);
    canvas.drawRRect(shape, Paint()..color = selected ? AppColors.greyDark : AppColors.greyDarker);

    if (waveform.isNotEmpty) {
      final Paint barPaint = Paint()
        ..color = AppColors.secondary
        ..strokeWidth = 2;
      final double middle = rect.center.dy;
      final double pointsPerMs = waveform.length / trackLength.inMilliseconds;
      // Only the visible part of the clip
      final double from = max(rect.left, 0);
      final double to = min(rect.right, size.width);
      for (double x = from + _barStep / 2; x < to; x += _barStep) {
        // Part of the original track under this bar: its loudest point, so zooming out keeps the peaks
        final double sourceMs = clip.sourceStart.inMilliseconds + (x - rect.left) / pxPerMs;
        final int first = (sourceMs * pointsPerMs).floor().clamp(0, waveform.length - 1);
        final int last = ((sourceMs + _barStep / pxPerMs) * pointsPerMs).floor().clamp(first + 1, waveform.length);
        double loudness = 0;
        for (int i = first; i < last; i++) {
          if (waveform[i] > loudness) loudness = waveform[i];
        }
        final double halfBar = loudness * rect.height * 0.45;
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
    final double x = _x(position);
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
          // Only the visible part of each clip: clips outside the zoomed view are reached by zooming out
          if (_clipRect(clip, size).intersect(Offset.zero & size) case final Rect visible when visible.width > 0)
            CustomPainterSemantics(
              key: ValueKey<int>(clip.id),
              rect: visible,
              properties: SemanticsProperties(
                label: 'Clip ${i + 1}',
                value: '${_formatTime(clip.timelineStart)} to ${_formatTime(clip.timelineEnd)}',
                increasedValue: _clipValue(clip, nudgeStep),
                decreasedValue: _clipValue(clip, -nudgeStep),
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
      old.insertAt != insertAt ||
      old.waveform != waveform ||
      old.pxPerMs != pxPerMs ||
      old.offset != offset ||
      old.trackLength != trackLength;

  @override
  bool shouldRebuildSemantics(_TimelinePainter old) =>
      old.clips != clips || old.selectedClipId != selectedClipId || old.pxPerMs != pxPerMs || old.offset != offset;
}
