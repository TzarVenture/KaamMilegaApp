import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/features/home/presentation/widgets/job_categories_section.dart';

void main() {
  test('every category photo is in the app and listed in pubspec', () {
    for (final c in popularJobCategories) {
      expect(File(c.image).existsSync(), isTrue, reason: c.image);
      expect(c.query.trim(), isNotEmpty);
    }
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('assets/images/categories/'),
    );
  });

  testWidgets('photo tiles: titles only, tap reports the category', (
    tester,
  ) async {
    JobCategory? picked;
    var viewAll = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobCategoriesSection(
            onSelected: (c) => picked = c,
            onViewAll: () => viewAll = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bike Courier'), findsOneWidget);
    // No invented opening counts
    expect(find.textContaining('Openings'), findsNothing);

    await tester.tap(find.text('Bike Courier'));
    expect(picked?.query, 'Delivery');

    await tester.tap(find.text('View All'));
    expect(viewAll, isTrue);
  });
}
