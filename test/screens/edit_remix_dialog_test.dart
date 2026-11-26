import 'dart:typed_data';

import 'package:flutter_beatcraft/models/timeline_clip.dart';
import 'package:flutter_beatcraft/providers/auth_provider.dart';
import 'package:flutter_beatcraft/providers/editor_provider.dart';
import 'package:flutter_beatcraft/providers/local_storage_provider.dart';
import 'package:flutter_beatcraft/providers/playback_provider.dart';
import 'package:flutter_beatcraft/screens/create_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/playback_provider_test.dart' show FakeAudioEngine, FakeLocalStorage, track;

/// A remix already loaded, without audio: the dialog only needs its name and cover.
class _LoadedEditor extends EditorNotifier {
  @override
  Future<EditorState?> build() async => EditorState(
    track: track('1'),
    trackLength: const Duration(minutes: 3),
    waveform: Float32List(0),
    clips: const [
      TimelineClip(id: 0, sourceStart: Duration.zero, sourceEnd: Duration(minutes: 3), timelineStart: Duration.zero),
    ],
    name: 'Night remix',
    cover: 3,
  );
}

void main() {
  late ProviderContainer container;

  Future<void> openDialog(WidgetTester tester) async {
    // Tall enough for the whole Create screen
    tester.view.physicalSize = const Size(1200, 2600);
    addTearDown(tester.view.resetPhysicalSize);
    container = ProviderContainer.test(
      overrides: [
        editorProvider.overrideWith(_LoadedEditor.new),
        audioEngineProvider.overrideWithValue(FakeAudioEngine()),
        editorEngineProvider.overrideWithValue(FakeAudioEngine()),
        localStorageProvider.overrideWithValue(FakeLocalStorage()),
        loggedUserIdProvider.overrideWithValue(1),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CreateScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit name and cover'));
    await tester.pumpAndSettle();
  }

  EditorState editor() => container.read(editorProvider).value!;

  testWidgets('without changes the X closes the dialog at once', (tester) async {
    await openDialog(tester);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Edit remix'), findsNothing);
    expect(find.text('Unsaved changes'), findsNothing);
  });

  testWidgets('with changes the X asks first, and Discard keeps the old name and cover', (tester) async {
    await openDialog(tester);
    await tester.enterText(find.byType(TextField), 'Day remix');
    await tester.tap(find.bySemanticsLabel('Cover 5'));
    await tester.pump();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Edit remix'), findsNothing);
    expect((editor().name, editor().cover), ('Night remix', 3));
  });

  testWidgets('a tap outside with changes asks too, and Apply applies them', (tester) async {
    await openDialog(tester);
    await tester.enterText(find.byType(TextField), 'Day remix');
    await tester.tap(find.bySemanticsLabel('Cover 5'));
    await tester.pump();

    // The barrier around the dialog
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);

    await tester.tap(find.text('Apply').last);
    await tester.pumpAndSettle();

    expect(find.text('Edit remix'), findsNothing);
    expect((editor().name, editor().cover), ('Day remix', 5));
  });

  testWidgets('Apply with an empty name shows the error and keeps the dialog open', (tester) async {
    await openDialog(tester);
    await tester.enterText(find.byType(TextField), '  ');

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name.'), findsOneWidget);
    expect(find.text('Edit remix'), findsOneWidget);
  });
}
