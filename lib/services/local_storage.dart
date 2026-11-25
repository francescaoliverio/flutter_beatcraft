import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/remix_project.dart';

/// Small values kept on the device between launches: ids and remix projects (track id and clip times).
/// Never tokens, audio or track data.
/// Last track, favorites and remixes are kept per user, so several users can share the device.
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferencesAsync _prefs;

  static const String _lastTrackIdKey = 'last_track_id';
  static const String _userIdKey = 'logged_user_id';
  static const String _favoriteTrackIdsKey = 'favorite_track_ids';
  static const String _remixProjectsKey = 'remix_projects';

  /// Key of [userId]'s own copy of a value, e.g. favorite_track_ids_5.
  static String _ofUser(String key, int userId) => '${key}_$userId';

  Future<String?> readLastTrackId(int userId) => _prefs.getString(_ofUser(_lastTrackIdKey, userId));

  Future<void> saveLastTrackId(int userId, String id) => _prefs.setString(_ofUser(_lastTrackIdKey, userId), id);

  Future<int?> readUserId() => _prefs.getInt(_userIdKey);

  Future<void> saveUserId(int id) => _prefs.setInt(_userIdKey, id);

  Future<void> clearUserId() => _prefs.remove(_userIdKey);

  /// Liked tracks, newest first.
  Future<List<String>> readFavoriteTrackIds(int userId) async =>
      await _prefs.getStringList(_ofUser(_favoriteTrackIdsKey, userId)) ?? [];

  Future<void> saveFavoriteTrackIds(int userId, List<String> ids) =>
      _prefs.setStringList(_ofUser(_favoriteTrackIdsKey, userId), ids);

  /// Saved remixes, one JSON string each. A project that can't be read is skipped.
  Future<List<RemixProject>> readRemixProjects(int userId) async {
    final List<String> saved = await _prefs.getStringList(_ofUser(_remixProjectsKey, userId)) ?? [];
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

  Future<void> saveRemixProjects(int userId, List<RemixProject> projects) => _prefs.setStringList(
    _ofUser(_remixProjectsKey, userId),
    projects.map((project) => jsonEncode(project.toJson())).toList(),
  );
}
