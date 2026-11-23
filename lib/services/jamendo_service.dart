import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/track.dart';

enum JamendoFailure {
  /// The app was started without `--dart-define=JAMENDO_CLIENT_ID=...`.
  missingClientId,

  /// Still no results after all attempts.
  empty,

  /// Network error, HTTP error, error code from Jamendo or unexpected body.
  other,
}

/// Thrown by [JamendoService] when a request fails.
class JamendoException implements Exception {
  const JamendoException(this.failure);

  final JamendoFailure failure;

  @override
  String toString() => 'JamendoException($failure)';
}

/// Read-only calls to the Jamendo API v3.0.
class JamendoService {
  JamendoService(this._client, this._clientId);

  final http.Client _client;
  final String _clientId;

  /// Jamendo sometimes answers with empty results and no error: each request is tried up to this many times.
  static const int maxAttempts = 3;

  /// Track cover size in px, one of the values allowed by `imagesize`.
  static const String _imageSize = '300';

  /// Newest tracks first.
  Future<List<Track>> newReleases({required int limit}) async {
    final results = await _get('tracks', {'order': 'releasedate_desc', 'limit': '$limit', 'imagesize': _imageSize});
    return _parse(results, Track.fromJson);
  }

  /// Most popular artists of the week, only those with a picture.
  Future<List<Artist>> trendingArtists({required int limit}) async {
    final results = await _get('artists', {'order': 'popularity_week', 'hasimage': 'true', 'limit': '$limit'});
    return _parse(results, Artist.fromJson);
  }

  /// Playlists whose name contains [query]. The cover uses [mood].
  Future<List<Playlist>> searchPlaylists(String query, CoverMood mood, {required int limit}) async {
    final results = await _get('playlists', {'namesearch': query, 'limit': '$limit'});
    return _parse(results, (json) => Playlist.fromJson(json, mood));
  }

  /// One track by id, or null if Jamendo doesn't return it.
  Future<Track?> trackById(String id) async {
    try {
      final results = await _get('tracks', {'id': id, 'imagesize': _imageSize});
      return _parse(results, Track.fromJson).first;
    } on JamendoException catch (e) {
      if (e.failure == JamendoFailure.empty) return null;
      rethrow;
    }
  }

  /// Returns the `results` list. Throws [JamendoException].
  Future<List<dynamic>> _get(String path, Map<String, String> params) async {
    if (_clientId.isEmpty) throw const JamendoException(JamendoFailure.missingClientId);

    final Uri uri = Uri.https('api.jamendo.com', '/v3.0/$path/', {'client_id': _clientId, 'format': 'json', ...params});

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final List<dynamic> results = await _request(uri);
      if (results.isNotEmpty) return results;
    }
    throw const JamendoException(JamendoFailure.empty);
  }

  Future<List<dynamic>> _request(Uri uri) async {
    final http.Response response;
    try {
      response = await _client.get(uri);
    } on Exception {
      throw const JamendoException(JamendoFailure.other);
    }
    if (response.statusCode != 200) throw const JamendoException(JamendoFailure.other);

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      // Errors come with HTTP 200: the outcome is in headers.code (0 = success)
      final headers = json['headers'] as Map<String, dynamic>;
      if (headers['code'] != 0) throw const JamendoException(JamendoFailure.other);
      return json['results'] as List<dynamic>;
    } on FormatException {
      throw const JamendoException(JamendoFailure.other);
    } on TypeError {
      throw const JamendoException(JamendoFailure.other);
    }
  }

  List<T> _parse<T>(List<dynamic> results, T Function(Map<String, dynamic>) fromJson) {
    try {
      return results.map((item) => fromJson(item as Map<String, dynamic>)).toList();
    } on TypeError {
      // A field is missing or has an unexpected type
      throw const JamendoException(JamendoFailure.other);
    }
  }
}
