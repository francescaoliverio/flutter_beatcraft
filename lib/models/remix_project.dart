import 'timeline_clip.dart';

/// A saved remix: the Jamendo track id and the clips, never the audio.
/// When it is opened, the track is loaded again from Jamendo.
class RemixProject {
  const RemixProject({
    required this.id,
    required this.name,
    required this.trackId,
    required this.clips,
    required this.updatedAt,
  });

  factory RemixProject.fromJson(Map<String, dynamic> json) {
    return RemixProject(
      id: json['id'] as String,
      name: json['name'] as String,
      trackId: json['track_id'] as String,
      clips: (json['clips'] as List<dynamic>)
          .map((clip) => TimelineClip.fromJson(clip as Map<String, dynamic>))
          .toList(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Creation time in microseconds, as text.
  final String id;

  final String name;
  final String trackId;
  final List<TimelineClip> clips;
  final DateTime updatedAt;

  /// End of the last clip.
  Duration get length =>
      clips.fold(Duration.zero, (Duration end, TimelineClip clip) => clip.timelineEnd > end ? clip.timelineEnd : end);

  /// One of the 18 remix covers, always the same for the same project.
  String get coverAsset {
    final int number = (int.tryParse(id) ?? id.hashCode).abs() % 18 + 1;
    return 'assets/images/remixes/remix_${number.toString().padLeft(2, '0')}.webp';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'track_id': trackId,
    'clips': clips.map((clip) => clip.toJson()).toList(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
