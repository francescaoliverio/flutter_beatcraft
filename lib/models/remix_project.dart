import 'timeline_clip.dart';

/// A saved remix: the Jamendo track id and the clips, never the audio.
/// When it is opened, the track is loaded again from Jamendo.
class RemixProject {
  const RemixProject({
    required this.id,
    required this.name,
    required this.trackId,
    required this.clips,
    required this.cover,
    required this.updatedAt,
  });

  factory RemixProject.fromJson(Map<String, dynamic> json) {
    final String id = json['id'] as String;
    return RemixProject(
      id: id,
      name: json['name'] as String,
      trackId: json['track_id'] as String,
      clips: (json['clips'] as List<dynamic>)
          .map((clip) => TimelineClip.fromJson(clip as Map<String, dynamic>))
          .toList(),
      // Remixes saved before covers could be chosen keep the one they always showed
      cover: json['cover'] as int? ?? (int.tryParse(id) ?? id.hashCode).abs() % coverCount + 1,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Number of remix covers in assets/images/remixes.
  static const int coverCount = 18;

  /// Asset of cover [number], from 1 to [coverCount].
  static String coverAssetOf(int number) => 'assets/images/remixes/remix_${number.toString().padLeft(2, '0')}.webp';

  /// Creation time in microseconds, as text.
  final String id;

  final String name;
  final String trackId;
  final List<TimelineClip> clips;

  /// Cover number, from 1 to [coverCount].
  final int cover;

  final DateTime updatedAt;

  /// End of the last clip.
  Duration get length =>
      clips.fold(Duration.zero, (Duration end, TimelineClip clip) => clip.timelineEnd > end ? clip.timelineEnd : end);

  String get coverAsset => coverAssetOf(cover);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'track_id': trackId,
    'clips': clips.map((clip) => clip.toJson()).toList(),
    'cover': cover,
    'updated_at': updatedAt.toIso8601String(),
  };
}
