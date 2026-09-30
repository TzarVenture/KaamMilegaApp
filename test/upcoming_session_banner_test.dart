import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/features/experts/models/booking.dart';
import 'package:kaam_milega/features/experts/presentation/widgets/upcoming_session_banner.dart';
import 'package:kaam_milega/features/experts/repositories/expert_repository.dart';

final _now = DateTime(2026, 9, 29, 9, 0);

BookingItem _b(String id, String status, DateTime at, {String title = ''}) =>
    BookingItem(
      id: id,
      mentorshipId: 'm1',
      expertId: 'e1',
      status: status,
      scheduledAt: at,
      mentorshipTitle: title,
      expertName: 'Jitendra Rai',
    );

Future<void> _pump(WidgetTester tester, List<BookingItem> bookings) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: UpcomingSessionBanner(now: _now),
          ),
        ),
      ),
      GoRoute(
        path: '/my-sessions',
        builder: (_, _) => const Scaffold(body: Text('sessions page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [myBookingsProvider.overrideWith((ref) async => bookings)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('next call: soonest confirmed one that has not finished', () {
    final next = UpcomingSessionBanner.nextCall([
      _b('later', 'confirmed', _now.add(const Duration(days: 2))),
      _b('soon', 'confirmed', _now.add(const Duration(hours: 1))),
      _b('pending', 'pending', _now.add(const Duration(minutes: 5))),
      _b('cancelled', 'cancelled', _now.add(const Duration(minutes: 10))),
      _b('past', 'confirmed', _now.subtract(const Duration(hours: 3))),
    ], _now);
    expect(next?.id, 'soon');
  });

  testWidgets('shows the next call and opens My Booked Sessions', (
    tester,
  ) async {
    await _pump(tester, [
      _b(
        'b1',
        'confirmed',
        DateTime(2026, 9, 29, 10, 0),
        title: 'Core Technical & Trade Skills Mastery',
      ),
    ]);

    expect(find.text('UPCOMING CALL'), findsOneWidget);
    expect(find.text('Core Technical & Trade Skills Mastery'), findsOneWidget);
    expect(
      find.textContaining('Jitendra Rai', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Today at 10:00 AM', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('View Session / Join Call'));
    await tester.pumpAndSettle();
    expect(find.text('sessions page'), findsOneWidget);
  });

  testWidgets('no upcoming call: nothing shown', (tester) async {
    await _pump(tester, [_b('c1', 'cancelled', DateTime(2026, 9, 29, 10, 0))]);
    expect(find.text('UPCOMING CALL'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });
}
