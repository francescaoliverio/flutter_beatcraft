/// A Jamendo artist, reduced to the fields the app shows.
class Artist {
  const Artist({required this.id, required this.name, required this.image, this.joinDate, this.website, this.shareUrl});

  factory Artist.fromJson(Map<String, dynamic> json) {
    final String website = json['website'] as String? ?? '';
    return Artist(
      id: json['id'] as String,
      name: json['name'] as String,
      image: json['image'] as String,
      joinDate: DateTime.tryParse(json['joindate'] as String? ?? ''),
      // Often empty
      website: website.isEmpty ? null : website,
      shareUrl: json['shareurl'] as String?,
    );
  }

  final String id;
  final String name;

  /// Picture URL.
  final String image;

  /// When the artist joined Jamendo.
  final DateTime? joinDate;

  /// The artist's own site.
  final String? website;

  /// Page of the artist on Jamendo.
  final String? shareUrl;
}
