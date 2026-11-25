/// A part of the original track placed on the remix timeline.
/// Not named Clip: Flutter already uses that name for clipBehavior.
class TimelineClip {
  const TimelineClip({
    required this.id,
    required this.sourceStart,
    required this.sourceEnd,
    required this.timelineStart,
  });

  factory TimelineClip.fromJson(Map<String, dynamic> json) {
    return TimelineClip(
      id: json['id'] as int,
      sourceStart: Duration(milliseconds: json['source_start_ms'] as int),
      sourceEnd: Duration(milliseconds: json['source_end_ms'] as int),
      timelineStart: Duration(milliseconds: json['timeline_start_ms'] as int),
    );
  }

  /// Unique within a remix, to select a clip and follow it through edits.
  final int id;

  /// Start in the original track.
  final Duration sourceStart;

  /// End in the original track, excluded.
  final Duration sourceEnd;

  /// Where the clip starts on the timeline.
  final Duration timelineStart;

  Duration get length => sourceEnd - sourceStart;

  Duration get timelineEnd => timelineStart + length;

  /// True if [time] is on the clip, edges included.
  bool covers(Duration time) => time >= timelineStart && time <= timelineEnd;

  TimelineClip copyWith({int? id, Duration? sourceStart, Duration? sourceEnd, Duration? timelineStart}) {
    return TimelineClip(
      id: id ?? this.id,
      sourceStart: sourceStart ?? this.sourceStart,
      sourceEnd: sourceEnd ?? this.sourceEnd,
      timelineStart: timelineStart ?? this.timelineStart,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'source_start_ms': sourceStart.inMilliseconds,
    'source_end_ms': sourceEnd.inMilliseconds,
    'timeline_start_ms': timelineStart.inMilliseconds,
  };
}
