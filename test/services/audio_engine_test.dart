import 'package:flutter_beatcraft/models/timeline_clip.dart';
import 'package:flutter_beatcraft/services/audio_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Duration s(int seconds) => Duration(seconds: seconds);

void main() {
  // Two clips with a 2 second gap: track 10-14 at 0-4, track 30-33 at 6-9
  final List<TimelineClip> clips = [
    TimelineClip(id: 0, sourceStart: s(10), sourceEnd: s(14), timelineStart: s(0)),
    TimelineClip(id: 1, sourceStart: s(30), sourceEnd: s(33), timelineStart: s(6)),
  ];

  test('from the start every clip plays whole, at its timeline position', () {
    final List<TimelinePart> parts = planTimeline(clips, Duration.zero);

    expect(parts.map((p) => p.delay), [s(0), s(6)]);
    expect(parts.map((p) => p.sourceStart), [s(10), s(30)]);
    expect(parts.map((p) => p.length), [s(4), s(3)]);
  });

  test('from inside a clip only its remaining part plays', () {
    final List<TimelinePart> parts = planTimeline(clips, s(1));

    expect(parts.map((p) => p.delay), [s(0), s(5)]);
    expect(parts.map((p) => p.sourceStart), [s(11), s(30)]);
    expect(parts.map((p) => p.length), [s(3), s(3)]);
  });

  test('clips that end before the start are skipped', () {
    final List<TimelinePart> parts = planTimeline(clips, s(4));

    expect(parts, hasLength(1));
    expect(parts.single.delay, s(2));
    expect(parts.single.sourceStart, s(30));
  });

  test('nothing plays after the last clip', () {
    expect(planTimeline(clips, s(9)), isEmpty);
  });
}
