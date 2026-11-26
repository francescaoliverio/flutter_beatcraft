import 'dart:convert';

import 'package:flutter_beatcraft/models/playlist.dart';
import 'package:flutter_beatcraft/services/jamendo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../models/jamendo_models_test.dart' show trackJson;

/// Body shaped like a Jamendo answer. Errors also come with HTTP 200.
String body({int code = 0, List<Object> results = const []}) => jsonEncode({
  'headers': {'status': code == 0 ? 'success' : 'failed', 'code': code, 'error_message': '', 'warnings': ''},
  'results': results,
});

Matcher throwsJamendoFailure(JamendoFailure failure) =>
    throwsA(isA<JamendoException>().having((e) => e.failure, 'failure', failure));

void main() {
  group('JamendoService', () {
    test('ready to remix asks for popular tracks without NoDerivatives and drops the ones without download', () async {
      late Uri sent;
      final service = JamendoService(
        MockClient((request) async {
          sent = request.url;
          return http.Response(
            body(
              results: [
                {...trackJson(), 'id': '1'},
                {...trackJson(downloadAllowed: false), 'id': '2'},
                {...trackJson(), 'id': '3'},
              ],
            ),
            200,
          );
        }),
        'test-id',
      );

      final tracks = await service.readyToRemix(limit: 7);

      expect(sent.queryParameters['order'], 'popularity_week');
      expect(sent.queryParameters['ccnd'], 'false');
      expect(tracks.map((t) => t.id), ['1', '3']);
    });

    test('sends the client id and the query, and parses the tracks', () async {
      late Uri sent;
      final service = JamendoService(
        MockClient((request) async {
          sent = request.url;
          return http.Response(body(results: [trackJson()]), 200);
        }),
        'test-id',
      );

      final tracks = await service.newReleases(limit: 7);

      expect(sent.host, 'api.jamendo.com');
      expect(sent.path, '/v3.0/tracks/');
      expect(sent.queryParameters['client_id'], 'test-id');
      expect(sent.queryParameters['order'], 'releasedate_desc');
      expect(sent.queryParameters['limit'], '7');
      expect(tracks.single.id, '2353774');
    });

    test('without client id fails before calling the network', () async {
      var calls = 0;
      final service = JamendoService(
        MockClient((_) async {
          calls++;
          return http.Response(body(), 200);
        }),
        '',
      );

      await expectLater(service.newReleases(limit: 7), throwsJamendoFailure(JamendoFailure.missingClientId));
      expect(calls, 0);
    });

    test('an error code with HTTP 200 is a failure', () {
      final service = JamendoService(MockClient((_) async => http.Response(body(code: 6), 200)), 'test-id');

      expect(service.newReleases(limit: 7), throwsJamendoFailure(JamendoFailure.other));
    });

    test('code 5 means the client id is not valid', () {
      final service = JamendoService(MockClient((_) async => http.Response(body(code: 5), 200)), 'wrong-id');

      expect(service.newReleases(limit: 7), throwsJamendoFailure(JamendoFailure.invalidClientId));
    });

    test('empty results are retried, and the first non-empty answer is used', () async {
      var calls = 0;
      final service = JamendoService(
        MockClient((_) async {
          calls++;
          return http.Response(body(results: calls < 3 ? [] : [trackJson()]), 200);
        }),
        'test-id',
      );

      final tracks = await service.newReleases(limit: 7);

      expect(calls, 3);
      expect(tracks, hasLength(1));
    });

    test('empty results on every attempt end in an empty failure', () async {
      var calls = 0;
      final service = JamendoService(
        MockClient((_) async {
          calls++;
          return http.Response(body(), 200);
        }),
        'test-id',
      );

      await expectLater(service.newReleases(limit: 7), throwsJamendoFailure(JamendoFailure.empty));
      expect(calls, JamendoService.maxAttempts);
    });

    test('network error is a generic failure', () {
      final service = JamendoService(MockClient((_) async => throw http.ClientException('offline')), 'test-id');

      expect(service.newReleases(limit: 7), throwsJamendoFailure(JamendoFailure.other));
    });

    test('a result with a missing field is a generic failure', () {
      final service = JamendoService(
        MockClient(
          (_) async => http.Response(
            body(
              results: [
                {'id': '1'},
              ],
            ),
            200,
          ),
        ),
        'test-id',
      );

      expect(service.newReleases(limit: 7), throwsJamendoFailure(JamendoFailure.other));
    });

    test('playlists carry the requested mood', () async {
      final service = JamendoService(
        MockClient(
          (_) async => http.Response(
            body(
              results: [
                {'id': '13', 'name': 'chillout', 'user_name': 'someone@example.com'},
              ],
            ),
            200,
          ),
        ),
        'test-id',
      );

      final playlists = await service.searchPlaylists('chill', CoverMood.calm, limit: 2);

      expect(playlists.single.mood, CoverMood.calm);
      expect(playlists.single.name, 'chillout');
    });

    test('tracksByIds asks for all ids at once and keeps their order', () async {
      late Uri sent;
      final service = JamendoService(
        MockClient((request) async {
          sent = request.url;
          // Jamendo doesn't document the order: answer in a different one
          return http.Response(
            body(
              results: [
                {...trackJson(), 'id': '2'},
                {...trackJson(), 'id': '1'},
              ],
            ),
            200,
          );
        }),
        'test-id',
      );

      final tracks = await service.tracksByIds(['1', '3', '2']);

      expect(sent.queryParameters['id'], '1 3 2');
      expect(sent.queryParameters['limit'], '3');
      // 3 is not returned by Jamendo and is skipped
      expect(tracks.map((t) => t.id), ['1', '2']);
    });

    test('tracksByIds without ids makes no request', () async {
      var calls = 0;
      final service = JamendoService(
        MockClient((_) async {
          calls++;
          return http.Response(body(), 200);
        }),
        'test-id',
      );

      expect(await service.tracksByIds([]), isEmpty);
      expect(calls, 0);
    });

    test('trackById returns null when the track is not found', () async {
      final service = JamendoService(MockClient((_) async => http.Response(body(), 200)), 'test-id');

      expect(await service.trackById('999'), isNull);
    });

    test('playlist tracks come in the order of their position, with all their fields', () async {
      final List<Uri> sent = [];
      final service = JamendoService(
        MockClient((request) async {
          sent.add(request.url);
          if (request.url.path.contains('playlists')) {
            return http.Response(
              body(
                results: [
                  {
                    'id': '11696',
                    'name': 'Instrumental',
                    'tracks': [
                      {'id': '3', 'position': '2'},
                      {'id': '1', 'position': '10'},
                      {'id': '2', 'position': '1'},
                    ],
                  },
                ],
              ),
              200,
            );
          }
          return http.Response(
            body(
              results: [
                for (final String id in ['1', '2', '3']) {...trackJson(), 'id': id},
              ],
            ),
            200,
          );
        }),
        'test-id',
      );

      final tracks = await service.playlistTracks('11696');

      expect(tracks.map((t) => t.id), ['2', '3', '1']);
      expect(sent.first.queryParameters['track_type'], 'single albumtrack');
      expect(sent.last.queryParameters['id'], '2 3 1');
      expect(tracks.first.shareUrl, isNotNull);
    });

    test('an empty playlist has no tracks instead of an error', () async {
      final service = JamendoService(MockClient((_) async => http.Response(body(), 200)), 'test-id');

      expect(await service.playlistTracks('100268'), isEmpty);
    });

    test('artist tracks are the most popular ones of that artist', () async {
      late Uri sent;
      final service = JamendoService(
        MockClient((request) async {
          sent = request.url;
          return http.Response(body(results: [trackJson()]), 200);
        }),
        'test-id',
      );

      final tracks = await service.artistTracks('603605', limit: 50);

      expect(tracks, hasLength(1));
      expect(
        (sent.queryParameters['artist_id'], sent.queryParameters['order'], sent.queryParameters['limit']),
        ('603605', 'popularity_total', '50'),
      );
    });
  });
}
