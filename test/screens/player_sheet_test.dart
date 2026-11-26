import 'package:flutter_beatcraft/providers/auth_provider.dart';
import 'package:flutter_beatcraft/providers/local_storage_provider.dart';
import 'package:flutter_beatcraft/providers/playback_provider.dart';
import 'package:flutter_beatcraft/screens/player_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/playback_provider_test.dart' show FakeAudioEngine, FakeLocalStorage;

void main() {
  /// An app with a button that opens the player, logged out so no track is restored.
  Future<void> showApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioEngineProvider.overrideWithValue(FakeAudioEngine()),
          localStorageProvider.overrideWithValue(FakeLocalStorage()),
          loggedUserIdProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          // Opened from inside a SafeArea, like the Home and Profile screens, which removes the top padding there
          home: Scaffold(
            body: SafeArea(
              child: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(onPressed: () => showPlayer(context), child: const Text('Open')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the player opens over the whole screen', (tester) async {
    await showApp(tester);

    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(tester.getSize(find.byType(PlayerScreen)), tester.view.physicalSize / tester.view.devicePixelRatio);
  });

  testWidgets('the close arrow stays below the status bar', (tester) async {
    // A status bar 47 logical px tall
    tester.view.padding = FakeViewPadding(top: 47 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await showApp(tester);

    expect(tester.getTopLeft(find.byTooltip('Close')).dy, greaterThanOrEqualTo(47));
  });

  testWidgets('a swipe down closes the player', (tester) async {
    await showApp(tester);

    await tester.fling(find.byType(PlayerScreen), const Offset(0, 400), 1500);
    await tester.pumpAndSettle();

    expect(find.byType(PlayerScreen), findsNothing);
  });

  testWidgets('the arrow closes the player', (tester) async {
    await showApp(tester);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerScreen), findsNothing);
  });
}
