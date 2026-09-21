import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/features/experts/presentation/apply_expert_screen.dart';
import 'package:kaam_milega/features/profile/presentation/widgets/profile_drawer.dart';
import 'package:kaam_milega/features/jobs/models/job.dart';
import 'package:kaam_milega/features/jobs/models/job_filter.dart';
import 'package:kaam_milega/features/jobs/models/jobs_response.dart';
import 'package:kaam_milega/features/jobs/presentation/saved_jobs_screen.dart';

void main() {
  group('Job Model Tests', () {
    test(
      'Job.fromJson correctly maps fields and computes formatted values',
      () {
        final json = {
          'id': 'job_123',
          'title': 'Delivery Driver',
          'company': 'Zomato',
          'city_name': 'Mumbai',
          'location': 'Andheri',
          'salary_min': 20000,
          'salary_max': 30000,
          'job_type': 'Full-time',
          'experience_min': 1,
          'experience_max': 3,
          'requirements': ['Bike', 'License'],
          'we_offer': ['Fuel Allowance'],
          'vacancies': 10,
          'applicant_count': 45,
        };

        final job = Job.fromJson(json);

        expect(job.id, 'job_123');
        expect(job.title, 'Delivery Driver');
        expect(job.company, 'Zomato');
        expect(job.cityName, 'Mumbai');
        expect(job.formattedSalary, '₹20,000 - ₹30,000');
        expect(job.formattedExperience, '1-3 Yrs');
        expect(job.formattedLocation, 'Andheri, Mumbai');
        expect(job.requirements.length, 2);
      },
    );

    test(
      'JobFilter.toQueryParams generates expected backend API query params',
      () {
        const filter = JobFilter(
          searchQuery: 'driver',
          city: 'Mumbai',
          jobTypes: ['Full-time', 'Part-time'],
          salaryRange: '20000',
          experience: '4',
          genders: ['Male'],
          qualification: ['10th Pass'],
          page: 2,
          limit: 10,
        );

        final params = filter.toQueryParams();

        expect(params['search'], 'driver');
        expect(params['city_ids'], 'Mumbai');
        expect(params['job_types'], 'Full-time,Part-time');
        expect(params['salary_min'], 20000);
        expect(params['experience_max'], 4);
        expect(params['genders'], 'Male');
        expect(params['education'], '10th Pass');
        expect(params['page'], 2);
        expect(params['limit'], 10);
        expect(filter.activeFilterCount, 6);
      },
    );

    test('JobsResponse.fromJson parses list and pagination data', () {
      final json = {
        'total': 25,
        'page': 1,
        'limit': 10,
        'jobs': [
          {
            'id': 'j1',
            'title': 'Security Guard',
            'company': 'G4S',
            'city_name': 'Pune',
          },
          {
            'id': 'j2',
            'title': 'Sales Executive',
            'company': 'Airtel',
            'city_name': 'Pune',
          },
        ],
      };

      final res = JobsResponse.fromJson(json);

      expect(res.total, 25);
      expect(res.page, 1);
      expect(res.limit, 10);
      expect(res.totalPages, 3);
      expect(res.hasNextPage, true);
      expect(res.hasPreviousPage, false);
      expect(res.jobs.length, 2);
    });
  });

  group('ApplyExpertScreen Widget Tests', () {
    testWidgets('ApplyExpertScreen renders all form fields and headers', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ApplyExpertScreen())),
      );

      expect(find.text('Apply to be an Expert'), findsOneWidget);
      expect(
        find.text('Share your knowledge, mentor others, and sell courses.'),
        findsOneWidget,
      );
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Bio'), findsOneWidget);
      expect(find.text('Hourly Mentorship Rate (₹)'), findsOneWidget);
      expect(find.text('Documents (Provide URLs for now)'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Identity Proof'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });
  });

  group('ProfileDrawer Widget Tests', () {
    testWidgets('ProfileDrawer renders all unified Home drawer items', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(endDrawer: ProfileDrawer(), body: SizedBox()),
          ),
        ),
      );

      // Open drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openEndDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Network'), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Jobs'), findsOneWidget);
      expect(find.text('Mentors'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Resources'), findsOneWidget);
      expect(find.text('Digital Wallet & Ledger'), findsOneWidget);
      expect(find.text('Setting & Privacy'), findsOneWidget);
      expect(find.text('Applied Jobs Status'), findsOneWidget);
      expect(find.text('Interviews'), findsOneWidget);
      expect(find.text('Apply to be an Expert'), findsOneWidget);
    });
  });

  group('SavedJobsScreen Widget Tests', () {
    testWidgets('SavedJobsScreen renders header and empty state correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SavedJobsScreen())),
      );

      await tester.pumpAndSettle();

      expect(find.text('Back to All Jobs'), findsOneWidget);
      expect(find.text('Saved Jobs'), findsOneWidget);
      expect(find.text('0 jobs saved for later'), findsOneWidget);
      expect(find.text('No Saved Jobs Found'), findsOneWidget);
      expect(find.text('Browse Jobs'), findsOneWidget);
    });
  });

  group('Logo Navigation Tests', () {
    testWidgets(
      'Tapping logo in ProfileDrawer invokes onNavigateTab to Home (0)',
      (tester) async {
        int navigatedTab = -1;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                endDrawer: ProfileDrawer(
                  onNavigateTab: (index) {
                    navigatedTab = index;
                  },
                ),
                body: const SizedBox(),
              ),
            ),
          ),
        );

        final scaffoldState = tester.state<ScaffoldState>(
          find.byType(Scaffold),
        );
        scaffoldState.openEndDrawer();
        await tester.pumpAndSettle();

        final logoFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/logo.png',
        );
        expect(logoFinder, findsOneWidget);

        final logoTextFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/logo_text.png',
        );
        expect(logoTextFinder, findsOneWidget);

        await tester.tap(logoFinder);
        await tester.pumpAndSettle();

        expect(navigatedTab, 0);
      },
    );
  });
}
