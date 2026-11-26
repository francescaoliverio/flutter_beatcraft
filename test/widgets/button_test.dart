import 'package:flutter_beatcraft/widgets/button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('a button next to a text is its own element for screen readers', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // A list item is one semantics node: without its own node the button would be merged with the text
          body: ListView(
            children: [
              Row(
                children: [
                  const Expanded(child: Text('3 tracks')),
                  Button(label: 'Play', semanticLabel: 'Play all', onPressed: () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Play all'), findsOneWidget);
    expect(find.bySemanticsLabel('3 tracks'), findsOneWidget);
    semantics.dispose();
  });
}
