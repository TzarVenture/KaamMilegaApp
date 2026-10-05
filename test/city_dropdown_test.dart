import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/features/cities/models/city.dart';
import 'package:kaam_milega/features/cities/presentation/city_dropdown.dart';
import 'package:kaam_milega/features/cities/repositories/city_repository.dart';

const _cities = [
  City(id: '1', name: 'Ahmedabad'),
  City(id: '2', name: 'Bangalore'),
  City(id: '3', name: 'Bhiwandi'),
  City(id: '4', name: 'Bhopal'),
  City(id: '5', name: 'Chennai'),
];

Future<List<String>> _pump(
  WidgetTester tester, {
  String current = 'All',
  Size size = const Size(360, 740),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final picked = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [citiesFutureProvider.overrideWith((ref) async => _cities)],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topLeft,
              child: CityPickerButton(
                currentCity: current,
                onSelected: picked.add,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return picked;
}

void main() {
  testWidgets('opens under the button with All Cities first', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(CityPickerButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Search city...'), findsOneWidget);
    expect(find.text('All Cities'), findsOneWidget);
    expect(find.text('Bhopal'), findsOneWidget);
    // The list starts just below the button
    final button = tester.getRect(find.byType(CityPickerButton));
    final search = tester.getRect(find.byType(TextField));
    expect(search.top, greaterThan(button.bottom));
  });

  testWidgets('search narrows the list; choosing a city closes it', (
    tester,
  ) async {
    final picked = await _pump(tester);
    await tester.tap(find.byType(CityPickerButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bh');
    await tester.pumpAndSettle();
    expect(find.text('Bhiwandi'), findsOneWidget);
    expect(find.text('Bhopal'), findsOneWidget);
    expect(find.text('Chennai'), findsNothing);
    expect(find.text('All Cities'), findsNothing);

    await tester.tap(find.text('Bhopal'));
    await tester.pumpAndSettle();
    expect(picked, ['Bhopal']);
    expect(find.text('Search city...'), findsNothing);
  });

  testWidgets('All Cities sends the "All" filter; tap outside closes', (
    tester,
  ) async {
    final picked = await _pump(tester, current: 'Chennai');
    expect(find.textContaining('Chennai'), findsOneWidget); // on the button
    await tester.tap(find.byType(CityPickerButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Cities'));
    await tester.pumpAndSettle();
    expect(picked, ['All']);

    await tester.tap(find.byType(CityPickerButton));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(350, 720)); // outside the list
    await tester.pumpAndSettle();
    expect(find.text('Search city...'), findsNothing);
    expect(picked, ['All']);
  });

  testWidgets('fits a 320px phone', (tester) async {
    await _pump(tester, size: const Size(320, 568));
    await tester.tap(find.byType(CityPickerButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final panel = tester.getRect(find.byType(TextField));
    expect(panel.left, greaterThanOrEqualTo(16));
    expect(panel.right, lessThanOrEqualTo(320 - 16));
  });
}
