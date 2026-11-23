import 'package:shared_preferences/shared_preferences.dart';

/// Small values kept on the device between launches. Never audio or track data, only ids.
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferencesAsync _prefs;

  static const String _lastTrackIdKey = 'last_track_id';

  Future<String?> readLastTrackId() => _prefs.getString(_lastTrackIdKey);

  Future<void> saveLastTrackId(String id) => _prefs.setString(_lastTrackIdKey, id);
}
