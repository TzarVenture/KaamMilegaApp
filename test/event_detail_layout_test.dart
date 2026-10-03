import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/events/models/event.dart';
import 'package:kaam_milega/features/events/models/event_participant.dart';
import 'package:kaam_milega/features/events/presentation/event_detail_screen.dart';
import 'package:kaam_milega/features/events/providers/event_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Guest extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isGuest: true);
}

Map<String, dynamic> _json({
  String location = 'Online',
  String description = 'Hands-on live masterclass on cloud deployments.',
  bool registered = false,
}) => {
  'id': 'e1',
  'title': 'Kubernetes & Cloud Scale Masterclass',
  'organizer': 'Tech Community Admin',
  'description': description,
  'date': '2026-10-25',
  'time': '19:00',
  'location': location,
  'category': 'Masterclass',
  'is_paid': true,
  'price': 499,
  'currency': 'INR',
  'capacity': 30,
  'available_seats': 28,
  'participants': <String>[],
  'is_registered': registered,
};

Future<void> _pump(
  WidgetTester tester,
  EventItem event, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_Guest.new),
        eventDetailProvider.overrideWith((ref, id) async => event),
        eventAttendeesProvider.overrideWith(
          (ref, id) async => const EventAttendees(total: 0, people: []),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: EventDetailScreen(event: event),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  testWidgets('online paid event: tags, pass card, locked room, booking bar', (
    tester,
  ) async {
    await _pump(tester, EventItem.fromJson(_json()));
    expect(tester.takeException(), isNull);
    expect(find.text('Masterclass'), findsOneWidget);
    expect(find.text('Paid · ₹499'), findsOneWidget);
    expect(find.text('Live video session'), findsOneWidget);
    expect(find.text('Kubernetes & Cloud Scale Masterclass'), findsOneWidget);
    expect(find.text('2026-10-25'), findsOneWidget);
    expect(find.text('19:00'), findsOneWidget);
    expect(find.text('28 seats remaining of 30 total'), findsOneWidget);
    expect(find.text('Live session meeting room'), findsOneWidget);
    // Booking stays at the bottom of the screen
    expect(find.text('Buy ticket · ₹499'), findsOneWidget);
    expect(find.text('₹499 per ticket · 28 seats left'), findsOneWidget);
    // No invented claims
    expect(find.textContaining('Verified Expert'), findsNothing);
  });

  testWidgets('fits a 320px phone with large text', (tester) async {
    await _pump(
      tester,
      EventItem.fromJson(_json(description: 'Long text. ' * 80)),
      size: const Size(320, 640),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Read more'), findsOneWidget);
  });

  testWidgets('registered with a real link: Join live session', (tester) async {
    await _pump(
      tester,
      EventItem.fromJson(
        _json(
          location: 'https://meet.google.com/abc-defg-hij',
          registered: true,
        ),
      ),
    );
    expect(find.text('Pass active'), findsOneWidget);
    expect(find.text('Join live session'), findsOneWidget);
    expect(find.text('View ticket'), findsOneWidget);
  });

  testWidgets('registered without a link: no invented meeting link', (
    tester,
  ) async {
    await _pump(tester, EventItem.fromJson(_json(registered: true)));
    expect(find.text('Join live session'), findsNothing);
    expect(
      find.textContaining('has not added a meeting link yet'),
      findsOneWidget,
    );
  });

  testWidgets('in-person event: venue shown, no meeting room', (tester) async {
    await _pump(
      tester,
      EventItem.fromJson(_json(location: 'Pune Convention Centre')),
    );
    expect(find.text('VENUE'), findsOneWidget);
    expect(find.text('Pune Convention Centre'), findsOneWidget);
    expect(find.text('Live session meeting room'), findsNothing);
  });

  testWidgets('no description: no section and no filler text', (tester) async {
    await _pump(tester, EventItem.fromJson(_json(description: '')));
    expect(find.text('About this event'), findsNothing);
  });
}
