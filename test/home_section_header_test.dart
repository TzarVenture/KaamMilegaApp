import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/features/home/presentation/widgets/home_section_header.dart';

Future<void> _pump(WidgetTester tester, Widget header, {double scale = 1}) =>
    tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 640),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(body: header),
        ),
      ),
    );

void main() {
  testWidgets('title, description and a real See All button', (tester) async {
    var tapped = false;
    await _pump(
      tester,
      HomeSectionHeader(
        title: 'Top Picks',
        subtitle: 'More openings you may like',
        onSeeAll: () => tapped = true,
      ),
    );
    expect(find.text('Top Picks'), findsOneWidget);
    expect(find.text('More openings you may like'), findsOneWidget);
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(40),
    );
    await tester.tap(find.text('See All'));
    expect(tapped, isTrue);
  });

  testWidgets('no See All without an action; long titles fit', (tester) async {
    await _pump(
      tester,
      const HomeSectionHeader(
        title: 'Featured Companies Actively Hiring on KaamMilega today',
      ),
      scale: 1.4,
    );
    expect(find.text('See All'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
