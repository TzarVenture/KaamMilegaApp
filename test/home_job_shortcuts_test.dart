import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/features/home/presentation/widgets/job_shortcuts_sections.dart';

JobShortcut _find(List<JobShortcut> list, String label) =>
    list.singleWhere((s) => s.label == label);

void main() {
  group('Shortcut filters use the values employers post with', () {
    test('qualification tiles filter by education', () {
      Map<String, dynamic> q(String label) =>
          _find(qualificationShortcuts, label).filterFor('All').toQueryParams();

      expect(q('10th Pass')['education'], '10th Pass');
      expect(q('12th Pass')['education'], '12th Pass');
      expect(q('Diploma / ITI')['education'], 'Diploma');
      expect(q('Graduate')['education'], 'Graduation');
      expect(q('Post Graduate')['education'], 'Post Graduation');
    });

    test('job type cards filter by type, experience or gender', () {
      Map<String, dynamic> t(String label) =>
          _find(jobTypeShortcuts, label).filterFor('All').toQueryParams();

      expect(t('Full Time')['job_types'], 'Full-time');
      expect(t('Part Time')['job_types'], 'Part-time');
      expect(t('Fresher Jobs')['experience_max'], 0);
      expect(t('Jobs for Women')['genders'], 'Female');
    });

    test('only one filter is applied, and the chosen city is kept', () {
      final filter = _find(qualificationShortcuts, '12th Pass').filterFor('c1');
      expect(filter.activeFilterCount, 1);
      expect(filter.city, 'c1');
      expect(filter.searchQuery, isEmpty);
      final params = filter.toQueryParams();
      expect(params['city_ids'], 'c1');
      expect(params.containsKey('job_types'), isFalse);
      expect(params.containsKey('genders'), isFalse);
    });

    test('no "Work From Home" or "Below 10th" (no backend filter)', () {
      final labels = [
        ...qualificationShortcuts,
        ...jobTypeShortcuts,
      ].map((s) => s.label);
      expect(labels, isNot(contains('Work From Home')));
      expect(labels, isNot(contains('Below 10th')));
    });
  });

  group('Home sections', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );
    }

    testWidgets('qualification tile reports its shortcut', (tester) async {
      JobShortcut? picked;
      await pump(
        tester,
        QualificationShortcutsSection(onSelected: (s) => picked = s),
      );
      expect(find.text('Search Jobs by Qualification'), findsOneWidget);
      // Labels only: no invented opening counts
      expect(find.textContaining('Openings'), findsNothing);

      await tester.tap(find.text('12th Pass'));
      expect(picked?.qualification, '12th Pass');
    });

    testWidgets('job type card reports its shortcut', (tester) async {
      JobShortcut? picked;
      await pump(
        tester,
        JobTypeShortcutsSection(onSelected: (s) => picked = s),
      );
      expect(find.text('What Type of Job Do You Want?'), findsOneWidget);
      expect(find.text('Full Time'), findsOneWidget);
      expect(find.text('Jobs for Women'), findsOneWidget);

      await tester.tap(find.text('Fresher Jobs'));
      expect(picked?.experience, '0');
    });
  });
}
