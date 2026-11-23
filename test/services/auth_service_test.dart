import 'dart:convert';

import 'package:flutter_beatcraft/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Matches an [AuthException] with the given [failure].
Matcher throwsAuthFailure(AuthFailure failure) =>
    throwsA(isA<AuthException>().having((e) => e.failure, 'failure', failure));

void main() {
  const Map<String, Object> successBody = {
    'accessToken': 'access',
    'refreshToken': 'refresh',
    'id': 1,
    'username': 'emilys',
    'email': 'emily.johnson@x.dummyjson.com',
    'firstName': 'Emily',
    'lastName': 'Johnson',
    'gender': 'female',
    'image': 'https://dummyjson.com/icon/emilys/128',
  };

  group('AuthService.login', () {
    test('sends the credentials as JSON and returns the session', () async {
      late http.Request sent;
      final service = AuthService(
        MockClient((request) async {
          sent = request;
          return http.Response(jsonEncode(successBody), 200);
        }),
      );

      final session = await service.login('emilys', 'emilyspass');

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://dummyjson.com/auth/login');
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), {'username': 'emilys', 'password': 'emilyspass'});
      expect(session.accessToken, 'access');
      expect(session.user.username, 'emilys');
    });

    test('400 means wrong credentials', () {
      final service = AuthService(
        MockClient((_) async => http.Response(jsonEncode({'message': 'Invalid credentials'}), 400)),
      );

      expect(service.login('emilys', 'wrong'), throwsAuthFailure(AuthFailure.invalidCredentials));
    });

    test('server error is a generic failure', () {
      final service = AuthService(MockClient((_) async => http.Response('', 500)));

      expect(service.login('emilys', 'emilyspass'), throwsAuthFailure(AuthFailure.other));
    });

    test('network error is a generic failure', () {
      final service = AuthService(MockClient((_) async => throw http.ClientException('offline')));

      expect(service.login('emilys', 'emilyspass'), throwsAuthFailure(AuthFailure.other));
    });

    test('unexpected body is a generic failure', () {
      final service = AuthService(MockClient((_) async => http.Response('not json', 200)));

      expect(service.login('emilys', 'emilyspass'), throwsAuthFailure(AuthFailure.other));
    });
  });

  group('AuthService.fetchUser', () {
    test('returns the user from /users/{id}', () async {
      late Uri sent;
      final service = AuthService(
        MockClient((request) async {
          sent = request.url;
          return http.Response(jsonEncode(successBody), 200);
        }),
      );

      final user = await service.fetchUser(1);

      expect(sent.toString(), 'https://dummyjson.com/users/1');
      expect(user?.username, 'emilys');
    });

    test('404 means the user does not exist', () async {
      final service = AuthService(
        MockClient((_) async => http.Response(jsonEncode({'message': "User with id '99' not found"}), 404)),
      );

      expect(await service.fetchUser(99), isNull);
    });

    test('network error is a generic failure', () {
      final service = AuthService(MockClient((_) async => throw http.ClientException('offline')));

      expect(service.fetchUser(1), throwsAuthFailure(AuthFailure.other));
    });
  });
}
