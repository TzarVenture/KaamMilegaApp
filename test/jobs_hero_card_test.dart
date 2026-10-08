import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/features/jobs/presentation/widgets/jobs_hero_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('shows the real open-job count and saved jobs', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _wrap(
        JobsHeroCard(
          openJobs: 1250,
          savedCount: 3,
          onSavedJobs: () => opened++,
          search: const TextField(key: Key('search')),
        ),
      ),
    );

    expect(find.text('Find your next job'), findsOneWidget);
    expect(find.text('1,250 open jobs · Apply directly'), findsOneWidget);
    expect(find.byKey(const Key('search')), findsOneWidget);
    // No invented company count
    expect(find.textContaining('Verified Companies'), findsNothing);

    await tester.tap(find.text('Saved 3'));
    expect(opened, 1);
    expect(find.bySemanticsLabel('Saved jobs: 3'), findsOneWidget);
  });

  testWidgets('no count while loading or filtered', (tester) async {
    await tester.pumpWidget(
      _wrap(JobsHeroCard(openJobs: null, savedCount: 0, onSavedJobs: () {})),
    );
    expect(find.textContaining('open job'), findsNothing);
    expect(
      find.text('Apply directly and chat with recruiters.'),
      findsOneWidget,
    );
    expect(find.text('Saved 0'), findsOneWidget);
  });
}
