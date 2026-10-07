import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/shared/widgets/rotating_search_hint.dart';

Future<TextEditingController> _pump(
  WidgetTester tester, {
  bool noAnimations = false,
}) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: noAnimations),
        child: Scaffold(
          body: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hint: RotatingSearchHint(
                semanticLabel: 'Search jobs, companies or locations',
                examples: ['Jobs', 'Companies', 'Locations'],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  testWidgets('"Search for" stays; the example changes in turn', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Search for '), findsOneWidget);
    expect(find.text("'Jobs'"), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(find.text("'Companies'"), findsOneWidget);
    expect(find.text("'Jobs'"), findsNothing);
    expect(find.text('Search for '), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(find.text("'Locations'"), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500)); // back to the first
    await tester.pumpAndSettle();
    expect(find.text("'Jobs'"), findsOneWidget);
  });

  testWidgets('hidden once the user types', (tester) async {
    final controller = await _pump(tester);
    await tester.enterText(find.byType(TextField), 'driver');
    await tester.pumpAndSettle();
    expect(controller.text, 'driver');
    // The text field removes the hint or fades it out while there is text.
    final hint = find.byType(RotatingSearchHint);
    if (hint.evaluate().isNotEmpty) {
      final fades = tester.widgetList<AnimatedOpacity>(
        find.ancestor(of: hint, matching: find.byType(AnimatedOpacity)),
      );
      expect(fades.any((o) => o.opacity == 0), isTrue);
    }
  });

  testWidgets('screen readers hear one fixed label', (tester) async {
    await _pump(tester);
    expect(
      find.bySemanticsLabel('Search jobs, companies or locations'),
      findsWidgets,
    );
  });

  testWidgets('starts rotating when more examples arrive later', (
    tester,
  ) async {
    Widget hint(List<String> examples) => MaterialApp(
      home: Scaffold(
        body: RotatingSearchHint(semanticLabel: 'Search', examples: examples),
      ),
    );
    await tester.pumpWidget(hint(const ['Skills']));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text("'Skills'"), findsOneWidget); // one example: still

    // Categories loaded from the server.
    await tester.pumpWidget(hint(const ['Skills', 'Design']));
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(find.text("'Design'"), findsOneWidget);
  });

  testWidgets('"remove animations" on: the example stays still', (
    tester,
  ) async {
    await _pump(tester, noAnimations: true);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text("'Jobs'"), findsOneWidget);
  });
}
