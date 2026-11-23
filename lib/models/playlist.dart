/// Mood of a playlist cover, as in the asset names.
enum CoverMood { bright, calm, dark, punchy }

/// A Jamendo playlist. Jamendo gives no image, so the cover is a local asset picked by [mood] and [id].
class Playlist {
  const Playlist({required this.id, required this.name, required this.mood});

  /// `user_name` is never read: it can contain an email address.
  factory Playlist.fromJson(Map<String, dynamic> json, CoverMood mood) {
    return Playlist(id: json['id'] as String, name: json['name'] as String, mood: mood);
  }

  final String id;
  final String name;
  final CoverMood mood;

  static const List<String> _coverColors = ['primary', 'secondary', 'tertiary'];

  /// One of the 6 covers of the mood (3 colors x 2), always the same for the same playlist.
  String get coverAsset {
    final int index = (int.tryParse(id) ?? id.hashCode).abs() % 6;
    final String color = _coverColors[index ~/ 2];
    final int number = index % 2 + 1;
    return 'assets/images/playlists/${color}_${mood.name}_0$number.webp';
  }
}
