import 'dart:convert';

import 'package:flutter_beatcraft/providers/auth_provider.dart';
import 'package:flutter_beatcraft/providers/favorites_provider.dart';
import 'package:flutter_beatcraft/providers/local_storage_provider.dart';
import 'package:flutter_beatcraft/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'playback_provider_test.dart' show FakeLocalStorage;

const Map<String, Object> emily = {
  'id': 1,
  'username': 'emilys',
  'firstName': 'Emily',
  'lastName': 'Johnson',
  'image': 'https://dummyjson.com/icon/emilys/128',
};

/// Answers /users/1 with Emily, other ids with 404, and the login with Emily plus a token.
http.Client fakeDummyJson() => MockClient((request) async {
  if (request.url.path == '/auth/login') {
    return http.Response(jsonEncode({...emily, 'accessToken': 'access', 'refreshToken': 'refresh'}), 200);
  }
  if (request.url.path == '/users/1') return http.Response(jsonEncode(emily), 200);
  return http.Response(jsonEncode({'message': 'not found'}), 404);
});

ProviderContainer containerWith(FakeLocalStorage storage) => ProviderContainer.test(
  overrides: [
    localStorageProvider.overrideWithValue(storage),
    authServiceProvider.overrideWithValue(AuthService(fakeDummyJson())),
  ],
);

void main() {
  group('authProvider', () {
    test('without a saved id starts logged out', () async {
      final container = containerWith(FakeLocalStorage());

      expect(await container.read(authProvider.future), isNull);
    });

    test('with a saved id restores the user, without a token', () async {
      final container = containerWith(FakeLocalStorage()..userId = 1);

      final session = await container.read(authProvider.future);

      expect(session?.user.username, 'emilys');
      expect(session?.accessToken, isNull);
    });

    test('with the id of a user that no longer exists starts logged out and forgets the id', () async {
      final storage = FakeLocalStorage()..userId = 42;
      final container = containerWith(storage);

      expect(await container.read(authProvider.future), isNull);
      expect(storage.userId, isNull);
    });

    test('login saves the user id, logout removes it', () async {
      final storage = FakeLocalStorage();
      final container = containerWith(storage);
      await container.read(authProvider.future);

      await container.read(authProvider.notifier).login('emilys', 'emilyspass');
      expect(storage.userId, 1);
      expect(container.read(authProvider).value?.accessToken, 'access');

      await container.read(authProvider.notifier).logout();
      expect(storage.userId, isNull);
      expect(container.read(authProvider).value, isNull);
    });

    test('logout hides the user data and keeps it for the next login', () async {
      final storage = FakeLocalStorage()
        ..userId = 1
        ..favoriteTrackIds[1] = ['2353774'];
      final container = containerWith(storage);
      await container.read(authProvider.future);
      expect(container.read(loggedUserIdProvider), 1);
      expect(await container.read(favoritesProvider.future), ['2353774']);

      await container.read(authProvider.notifier).logout();

      expect(container.read(loggedUserIdProvider), isNull);
      expect(await container.read(favoritesProvider.future), isEmpty);
      expect(storage.favoriteTrackIds[1], ['2353774']);

      await container.read(authProvider.notifier).login('emilys', 'emilyspass');

      expect(await container.read(favoritesProvider.future), ['2353774']);
    });

    test('each user sees only their own favorites', () async {
      final storage = FakeLocalStorage()
        ..userId = 1
        ..favoriteTrackIds[1] = ['1']
        ..favoriteTrackIds[2] = ['2'];
      final container = containerWith(storage);
      await container.read(authProvider.future);

      expect(await container.read(favoritesProvider.future), ['1']);
    });
  });
}
