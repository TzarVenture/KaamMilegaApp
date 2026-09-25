import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/features/applications/models/application.dart';
import 'package:kaam_milega/features/applications/presentation/application_detail_screen.dart';
import 'package:kaam_milega/features/applications/presentation/my_applications_screen.dart';
import 'package:kaam_milega/features/applications/repositories/application_repository.dart';
import 'package:kaam_milega/features/company/presentation/company_screen.dart';

/// Batch 3: no invented ratings, activity or companies are shown.
void main() {
  final application = ApplicationItem(
    id: 'app1',
    jobId: 'job1',
    recruiterId: 'rec1',
    candidateId: 'cand1',
    status: 'Applied',
    coverLetter: '',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    jobTitle: 'Warehouse Associate',
    companyName: 'A Very Long Logistics And Supply Chain Company Name Pvt Ltd',
    cityName: 'Pune',
  );

  Widget app(Widget screen) => ProviderScope(
    overrides: [
      myApplicationsProvider.overrideWith((ref) async => [application]),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: screen),
  );

  Future<void> useSmallPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  void expectNoInventedText() {
    expect(find.textContaining('4.4K'), findsNothing);
    expect(find.text('4.2'), findsNothing);
    expect(find.textContaining('Reviews'), findsNothing);
    expect(find.textContaining('last active'), findsNothing);
  }

  testWidgets('My Applications card shows real company/city, no fake rating '
      'or recruiter activity (small phone, long name)', (tester) async {
    await useSmallPhone(tester);
    await tester.pumpWidget(app(const MyApplicationsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Warehouse Associate'), findsWidgets);
    expect(
      find.text(
        'A Very Long Logistics And Supply Chain Company Name Pvt Ltd • Pune',
      ),
      findsOneWidget,
    );
    expectNoInventedText();
    expect(tester.takeException(), isNull); // no RenderFlex overflow
  });

  testWidgets('Application detail header shows no fake rating', (tester) async {
    await useSmallPhone(tester);
    await tester.pumpWidget(
      app(const ApplicationDetailScreen(applicationId: 'app1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Warehouse Associate'), findsWidgets);
    expectNoInventedText();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Company page shows Coming Soon, not invented company data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const CompanyScreen(companyId: 'any-id'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coming Soon'), findsOneWidget);
    expect(find.text('Company profiles are coming soon.'), findsOneWidget);
    expect(find.textContaining('Reliance'), findsNothing);
    expect(find.text('Follow'), findsNothing);
  });
}
