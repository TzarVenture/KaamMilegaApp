import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/peer_to_peer/presentation/widgets/people_suggestion_grid.dart';

void main() {
  testWidgets('phone width: two even columns, no overflow, taps routed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400); // 360 x 800
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final opened = <String>[];
    final messaged = <String>[];
    const users = [
      UserProfile(
        id: 'a',
        mobile: '',
        name: 'Harshad Shelke With A Very Long Family Name',
        headline: 'Electrician and home wiring specialist, 8 years',
        city: 'Pune',
      ),
      UserProfile(id: 'b', mobile: '', name: 'Anwar'), // nothing else
      UserProfile(
        id: 'c',
        mobile: '',
        name: 'Test',
        skills: ['Plumbing', 'Painting'],
        city: 'Mumbai',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionUserIdProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PeopleSuggestionGrid(
                users: users,
                onOpen: (u) => opened.add(u.id),
                onMessage: (u) => messaged.add(u.id),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Two per row, same height in a row.
    final cards = find.byType(PeopleSuggestionCard);
    expect(cards, findsNWidgets(3));
    final first = tester.getRect(cards.at(0));
    final second = tester.getRect(cards.at(1));
    expect(first.top, second.top);
    expect(first.height, second.height);
    expect(tester.getRect(cards.at(2)).top, greaterThan(first.bottom));

    // Skills stand in for a missing headline.
    expect(find.text('Plumbing · Painting'), findsOneWidget);

    await tester.tap(find.text('Anwar'));
    await tester.tap(find.byTooltip('Message Test'));
    expect(opened, ['b']);
    expect(messaged, ['c']);
  });
}
