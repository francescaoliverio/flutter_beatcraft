import 'package:shared_preferences/shared_preferences.dart';

/// Small values kept on the device between launches. Only ids: never tokens, audio or track data.
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferencesAsync _prefs;

  static const String _lastTrackIdKey = 'last_track_id';
  static const String _userIdKey = 'logged_user_id';

  Future<String?> readLastTrackId() => _prefs.getString(_lastTrackIdKey);

  Future<void> saveLastTrackId(String id) => _prefs.setString(_lastTrackIdKey, id);

  Future<int?> readUserId() => _prefs.getInt(_userIdKey);

  Future<void> saveUserId(int id) => _prefs.setInt(_userIdKey, id);

  Future<void> clearUserId() => _prefs.remove(_userIdKey);
}
