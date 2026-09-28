import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/events/models/event.dart';
import 'package:kaam_milega/features/events/presentation/events_screen.dart';
import 'package:kaam_milega/features/events/presentation/widgets/event_pricing_filter.dart';
import 'package:kaam_milega/features/events/providers/event_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

EventItem _event(
  String id,
  String title, {
  bool isPaid = false,
  num price = 0,
}) => EventItem.fromJson({
  'id': id,
  'title': title,
  'date': '2026-11-10',
  'time': '18:30',
  'location': 'Online',
  'is_paid': isPaid,
  'price': price,
});

final _free = _event('e1', 'Resume Clinic');
final _paid = _event('e2', 'LLM Bootcamp', isPaid: true, price: 799);
// Marked paid but no price: checkout treats it as free, so does the filter
final _paidNoPrice = _event('e3', 'Open Webinar', isPaid: true);

class _Events extends EventsNotifier {
  @override
  Future<List<EventItem>> build() async => [_free, _paid, _paidNoPrice];
}

class _Guest extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isGuest: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('filter rule matches ticket checkout', () {
    expect(EventPricingFilter.all.matches(_paid), isTrue);
    expect(EventPricingFilter.free.matches(_free), isTrue);
    expect(EventPricingFilter.free.matches(_paid), isFalse);
    expect(EventPricingFilter.free.matches(_paidNoPrice), isTrue);
    expect(EventPricingFilter.paid.matches(_paid), isTrue);
    expect(EventPricingFilter.paid.matches(_paidNoPrice), isFalse);
  });

  testWidgets('chips report the tapped filter', (tester) async {
    EventPricingFilter? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventPricingChips(
            selected: EventPricingFilter.all,
            onChanged: (f) => picked = f,
          ),
        ),
      ),
    );
    expect(find.text('All Events'), findsOneWidget);
    expect(find.text('Free Events'), findsOneWidget);
    expect(find.text('Paid Masterclasses'), findsOneWidget);

    await tester.tap(find.text('Paid Masterclasses'));
    expect(picked, EventPricingFilter.paid);
  });

  testWidgets('Events tab shows only the chosen pricing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_Guest.new),
          eventsProvider.overrideWith(_Events.new),
        ],
        child: const MaterialApp(home: EventsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resume Clinic'), findsOneWidget);
    expect(find.text('LLM Bootcamp'), findsOneWidget);

    await tester.tap(find.text('Paid Masterclasses'));
    await tester.pumpAndSettle();
    expect(find.text('LLM Bootcamp'), findsOneWidget);
    expect(find.text('Resume Clinic'), findsNothing);
    expect(find.text('Open Webinar'), findsNothing);

    await tester.tap(find.text('Free Events'));
    await tester.pumpAndSettle();
    expect(find.text('Resume Clinic'), findsOneWidget);
    expect(find.text('Open Webinar'), findsOneWidget);
    expect(find.text('LLM Bootcamp'), findsNothing);
  });
}
