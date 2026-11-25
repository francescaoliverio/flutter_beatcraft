import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/remix_project.dart';

/// Small values kept on the device between launches: ids and remix projects (track id and clip times).
/// Never tokens, audio or track data.
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferencesAsync _prefs;

  static const String _lastTrackIdKey = 'last_track_id';
  static const String _userIdKey = 'logged_user_id';
  static const String _favoriteTrackIdsKey = 'favorite_track_ids';
  static const String _remixProjectsKey = 'remix_projects';

  Future<String?> readLastTrackId() => _prefs.getString(_lastTrackIdKey);

  Future<void> saveLastTrackId(String id) => _prefs.setString(_lastTrackIdKey, id);

  Future<void> clearLastTrackId() => _prefs.remove(_lastTrackIdKey);

  Future<int?> readUserId() => _prefs.getInt(_userIdKey);

  Future<void> saveUserId(int id) => _prefs.setInt(_userIdKey, id);

  Future<void> clearUserId() => _prefs.remove(_userIdKey);

  /// Liked tracks, newest first.
  Future<List<String>> readFavoriteTrackIds() async => await _prefs.getStringList(_favoriteTrackIdsKey) ?? [];

  Future<void> saveFavoriteTrackIds(List<String> ids) => _prefs.setStringList(_favoriteTrackIdsKey, ids);

  /// Saved remixes, one JSON string each. A project that can't be read is skipped.
  Future<List<RemixProject>> readRemixProjects() async {
    final List<String> saved = await _prefs.getStringList(_remixProjectsKey) ?? [];
    final List<RemixProject> projects = [];
    for (final String json in saved) {
      try {
        projects.add(RemixProject.fromJson(jsonDecode(json) as Map<String, dynamic>));
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return projects;
  }

  Future<void> saveRemixProjects(List<RemixProject> projects) =>
      _prefs.setStringList(_remixProjectsKey, projects.map((project) => jsonEncode(project.toJson())).toList());
}
