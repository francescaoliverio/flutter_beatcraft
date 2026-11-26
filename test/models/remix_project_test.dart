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
      cover: 5,
      updatedAt: DateTime.utc(2026, 11, 25, 2),
    );

    final RemixProject read = RemixProject.fromJson(project.toJson());

    expect(
      (read.id, read.name, read.trackId, read.cover, read.updatedAt),
      (project.id, project.name, project.trackId, 5, project.updatedAt),
    );
    final TimelineClip clip = read.clips.single;
    expect(
      (clip.id, clip.sourceStart, clip.sourceEnd, clip.timelineStart),
      (3, const Duration(milliseconds: 1500), const Duration(seconds: 9), const Duration(seconds: 20)),
    );
    expect(read.length, const Duration(milliseconds: 27500));
  });

  test('a project saved before covers could be chosen keeps the cover derived from its id', () {
    final Map<String, dynamic> json = {
      'id': '1732500000000000',
      'name': 'Old remix',
      'track_id': '2353774',
      'clips': <dynamic>[],
      'updated_at': '2026-11-25T02:00:00.000Z',
    };

    final RemixProject read = RemixProject.fromJson(json);

    expect(read.cover, 1732500000000000 % RemixProject.coverCount + 1);
    expect(read.coverAsset, 'assets/images/remixes/remix_${read.cover.toString().padLeft(2, '0')}.webp');
  });
}
