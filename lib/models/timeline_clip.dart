/// A part of the original track placed on the remix timeline.
/// Not named Clip: Flutter already uses that name for clipBehavior.
class TimelineClip {
  const TimelineClip({required this.sourceStart, required this.sourceEnd, required this.timelineStart});

  /// Start in the original track.
  final Duration sourceStart;

  /// End in the original track, excluded.
  final Duration sourceEnd;

  /// Where the clip starts on the timeline.
  final Duration timelineStart;

  Duration get length => sourceEnd - sourceStart;

  Duration get timelineEnd => timelineStart + length;
}
