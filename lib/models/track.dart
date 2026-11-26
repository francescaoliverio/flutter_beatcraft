/// A Jamendo track, reduced to the fields the app uses.
class Track {
  const Track({
    required this.id,
    required this.name,
    required this.artistName,
    required this.image,
    required this.audio,
    required this.audiodownloadAllowed,
    required this.licenseCcurl,
    this.shareUrl,
    this.duration,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      name: json['name'] as String,
      artistName: json['artist_name'] as String,
      image: json['image'] as String,
      audio: json['audio'] as String,
      audiodownloadAllowed: json['audiodownload_allowed'] as bool,
      licenseCcurl: json['license_ccurl'] as String,
      shareUrl: json['shareurl'] as String?,
      duration: switch (json['duration']) {
        final int seconds => Duration(seconds: seconds),
        _ => null,
      },
    );
  }

  final String id;
  final String name;
  final String artistName;

  /// Cover URL.
  final String image;

  /// Stream URL.
  final String audio;

  final bool audiodownloadAllowed;

  /// Creative Commons license URL. Empty on some older tracks.
  final String licenseCcurl;

  /// Page of the track on Jamendo, where the Jamendo terms ask the app to link each track.
  /// Not described in the API documentation, but returned by /tracks (checked with a real call).
  final String? shareUrl;

  /// Null if Jamendo doesn't give it.
  final Duration? duration;

  /// Local cover used if [image] fails to load: one of the 18 remix covers, always the same for the same track.
  String get fallbackCoverAsset {
    final int number = (int.tryParse(id) ?? id.hashCode).abs() % 18 + 1;
    return 'assets/images/remixes/remix_${number.toString().padLeft(2, '0')}.webp';
  }

  /// Remix rule from the README: downloads allowed, license present and not NoDerivatives.
  bool get canRemix => audiodownloadAllowed && licenseCcurl.isNotEmpty && !licenseCcurl.contains('-nd');
}
