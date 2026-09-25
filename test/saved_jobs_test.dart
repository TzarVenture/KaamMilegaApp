import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/jobs/models/job.dart';
import 'package:kaam_milega/features/jobs/models/job_filter.dart';
import 'package:kaam_milega/features/jobs/models/jobs_response.dart';
import 'package:kaam_milega/features/jobs/presentation/saved_jobs_screen.dart';
import 'package:kaam_milega/features/jobs/providers/jobs_provider.dart';
import 'package:kaam_milega/features/jobs/repositories/job_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaam_milega/core/network/provider_retry.dart';

Job _job(String id, String title) => Job.fromJson({
  'id': id,
  'title': title,
  'company': 'Acme Logistics',
  'city_name': 'Pune',
});

/// Jobs API answered locally. The first Jobs page holds [pageJobs];
/// GET /jobs/:id answers from [byId], 404 for "gone", 500 for "broken".
class _FakeJobs extends JobRepository {
  _FakeJobs({this.pageJobs = const []}) : super(ApiClient());
  final List<Job> pageJobs;
  final byId = <String, Job>{'j1': _job('j1', 'Warehouse Helper')};
  final detailCalls = <String>[];

  @override
  Future<JobsResponse> getJobs(JobFilter filter) async =>
      JobsResponse(jobs: pageJobs, total: pageJobs.length, page: 1, limit: 10);

  @override
  Future<Job> getJobById(String id) async {
    detailCalls.add(id);
    if (id == 'gone') throw const AppNotFoundException('Job not found');
    if (id == 'broken') throw const AppServerException();
    return byId[id]!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> savedIds(List<String> ids) async {
    SharedPreferences.setMockInitialValues({'km_saved_job_ids': ids});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  }

  ProviderContainer containerWith(_FakeJobs jobs) {
    // The app's retry policy (as in main.dart), so failures surface as fast
    // as they do in the app.
    final container = ProviderContainer(
      retry: appProviderRetry,
      overrides: [jobRepositoryProvider.overrideWithValue(jobs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads every saved job by ID; a deleted job is "unavailable"', () async {
    await savedIds(['j1', 'gone']);
    final jobs = _FakeJobs(); // the Jobs page does not contain them
    final container = containerWith(jobs);
    final sub = container.listen(savedJobsProvider, (_, _) {});
    addTearDown(sub.close);

    final entries = await container.read(savedJobsProvider.future);
    expect(entries.map((e) => e.id), ['j1', 'gone']);
    expect(entries.first.job?.title, 'Warehouse Helper');
    expect(entries.last.isUnavailable, isTrue);
    expect(jobs.detailCalls.toSet(), {'j1', 'gone'});
  });

  test('a job already on the Jobs page is reused (no extra request)', () async {
    await savedIds(['j1']);
    final jobs = _FakeJobs(pageJobs: [_job('j1', 'Warehouse Helper')]);
    final container = containerWith(jobs);
    final jobsSub = container.listen(jobsProvider, (_, _) {});
    addTearDown(jobsSub.close);
    await Future<void>.delayed(Duration.zero); // first Jobs page loaded

    final sub = container.listen(savedJobsProvider, (_, _) {});
    addTearDown(sub.close);
    final entries = await container.read(savedJobsProvider.future);
    expect(entries.single.job?.title, 'Warehouse Helper');
    expect(jobs.detailCalls, isEmpty);
  });

  test('a server error is an error, not "no saved jobs"', () async {
    await savedIds(['j1', 'broken']);
    final container = containerWith(_FakeJobs());
    final sub = container.listen(savedJobsProvider, (_, _) {});
    addTearDown(sub.close);

    await expectLater(
      container.read(savedJobsProvider.future),
      throwsA(isA<AppServerException>()),
    );
  });

  testWidgets('screen lists saved jobs beyond the current page and lets the '
      'user remove an unavailable one', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await savedIds(['j1', 'gone']);
    final jobs = _FakeJobs();
    await tester.pumpWidget(
      ProviderScope(
        retry: appProviderRetry,
        overrides: [jobRepositoryProvider.overrideWithValue(jobs)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SavedJobsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 jobs saved for later'), findsOneWidget);
    // JobCard shows the title in capitals.
    expect(find.text('WAREHOUSE HELPER'), findsOneWidget);
    expect(find.text('This saved job is no longer available.'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('1 job saved for later'), findsOneWidget);
    expect(find.text('This saved job is no longer available.'), findsNothing);
    expect(LocalStorage.getSavedJobIds(), {'j1'});
  });

  testWidgets('nothing saved: empty state and no requests', (tester) async {
    await savedIds([]);
    final jobs = _FakeJobs();
    await tester.pumpWidget(
      ProviderScope(
        retry: appProviderRetry,
        overrides: [jobRepositoryProvider.overrideWithValue(jobs)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SavedJobsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Saved Jobs Found'), findsOneWidget);
    expect(jobs.detailCalls, isEmpty);
  });
}
