import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

// SemanticsProperties for the clips drawn on the timeline: material_ui doesn't export it
import 'package:flutter/semantics.dart' show SemanticsProperties;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../models/remix_project.dart';
import '../models/timeline_clip.dart';
import '../providers/editor_provider.dart';
import '../providers/remix_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/button.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_box.dart';
import '../widgets/heading.dart';
import '../widgets/jamendo_link.dart';
import '../widgets/undo_snack_bar.dart';

/// Minutes, seconds and tenths, e.g. 1:08.4.
String _formatTime(Duration time) {
  final String seconds = (time.inSeconds % 60).toString().padLeft(2, '0');
  return '${time.inMinutes}:$seconds.${time.inMilliseconds % 1000 ~/ 100}';
}

/// Border of the dialogs, the same as the snackbars and empty states.
const ShapeBorder _dialogShape = RoundedRectangleBorder(
  side: BorderSide(color: AppColors.greyDark),
  borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusMd)),
);

/// Size of the cover next to the remix name.
const double _coverSize = 48;

/// The remix cover: one of the covers in the assets, decoded at the displayed [size] (the files are 1024 px).
class _Cover extends StatelessWidget {
  const _Cover({required this.number, required this.size});

  final int number;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Image.asset(
        RemixProject.coverAssetOf(number),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      ),
    );
  }
}

/// Name and cover chosen in [_EditDialog].
typedef _RemixDetails = ({String name, int cover});

/// Edits the remix name and cover together. Pops the new details with Apply, or null if closed.
/// An empty name, or one already used by another remix of the user ([isTaken]), shows an error instead.
/// Closed with changes (X, a tap outside, back), it asks whether to apply or discard them.
class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.name, required this.cover, required this.isTaken});

  final String name;
  final int cover;
  final bool Function(String name) isTaken;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  static const int _columns = 3;

  late final TextEditingController _controller = TextEditingController(text: widget.name);
  late int _cover = widget.cover;
  String? _error;

  bool get _hasChanges => _controller.text.trim() != widget.name.trim() || _cover != widget.cover;

  /// Asked when closing with changes: Apply applies them (or shows the name error), Discard closes without them.
  Future<void> _confirmClose() async {
    final bool? apply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgDark,
        shape: _dialogShape,
        title: const Heading('Unsaved changes', style: HeadingStyle.h4, uppercase: false),
        content: Text('Apply the new name and cover, or discard them?', style: AppTextStyles.p),
        actions: [
          Button(
            label: 'Discard',
            color: ButtonColor.tertiary,
            variant: ButtonVariant.outline,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          Button(label: 'Apply', onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    if (!mounted || apply == null) return;
    if (apply) {
      _submit();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _submit() {
    final String name = _controller.text.trim();
    final String? error = name.isEmpty
        ? 'Enter a name.'
        : (widget.isTaken(name) ? 'You already have a remix with this name.' : null);
    if (error == null) {
      Navigator.of(context).pop((name: name, cover: _cover));
    } else {
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _coverOption(int number, double size) {
    final bool selected = number == _cover;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Cover $number',
      excludeSemantics: true,
      onTap: () => setState(() => _cover = number),
      child: GestureDetector(
        onTap: () => setState(() => _cover = number),
        child: Container(
          // The chosen cover has a tertiary border, the others a transparent one of the same width
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? AppColors.tertiary : Colors.transparent, width: 3),
            borderRadius: const BorderRadius.all(Radius.circular(AppSpacing.radiusMd)),
          ),
          child: _Cover(number: number, size: size - 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // X, a tap outside and back all try to pop: with changes, ask first
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) _confirmClose();
      },
      child: AlertDialog(
        backgroundColor: AppColors.bgDark,
        shape: _dialogShape,
        title: Row(
          children: [
            const Expanded(child: Heading('Edit remix', style: HeadingStyle.h3, uppercase: false)),
            IconButton(
              icon: const Icon(PhosphorIconsRegular.x),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Heading('Change name', style: HeadingStyle.h5, uppercase: false),
                const SizedBox(height: AppSpacing.paddingSm),
                TextField(
                  controller: _controller,
                  // No autofocus: the keyboard would hide the covers
                  maxLength: 40,
                  textInputAction: TextInputAction.done,
                  // The label doesn't float above the field: the section title is there.
                  // It is still read by screen readers, and errorText too
                  decoration: InputDecoration(
                    labelText: 'Name',
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    errorText: _error,
                  ),
                  // Rebuilt at every change, so closing knows whether there are changes
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.paddingMd),
                const Heading('Choose cover', style: HeadingStyle.h5, uppercase: false),
                const SizedBox(height: AppSpacing.paddingSm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Rounded down, so rounding never pushes the third cover to a new row
                    final double size = ((constraints.maxWidth - AppSpacing.paddingSm * (_columns - 1)) / _columns)
                        .floorToDouble();
                    return Wrap(
                      spacing: AppSpacing.paddingSm,
                      runSpacing: AppSpacing.paddingSm,
                      children: [
                        for (int number = 1; number <= RemixProject.coverCount; number++) _coverOption(number, size),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // Apply, not Save: the remix itself is saved with the Save button of the screen
        actions: [Button(label: 'Apply', onPressed: _submit)],
      ),
    );
  }
}

/// Remix editor: timeline with clips, playback and editing tools.
class CreateScreen extends ConsumerWidget {
  const CreateScreen({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final SavedRemix? saved = await ref.read(editorProvider.notifier).save();
    if (saved == null || !context.mounted) return;
    showUndoSnackBar(
      context,
      message: 'Remix saved',
      onUndo: () => ref.read(remixProjectsProvider.notifier).revert(saved.projectId, saved.previous),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, EditorState editor) async {
    final _RemixDetails? details = await showDialog<_RemixDetails>(
      context: context,
      builder: (_) => _EditDialog(
        name: editor.name,
        cover: editor.cover,
        isTaken: (name) =>
            isRemixNameTaken(ref.read(remixProjectsProvider).value ?? [], name, exceptId: editor.projectId),
      ),
    );
    if (details == null) return;
    ref.read(editorProvider.notifier)
      ..rename(details.name)
      ..setCover(details.cover);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EditorState?> editor = ref.watch(editorProvider);
    // While another remix loads, the previous one is not shown
    final EditorState? loaded = editor.isLoading || editor.hasError ? null : editor.value;
    // Another remix may have taken the name meanwhile, e.g. brought back by an Undo
    final bool nameTaken =
        loaded != null &&
        isRemixNameTaken(ref.watch(remixProjectsProvider).value ?? [], loaded.name, exceptId: loaded.projectId);
    final bool canSave = loaded != null && loaded.hasUnsavedChanges && !nameTaken;

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
                  spacing: AppSpacing.paddingMd,
                  children: [
                    // Only shown: name and cover are changed together with the pencil
                    Semantics(
                      image: true,
                      label: 'Remix cover ${loaded.cover}',
                      excludeSemantics: true,
                      child: _Cover(number: loaded.cover, size: _coverSize),
                    ),
                    // Expanded: the pencil sits at the right edge, like the trash and logout buttons
                    Expanded(child: Heading(loaded.name, style: HeadingStyle.h4, uppercase: false)),
                    IconButton(
                      icon: const Icon(PhosphorIconsRegular.pencilSimple),
                      tooltip: 'Edit name and cover',
                      onPressed: () => _edit(context, ref, loaded),
                    ),
                  ],
                ),
                if (nameTaken)
                  Text(
                    'You already have a remix with this name. Change it with the pencil to save.',
                    style: AppTextStyles.p.copyWith(color: AppColors.error),
                  ),
                TrackCredit(track: loaded.track),
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
            // Side by side without the row spacing, like the zoom buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                label: 'Copy',
                semanticLabel: 'Copy clip',
                icon: PhosphorIconsRegular.copy,
                onPressed: hasSelection ? controls.copySelected : null,
              ),
              _Tool(
                label: 'Paste',
                semanticLabel: 'Paste at playhead',
                icon: PhosphorIconsRegular.clipboard,
                onPressed: editor.canPaste ? controls.paste : null,
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
              : 'Tap a clip to select it, drag it to move it. Dropped or pasted on another clip, '
                    'it goes before or after it. Paste puts the copied clip at the playhead. '
                    'Drag on the ruler to move the playhead. Pinch to zoom, then scroll with the bar or two fingers.',
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
/// Drag a clip: moves it. Drag on the ruler or where there is no clip: moves the playhead.
/// Two fingers: pinch to zoom, move together to scroll. When zoomed, the bar below also scrolls.
class _Timeline extends StatefulWidget {
  const _Timeline({required this.editor, required this.controls});

  final EditorState editor;
  final EditorNotifier controls;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  /// Room above the ruler for the playhead head: with the ruler, a touch area of 44 px to move the playhead.
  static const double _headHeight = 20;
  static const double _rulerHeight = 24;
  static const double _topHeight = _headHeight + _rulerHeight;
  static const double _laneHeight = 120;

  /// Distance in px within which a dragged clip snaps to 0, the playhead or the edges of other clips.
  static const double _snapDistance = 12;

  /// Height of the scroll bar: its touch area, and the visible bar in the middle.
  static const double _scrollBarHeight = 44;
  static const double _scrollBarThickness = 8;

  /// Shortest scroll thumb, so it stays easy to grab when zoomed in a lot.
  static const double _minThumbWidth = 44;

  /// Distance in px from the left or right edge where a dragged playhead scrolls the view.
  static const double _edgeZone = 32;

  /// How often, and by which part of the visible time, the view scrolls while the playhead is held at an edge.
  static const Duration _edgeTick = Duration(milliseconds: 16);
  static const double _edgeStep = 0.02;

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

  /// True while the scroll thumb is dragged, for its pressed color.
  bool _scrolling = false;

  /// Scrolls the view while the dragged playhead or clip is held at an edge; [_dragX] is where the finger is.
  Timer? _edgeTimer;
  double _dragX = 0;

  EditorState get _editor => widget.editor;

  /// The whole timeline, shown when not zoomed.
  Duration get _viewLength => _editor.timelineLength;

  /// Where scrolling stops: the end of the content, or a bit after the playhead or the dragged clip when they are
  /// in the free space, so the view can follow them there (also while dragged against the right edge).
  Duration get _scrollEnd {
    Duration reach = _editor.position;
    final int? clipId = _dragClipId;
    if (clipId != null) {
      final Duration clipEnd = _dragStart + _editor.clips.firstWhere((c) => c.id == clipId).length;
      if (clipEnd > reach) reach = clipEnd;
    }
    final Duration margin = Duration(milliseconds: (_edgeZone * 2 / _pxPerMs).round());
    final Duration end = reach + margin > _editor.contentLength ? reach + margin : _editor.contentLength;
    return end > _viewLength ? _viewLength : end;
  }

  Duration get _visible {
    final Duration? span = _span;
    return span == null || span > _viewLength ? _viewLength : span;
  }

  double get _pxPerMs => _width / max(1, _visible.inMilliseconds);

  Duration _timeAt(double x) => Duration(milliseconds: max(0, _offset.inMilliseconds + x / _pxPerMs).round());

  double _xOf(Duration time) => (time - _offset).inMilliseconds * _pxPerMs;

  /// Latest left edge: [_scrollEnd] on the right edge.
  Duration get _maxOffset => _scrollEnd - _visible;

  Duration _clampOffset(Duration offset) {
    final Duration maxOffset = _maxOffset;
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
    final Placement placed = placeClip(_editor.clips.where((c) => c.id != clipId).toList(), _dragStart, clip.length);
    return placed.moved ? placed.start : null;
  }

  /// Playhead value read by screen readers, kept between 0 and the end like a seek does.
  String _playheadValue(Duration position) {
    final Duration clamped = position < Duration.zero
        ? Duration.zero
        : (position > _editor.timelineLength ? _editor.timelineLength : position);
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
    if (details.localPosition.dy > _topHeight) widget.controls.select(_clipAt(time)?.id);
    widget.controls.seek(time);
  }

  void _onDragStart(DragStartDetails details) {
    if (_pinched) return;
    final Offset point = details.localPosition;
    // On the ruler and above it the drag moves the playhead (see _onDragUpdate)
    if (point.dy <= _topHeight) return;
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
      _dragX = details.localPosition.dx;
      widget.controls.seek(_timeAt(_dragX));
      _updateEdgeScroll();
      return;
    }
    _dragX = details.localPosition.dx;
    _dragClipTo(clipId);
    _updateEdgeScroll();
  }

  /// Moves the preview of the dragged clip under the finger, inside the timeline and snapped to nearby edges.
  void _dragClipTo(int clipId) {
    final TimelineClip clip = _editor.clips.firstWhere((c) => c.id == clipId);
    final Duration wanted = _timeAt(_dragX) - _grabOffset;
    final Duration maxStart = _viewLength - clip.length;
    final Duration inside = wanted < Duration.zero ? Duration.zero : (wanted > maxStart ? maxStart : wanted);
    setState(() => _dragStart = _snap(clip, inside));
  }

  /// Starts scrolling while the dragged playhead or clip is at an edge, stops when it leaves it.
  void _updateEdgeScroll() {
    final int direction = _dragX >= _width - _edgeZone ? 1 : (_dragX <= _edgeZone ? -1 : 0);
    if (direction == 0 || _span == null) {
      _stopEdgeScroll();
      return;
    }
    _edgeTimer ??= Timer.periodic(_edgeTick, (_) {
      // The edge may have changed meanwhile: read it again at every tick
      final int now = _dragX >= _width - _edgeZone ? 1 : (_dragX <= _edgeZone ? -1 : 0);
      if (now == 0 || _pinched) {
        _stopEdgeScroll();
        return;
      }
      setState(() => _offset = _clampOffset(_offset + _visible * (_edgeStep * now)));
      final int? clipId = _dragClipId;
      if (clipId != null) {
        _dragClipTo(clipId);
      } else {
        widget.controls.seek(_timeAt(_dragX));
      }
    });
  }

  void _stopEdgeScroll() {
    _edgeTimer?.cancel();
    _edgeTimer = null;
  }

  @override
  void dispose() {
    _stopEdgeScroll();
    super.dispose();
  }

  void _onDragEnd() {
    _stopEdgeScroll();
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

  // Scroll bar

  /// Thumb as wide as the visible part of the content, at least [_minThumbWidth].
  double _thumbWidth(double barWidth) =>
      min(barWidth, max(_minThumbWidth, barWidth * _visible.inMilliseconds / max(1, _scrollEnd.inMilliseconds)));

  /// Room the thumb can move in.
  double _thumbTravel(double barWidth) => max(1, barWidth - _thumbWidth(barWidth));

  double _thumbLeft(double barWidth) =>
      _maxOffset <= Duration.zero ? 0 : _thumbTravel(barWidth) * _offset.inMilliseconds / _maxOffset.inMilliseconds;

  /// Scrolls so the thumb starts at [left].
  void _scrollThumbTo(double left, double barWidth) {
    if (_maxOffset <= Duration.zero) return;
    final double fraction = (left / _thumbTravel(barWidth)).clamp(0, 1);
    setState(() => _offset = _clampOffset(Duration(milliseconds: (_maxOffset.inMilliseconds * fraction).round())));
  }

  /// Scrolls by half a screen, for screen readers.
  void _scrollBy(int direction) => setState(() => _offset = _clampOffset(_offset + _visible * (0.5 * direction)));

  String _shownRange(Duration offset) {
    final Duration from = _clampOffset(offset);
    final Duration to = from + _visible > _scrollEnd ? _scrollEnd : from + _visible;
    return 'Showing ${_formatTime(from)} to ${_formatTime(to)}';
  }

  Widget _scrollBar(double barWidth) {
    final double thumbWidth = _thumbWidth(barWidth);
    final double thumbLeft = _thumbLeft(barWidth);
    return Semantics(
      label: 'Timeline scroll',
      value: _shownRange(_offset),
      increasedValue: _shownRange(_offset + _visible * 0.5),
      decreasedValue: _shownRange(_offset - _visible * 0.5),
      onIncrease: () => _scrollBy(1),
      onDecrease: () => _scrollBy(-1),
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        // A tap on the bar centres the thumb there
        onTapUp: (details) => _scrollThumbTo(details.localPosition.dx - thumbWidth / 2, barWidth),
        onHorizontalDragStart: (_) => setState(() => _scrolling = true),
        onHorizontalDragUpdate: (details) => _scrollThumbTo(_thumbLeft(barWidth) + details.delta.dx, barWidth),
        onHorizontalDragEnd: (_) => setState(() => _scrolling = false),
        onHorizontalDragCancel: () => setState(() => _scrolling = false),
        child: SizedBox(
          height: _scrollBarHeight,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: _scrollBarThickness,
                decoration: const BoxDecoration(
                  color: AppColors.greyDarker,
                  borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusPill)),
                ),
              ),
              Positioned(
                left: thumbLeft,
                width: thumbWidth,
                child: Container(
                  height: _scrollBarThickness,
                  decoration: BoxDecoration(
                    color: _scrolling ? AppColors.greyLighter : AppColors.greyLight,
                    borderRadius: const BorderRadius.all(Radius.circular(AppSpacing.radiusPill)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Scroll bar (only when zoomed) and zoom buttons on one row, under the timeline.
  Widget _scrollAndZoom() {
    return Row(
      children: [
        Expanded(
          child: _span == null
              ? const SizedBox(height: _scrollBarHeight)
              : LayoutBuilder(builder: (context, constraints) => _scrollBar(constraints.maxWidth)),
        ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            _width = max(1, constraints.maxWidth);
            // The timeline may have become shorter since the last build
            _offset = _clampOffset(_offset);

            final Widget timeline = Semantics(
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
                    size: Size(_width, _topHeight + _laneHeight),
                    painter: _TimelinePainter(
                      clips: _shownClips,
                      selectedClipId: _editor.selectedClipId,
                      waveform: _editor.waveform,
                      trackLength: _editor.trackLength,
                      pxPerMs: _pxPerMs,
                      offset: _offset,
                      position: _editor.position,
                      headHeight: _headHeight,
                      rulerHeight: _topHeight,
                      insertAt: _insertAt,
                      onSelect: widget.controls.select,
                      onNudge: (clip, step) => widget.controls.nudge(clip.id, step),
                      nudgeStep: _clipStep,
                    ),
                  ),
                ),
              ),
            );
            return timeline;
          },
        ),
        _scrollAndZoom(),
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
    required this.headHeight,
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

  /// Room at the top for the playhead head, above the ruler labels.
  final double headHeight;

  /// Bottom of the ruler, where the clips start.
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
      if (x + 2 + label.width <= size.width) label.paint(canvas, Offset(x + 2, headHeight));
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
    canvas.drawLine(Offset(x, headHeight), Offset(x, size.height), paint);
    // Head in the room above the ruler, so it doesn't cover the labels
    canvas.drawPath(
      Path()
        ..moveTo(x - 8, headHeight - 14)
        ..lineTo(x + 8, headHeight - 14)
        ..lineTo(x, headHeight)
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
