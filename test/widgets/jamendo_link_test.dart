import 'package:flutter_beatcraft/models/track.dart';
import 'package:flutter_beatcraft/providers/link_launcher_provider.dart';
import 'package:flutter_beatcraft/services/link_launcher.dart';
import 'package:flutter_beatcraft/widgets/jamendo_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Records the opened links instead of opening a browser.
class FakeLinkLauncher implements LinkLauncher {
  FakeLinkLauncher({this.succeeds = true});

  final bool succeeds;
  final List<String> opened = [];

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return succeeds;
  }
}

const Track _track = Track(
  id: '7',
  name: 'Night Drive',
  artistName: 'Megis',
  image: 'https://example.com/7.jpg',
  audio: 'https://example.com/7.mp3',
  audiodownloadAllowed: true,
  licenseCcurl: 'http://creativecommons.org/licenses/by/3.0/',
  shareUrl: 'https://www.jamendo.com/track/7',
);

void main() {
  Future<void> showCredit(WidgetTester tester, FakeLinkLauncher launcher) => tester.pumpWidget(
    ProviderScope(
      overrides: [linkLauncherProvider.overrideWithValue(launcher)],
      child: const MaterialApp(
        home: Scaffold(body: TrackCredit(track: _track)),
      ),
    ),
  );

  testWidgets('the credit is one link to the track page on Jamendo', (tester) async {
    final FakeLinkLauncher launcher = FakeLinkLauncher();
    await showCredit(tester, launcher);

    expect(find.bySemanticsLabel('From Night Drive by Megis via Jamendo'), findsOneWidget);
    await tester.tap(find.byType(TrackCredit));
    await tester.pump();

    expect(launcher.opened, ['https://www.jamendo.com/track/7']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a page that does not open shows a message', (tester) async {
    await showCredit(tester, FakeLinkLauncher(succeeds: false));

    await tester.tap(find.byType(TrackCredit));
    await tester.pump();

    expect(find.text("Couldn't open the track on Jamendo."), findsOneWidget);
  });

  testWidgets('the tap area is at least 44 px tall', (tester) async {
    await showCredit(tester, FakeLinkLauncher());

    expect(tester.getSize(find.byType(TrackCredit)).height, greaterThanOrEqualTo(44));
  });
}
