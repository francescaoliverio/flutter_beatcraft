import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:http/http.dart' as http;

/// Loading a track failed: network error, HTTP status other than 200, engine not available or audio not decodable.
class AudioLoadException implements Exception {
  const AudioLoadException(this.message);

  final String message;

  @override
  String toString() => 'AudioLoadException: $message';
}

/// A newer [AudioEngine.load] started before this one finished: its result is dropped.
class AudioLoadCancelled implements Exception {
  const AudioLoadCancelled();
}

/// Plays one track at a time. Abstract so tests can replace the real engine with a fake.
abstract class AudioEngine {
  /// Downloads [url] and replaces the current track, paused at the start. Returns the track length.
  Future<Duration> load(String url);

  void play();

  void pause();

  void seek(Duration position);

  /// Current position. After the end of the track it equals the track length.
  Duration get position;

  /// True from the end of the track until the next [play] or [seek].
  bool get hasEnded;

  Future<void> dispose();
}

/// [AudioEngine] on flutter_soloud.
/// The track stays in memory and is never written to disk, as the Jamendo terms require:
/// loadUrl would save a temporary copy, so the bytes are downloaded here and passed to loadMem.
class SoLoudAudioEngine implements AudioEngine {
  SoLoudAudioEngine(this._client);

  final http.Client _client;
  final SoLoud _soloud = SoLoud.instance;

  AudioSource? _source;
  SoundHandle? _handle;
  Duration _length = Duration.zero;

  /// Incremented by every [load], to recognize loads overtaken by a newer one.
  int _loadId = 0;

  @override
  Future<Duration> load(String url) async {
    final int loadId = ++_loadId;

    try {
      if (!_soloud.isInitialized) await _soloud.init();
    } on SoLoudException catch (e) {
      throw AudioLoadException(e.toString());
    }

    final http.Response response;
    try {
      response = await _client.get(Uri.parse(url));
    } on http.ClientException catch (e) {
      throw AudioLoadException(e.message);
    }
    if (response.statusCode != 200) throw AudioLoadException('HTTP ${response.statusCode}');
    if (loadId != _loadId) throw const AudioLoadCancelled();

    await _unload();

    final AudioSource source;
    try {
      // LoadMode.disk with loadMem: the compressed bytes stay in memory and are decoded while playing,
      // so a track takes a few MB instead of the tens of MB of fully decoded audio
      source = await _soloud.loadMem(url, response.bodyBytes, mode: LoadMode.disk);
    } on SoLoudException catch (e) {
      throw AudioLoadException(e.toString());
    }
    if (loadId != _loadId) {
      await _soloud.disposeSource(source);
      throw const AudioLoadCancelled();
    }

    _source = source;
    _handle = _soloud.play(source, paused: true);
    _length = _soloud.getLength(source);
    return _length;
  }

  bool get _hasValidHandle {
    final SoundHandle? handle = _handle;
    return handle != null && _soloud.getIsValidVoiceHandle(handle);
  }

  @override
  void play() {
    final AudioSource? source = _source;
    if (source == null) return;
    if (_hasValidHandle) {
      _soloud.setPause(_handle!, false);
    } else {
      // The track ended and its handle is no longer valid: start it again from the beginning
      _handle = _soloud.play(source);
    }
  }

  @override
  void pause() {
    if (_hasValidHandle) _soloud.setPause(_handle!, true);
  }

  @override
  void seek(Duration position) {
    final AudioSource? source = _source;
    if (source == null) return;
    if (!_hasValidHandle) _handle = _soloud.play(source, paused: true);
    _soloud.seek(_handle!, position);
  }

  @override
  Duration get position {
    if (_hasValidHandle) return _soloud.getPosition(_handle!);
    return _source == null ? Duration.zero : _length;
  }

  @override
  bool get hasEnded => _source != null && !_hasValidHandle;

  Future<void> _unload() async {
    final AudioSource? source = _source;
    _source = null;
    _handle = null;
    _length = Duration.zero;
    // disposeSource also stops every handle of the source
    if (source != null) await _soloud.disposeSource(source);
  }

  /// Frees the current track. The engine stays initialized: the remix editor will use it too.
  @override
  Future<void> dispose() => _unload();
}
