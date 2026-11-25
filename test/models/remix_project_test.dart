import 'package:flutter_beatcraft/models/remix_project.dart';
import 'package:flutter_beatcraft/models/timeline_clip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a project survives a round trip through JSON', () {
    final RemixProject project = RemixProject(
      id: '1732500000000000',
      name: 'Night remix',
      trackId: '2353774',
      clips: const [
        TimelineClip(
          id: 3,
          sourceStart: Duration(milliseconds: 1500),
          sourceEnd: Duration(seconds: 9),
          timelineStart: Duration(seconds: 20),
        ),
      ],
      updatedAt: DateTime.utc(2026, 11, 25, 2),
    );

    final RemixProject read = RemixProject.fromJson(project.toJson());

    expect(
      (read.id, read.name, read.trackId, read.updatedAt),
      (project.id, project.name, project.trackId, project.updatedAt),
    );
    final TimelineClip clip = read.clips.single;
    expect(
      (clip.id, clip.sourceStart, clip.sourceEnd, clip.timelineStart),
      (3, const Duration(milliseconds: 1500), const Duration(seconds: 9), const Duration(seconds: 20)),
    );
    expect(read.length, const Duration(milliseconds: 27500));
  });
}
