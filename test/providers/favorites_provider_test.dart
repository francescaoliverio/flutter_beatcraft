import 'package:flutter_beatcraft/providers/favorites_provider.dart';
import 'package:flutter_beatcraft/providers/local_storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'playback_provider_test.dart' show FakeLocalStorage;

void main() {
  late FakeLocalStorage storage;
  late ProviderContainer container;

  setUp(() {
    storage = FakeLocalStorage()..favoriteTrackIds = ['1'];
    container = ProviderContainer.test(overrides: [localStorageProvider.overrideWithValue(storage)]);
  });

  test('starts from the saved likes', () async {
    expect(await container.read(favoritesProvider.future), ['1']);
  });

  test('a new like goes first and is saved', () async {
    await container.read(favoritesProvider.future);

    await container.read(favoritesProvider.notifier).toggle('2');

    expect(container.read(favoritesProvider).value, ['2', '1']);
    expect(storage.favoriteTrackIds, ['2', '1']);
  });

  test('liking again removes the like', () async {
    await container.read(favoritesProvider.future);

    await container.read(favoritesProvider.notifier).toggle('1');

    expect(container.read(favoritesProvider).value, isEmpty);
    expect(storage.favoriteTrackIds, isEmpty);
  });
}
