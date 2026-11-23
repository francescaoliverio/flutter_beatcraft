/// A Jamendo artist, reduced to the fields the app shows.
class Artist {
  const Artist({required this.id, required this.name, required this.image});

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(id: json['id'] as String, name: json['name'] as String, image: json['image'] as String);
  }

  final String id;
  final String name;

  /// Picture URL.
  final String image;
}
