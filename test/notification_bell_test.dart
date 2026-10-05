import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/features/notifications/providers/notification_provider.dart';
import 'package:kaam_milega/shared/widgets/notification_bell_button.dart';

Future<void> _pump(WidgetTester tester, int unread) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            Scaffold(appBar: AppBar(actions: const [NotificationBellButton()])),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const Scaffold(body: Text('Notifications page')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [unreadNotificationsCountProvider.overrideWithValue(unread)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a real button: tooltip, 40px tap area, opens Notifications', (
    tester,
  ) async {
    await _pump(tester, 3);
    expect(find.byTooltip('Notifications, 3 unread'), findsOneWidget);
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(40));
    expect(size.height, greaterThanOrEqualTo(40));

    await tester.tap(find.byType(NotificationBellButton));
    await tester.pumpAndSettle();
    expect(find.text('Notifications page'), findsOneWidget);
  });

  testWidgets('red dot only while there are unread notifications', (
    tester,
  ) async {
    await _pump(tester, 0);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isFalse);

    await _pump(tester, 2);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
  });
}
