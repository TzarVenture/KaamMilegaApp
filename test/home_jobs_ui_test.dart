import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/features/jobs/models/job.dart';
import 'package:kaam_milega/features/jobs/presentation/widgets/job_card.dart';

/// Batch 6 (Home / Jobs / Details / Applications UI): long titles and small
/// screens must not overflow; taps still work.
void main() {
  final longJob = Job.fromJson({
    'id': 'job_long',
    'title':
        'Senior Warehouse Operations Supervisor and Inventory Control '
        'Executive (Night Shift, Immediate Joining)',
    'company': 'A Very Long Logistics and Supply Chain Company Private Limited',
    'city_name': 'Navi Mumbai',
    'location': 'Turbhe MIDC Industrial Area, Sector 20',
    'salary_min': 18000,
    'salary_max': 32000,
    'job_type': 'Full-time',
    'requirements': ['Two wheeler', 'Driving licence', 'Smartphone'],
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    required Size screen,
    double textScale = 1.0,
    VoidCallback? onTap,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: screen,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: JobCard(
                job: longJob,
                onTap: onTap ?? () {},
                onApply: () {},
                onChat: () {},
                onCall: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Note: widget tests draw text with a test font that is much wider than
  // the real app font, so 360 px here is stricter than a real 360 px phone.
  testWidgets('long job title and company on a small phone do not overflow', (
    tester,
  ) async {
    await pumpCard(tester, screen: const Size(360, 740));
    expect(tester.takeException(), isNull);
  });

  testWidgets('job card still opens on tap (press effect is visual)', (
    tester,
  ) async {
    var taps = 0;
    await pumpCard(tester, screen: const Size(390, 844), onTap: () => taps++);
    // Tap the card body (top-left area), not one of its buttons.
    await tester.tapAt(
      tester.getTopLeft(find.byType(JobCard)) + const Offset(40, 30),
    );
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
