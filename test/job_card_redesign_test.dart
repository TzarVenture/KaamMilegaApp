import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/features/company/models/top_company.dart';
import 'package:kaam_milega/features/company/providers/company_provider.dart';
import 'package:kaam_milega/features/company/repositories/company_repository.dart';
import 'package:kaam_milega/features/jobs/models/job.dart';
import 'package:kaam_milega/features/jobs/presentation/widgets/job_card.dart';

class _Companies extends CompanyRepository {
  _Companies() : super(ApiClient());

  int? askedLimit;

  @override
  Future<List<TopCompany>> getTopCompanies({int limit = 10}) async {
    askedLimit = limit;
    return const [
      TopCompany(id: 'r-verified', name: 'Acme', verified: true),
      TopCompany(id: 'r-pending', name: 'Beta'),
    ];
  }
}

Job _job(Map<String, dynamic> extra) => Job.fromJson({
  'id': 'j1',
  'title': 'UI UX DESIGNER',
  'company': 'Kaammi Studio',
  'city_name': 'Pune',
  'location': 'Deep Dead Sea, Near a very long landmark road',
  'salary_min': 25000,
  'salary_max': 35000,
  'job_type': 'Internship',
  'vacancies': 1,
  ...extra,
});

void main() {
  group('Job display helpers', () {
    test('compact salary keeps the whole range short', () {
      expect(_job({}).compactSalary, '₹25K – ₹35K');
      expect(
        _job({'salary_min': 120000, 'salary_max': 150000}).compactSalary,
        '₹1.2L – ₹1.5L',
      );
      expect(
        _job({'salary_min': 12500, 'salary_max': 0}).compactSalary,
        '₹12.5K+',
      );
      expect(
        _job({'salary_min': 0, 'salary_max': 900}).compactSalary,
        'Up to ₹900',
      );
      expect(
        _job({'salary_min': 0, 'salary_max': 0}).compactSalary,
        'Salary disclosed at interview',
      );
      // The long form used elsewhere is unchanged
      expect(_job({}).formattedSalary, '₹25,000 - ₹35,000');
    });

    test('ALL CAPS titles shown in normal case, short words kept', () {
      expect(_job({}).displayTitle, 'UI UX Designer');
      expect(_job({'title': 'DEV ENGINEER'}).displayTitle, 'Dev Engineer');
      expect(
        _job({'title': 'Senior iOS Developer'}).displayTitle,
        'Senior iOS Developer',
      );
    });

    test('posted label', () {
      final now = DateTime.now();
      expect(_job({'created_at': now.toIso8601String()}).postedLabel, 'Today');
      expect(
        _job({
          'created_at': now.subtract(const Duration(days: 3)).toIso8601String(),
        }).postedLabel,
        '3 days ago',
      );
      expect(_job({}).postedLabel, '');
    });
  });

  group('Job card', () {
    Future<void> pump(
      WidgetTester tester,
      Job job, {
      Size screen = const Size(390, 844),
      double textScale = 1,
      bool applied = false,
      bool verified = false,
    }) async {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
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
                  job: job,
                  isApplied: applied,
                  isVerifiedEmployer: verified,
                  onTap: () {},
                  onApply: () {},
                  onChat: () {},
                  onCall: () {},
                  onBookmarkToggle: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows real data only, in a clean layout', (tester) async {
      await pump(tester, _job({}));
      expect(find.text('UI UX Designer'), findsOneWidget);
      expect(find.text('Kaammi Studio · Pune'), findsOneWidget);
      expect(find.textContaining('₹25K – ₹35K'), findsOneWidget);
      expect(find.text('Internship'), findsOneWidget);
      expect(find.text('1 opening'), findsOneWidget);
      expect(find.text('View & Apply'), findsOneWidget);
      // Labels that were not based on data are gone
      expect(find.text('HOT'), findsNothing);
      expect(find.text('KM VERIFIED'), findsNothing);
      expect(find.text('TOP RECOMMENDED MATCH'), findsNothing);
      expect(find.text('HIRING NOW'), findsNothing);
    });

    testWidgets('KM Verified Employer only when the server says so', (
      tester,
    ) async {
      await pump(tester, _job({}));
      expect(find.text('KM Verified Employer'), findsNothing);

      await pump(tester, _job({}), verified: true);
      expect(find.text('KM Verified Employer'), findsOneWidget);
    });

    testWidgets('applied state replaces the Apply button', (tester) async {
      await pump(tester, _job({}), applied: true);
      expect(find.text('Applied'), findsOneWidget);
      expect(find.text('View & Apply'), findsNothing);
    });

    testWidgets('small phone with large text does not overflow', (
      tester,
    ) async {
      await pump(
        tester,
        _job({'title': 'SENIOR WAREHOUSE OPERATIONS AND LOGISTICS MANAGER'}),
        screen: const Size(320, 700),
        textScale: 1.3,
        verified: true,
      );
      expect(tester.takeException(), isNull);
    });
  });

  test('verified employer ids come only from verified companies', () async {
    final companies = _Companies();
    final container = ProviderContainer(
      overrides: [companyRepositoryProvider.overrideWithValue(companies)],
    );
    addTearDown(container.dispose);

    final ids = await container.read(verifiedEmployerIdsProvider.future);
    expect(ids, {'r-verified'});
    expect(companies.askedLimit, 50);
  });
}
