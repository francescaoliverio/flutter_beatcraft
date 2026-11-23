import 'package:flutter_beatcraft/models/artist.dart';
import 'package:flutter_beatcraft/models/playlist.dart';
import 'package:flutter_beatcraft/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shape of a real /tracks result (2026-11-23), with fields the app doesn't read left out.
Map<String, dynamic> trackJson({
  bool downloadAllowed = true,
  String license = 'http://creativecommons.org/licenses/by/3.0/',
}) => {
  'id': '2353774',
  'name': 'Calmness Angel Meditation',
  'duration': 343,
  'artist_id': '603605',
  'artist_name': 'Megis',
  'license_ccurl': license,
  'image': 'https://usercontent.jamendo.com?type=album&id=651054&width=300&trackid=2353774',
  'audio': 'https://prod-1.storage.jamendo.com/?trackid=2353774&format=mp31',
  'audiodownload_allowed': downloadAllowed,
};

void main() {
  group('Track', () {
    test('reads the fields', () {
      final track = Track.fromJson(trackJson());

      expect(track.id, '2353774');
      expect(track.name, 'Calmness Angel Meditation');
      expect(track.artistName, 'Megis');
      expect(track.image, startsWith('https://usercontent.jamendo.com'));
      expect(track.audio, startsWith('https://prod-1.storage.jamendo.com'));
    });

    test('can be remixed with downloads allowed and a license without -nd', () {
      expect(Track.fromJson(trackJson()).canRemix, isTrue);
    });

    test('cannot be remixed with a NoDerivatives license', () {
      final track = Track.fromJson(trackJson(license: 'http://creativecommons.org/licenses/by-nc-nd/3.0/'));
      expect(track.canRemix, isFalse);
    });

    test('cannot be remixed without a license', () {
      expect(Track.fromJson(trackJson(license: '')).canRemix, isFalse);
    });

    test('cannot be remixed when downloads are not allowed', () {
      expect(Track.fromJson(trackJson(downloadAllowed: false)).canRemix, isFalse);
    });

    test('fallback cover is one of the 18 remix covers', () {
      // 2353774 % 18 = 4, so cover 05
      expect(Track.fromJson(trackJson()).fallbackCoverAsset, 'assets/images/remixes/remix_05.webp');
    });
  });

  group('Artist', () {
    test('reads the fields', () {
      final artist = Artist.fromJson({
        'id': '606900',
        'name': 'Los Intokables Del Reggaeton - The BackFlash',
        'website': '',
        'joindate': '2026-09-19',
        'image': 'https://usercontent.jamendo.com?type=artist&id=606900&width=300',
      });

      expect(artist.id, '606900');
      expect(artist.name, 'Los Intokables Del Reggaeton - The BackFlash');
      expect(artist.image, startsWith('https://usercontent.jamendo.com'));
    });
  });

  group('Playlist', () {
    test('cover follows the mood and the id', () {
      // 13 % 6 = 1: primary, second image
      final playlist = Playlist.fromJson({'id': '13', 'name': 'chillout'}, CoverMood.calm);
      expect(playlist.coverAsset, 'assets/images/playlists/primary_calm_02.webp');

      // 16 % 6 = 4: tertiary, first image
      final other = Playlist.fromJson({'id': '16', 'name': 'party'}, CoverMood.punchy);
      expect(other.coverAsset, 'assets/images/playlists/tertiary_punchy_01.webp');
    });
  });
}
