import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/features/jobs/models/job_filter.dart';
import 'package:kaam_milega/features/jobs/presentation/job_links.dart';
import 'package:kaam_milega/features/jobs/presentation/widgets/filter_modal.dart';

void main() {
  Future<void> pumpFilters(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => FilterModalSheet.show(
                  context,
                  initialFilter: const JobFilter(),
                  onApply: (_) {},
                ),
                child: const Text('Open filters'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/instant-work',
          builder: (_, _) => const Scaffold(body: Text('Instant page')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open filters'));
    await tester.pumpAndSettle();
  }

  testWidgets('Instant Milega card is on top and opens Instant Milega', (
    tester,
  ) async {
    await pumpFilters(tester);
    expect(find.text('Instant Milega'), findsOneWidget);
    final banner = tester.getTopLeft(find.text('Instant Milega')).dy;
    final salary = tester.getTopLeft(find.text('Monthly salary')).dy;
    expect(banner, lessThan(salary));

    await tester.tap(find.text('Instant Milega'));
    await tester.pumpAndSettle();
    expect(find.text('Instant page'), findsOneWidget);
  });

  testWidgets('Gender tiles: blue male, pink female; tap selects', (
    tester,
  ) async {
    await pumpFilters(tester);
    // The list builds lazily: scroll until the Gender section exists.
    await tester.scrollUntilVisible(
      find.text('Female'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.male_rounded), findsOneWidget);
    expect(find.byIcon(Icons.female_rounded), findsOneWidget);

    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    expect(find.text('Apply Filters (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chips select and Clear all resets', (tester) async {
    await pumpFilters(tester);
    await tester.tap(find.text('Fresher'));
    await tester.pumpAndSettle();
    expect(find.text('Apply Filters (1)'), findsOneWidget);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(find.text('Apply Filters'), findsOneWidget);
  });

  testWidgets('Call without a shared number offers Chat, dials nothing', (
    tester,
  ) async {
    var chatted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showRecruiterCallSheet(context, onChat: () => chatted = true),
              child: const Text('Call'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();
    expect(find.text('Phone number not shared'), findsOneWidget);

    await tester.tap(find.text('Chat with recruiter'));
    await tester.pumpAndSettle();
    expect(chatted, isTrue);
    expect(find.text('Phone number not shared'), findsNothing);
  });
}
