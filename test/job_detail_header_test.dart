import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_colors.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/provider_retry.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/applications/repositories/application_repository.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/jobs/models/job.dart';
import 'package:kaam_milega/features/jobs/models/job_filter.dart';
import 'package:kaam_milega/features/jobs/models/jobs_response.dart';
import 'package:kaam_milega/features/jobs/presentation/job_detail_screen.dart';
import 'package:kaam_milega/features/jobs/repositories/job_repository.dart';
import 'package:kaam_milega/features/network/providers/network_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _job = Job.fromJson({
  'id': 'j1',
  'title': 'HIRING: LABOUR CONTRACTOR – HELPERS & HOUSEKEEPING STAFF',
  'company': 'Shree Facility Services',
  'city_name': 'Ahmedabad',
  'salary_min': 40000,
  'salary_max': 50000,
  'experience_min': 5,
  'experience_max': 8,
  'job_type': 'Full-time',
  'vacancies': 1,
  'applicant_count': 0,
});

/// Answers locally; no network.
class _Jobs extends JobRepository {
  _Jobs() : super(ApiClient());

  @override
  Future<JobsResponse> getJobs(JobFilter filter) async =>
      const JobsResponse(jobs: [], total: 0, page: 1, limit: 10);

  @override
  Future<Job> getJobById(String id) async => _job;
}

class _Apps extends ApplicationRepository {
  _Apps() : super(ApiClient());

  @override
  Future<bool> hasApplied(String jobId) async => false;
}

class _Guest extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isGuest: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('compact header with real job data only', (tester) async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        retry: appProviderRetry,
        overrides: [
          authProvider.overrideWith(_Guest.new),
          jobRepositoryProvider.overrideWithValue(_Jobs()),
          applicationRepositoryProvider.overrideWithValue(_Apps()),
          // People Like You on the page; not under test here.
          communityUsersProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: JobDetailScreen(jobId: 'j1', initialJob: _job),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Hiring: Labour Contractor – Helpers & Housekeeping Staff'),
      findsOneWidget,
    );
    expect(find.text('Shree Facility Services · Ahmedabad'), findsOneWidget);
    expect(find.textContaining('₹40,000 - ₹50,000'), findsOneWidget);
    expect(find.text('5-8 Yrs'), findsWidgets);
    expect(find.text('1 opening'), findsOneWidget);
    expect(find.text('Apply for Position'), findsOneWidget);
    final apply = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Apply for Position'),
    );
    expect(
      apply.style!.backgroundColor!.resolve(<WidgetState>{}),
      AppColors.accent,
    );

    // Nothing invented: no fixed badges, no made-up applicant count
    expect(find.text('HOT LISTING'), findsNothing);
    expect(find.text('KM VERIFIED'), findsNothing);
    expect(find.text('DIRECT HIRING'), findsNothing);
    expect(find.textContaining('People Interested'), findsNothing);
    expect(find.textContaining(RegExp(r'^\d+\+? applied$')), findsNothing);
    expect(find.textContaining('Day Shift'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
