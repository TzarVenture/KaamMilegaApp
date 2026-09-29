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
        ),
      ),
    );

    expect(find.text('Find Jobs & Connect Direct'), findsOneWidget);
    expect(find.text('Verified Indian Employment Portal'), findsOneWidget);
    expect(find.text('1,250 Active Listings'), findsOneWidget);
    expect(find.text('Instant Application'), findsOneWidget);
    // No invented company count
    expect(find.textContaining('Verified Companies'), findsNothing);

    await tester.tap(find.text('Saved Jobs (3)'));
    expect(opened, 1);
  });

  testWidgets('no count while loading or filtered', (tester) async {
    await tester.pumpWidget(
      _wrap(JobsHeroCard(openJobs: null, savedCount: 0, onSavedJobs: () {})),
    );
    expect(find.textContaining('Active Listing'), findsNothing);
    expect(find.text('Saved Jobs (0)'), findsOneWidget);
  });
}
