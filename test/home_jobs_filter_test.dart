import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/provider_retry.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/jobs/models/job.dart';
import 'package:kaam_milega/features/jobs/models/job_filter.dart';
import 'package:kaam_milega/features/jobs/models/jobs_response.dart';
import 'package:kaam_milega/features/jobs/providers/jobs_provider.dart';
import 'package:kaam_milega/features/jobs/repositories/job_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Jobs API answered locally: a search returns nothing (like a category
/// with no matching jobs); records every filter it was asked for.
class _SearchJobs extends JobRepository {
  _SearchJobs() : super(ApiClient());
  final requests = <JobFilter>[];

  @override
  Future<JobsResponse> getJobs(JobFilter filter) async {
    requests.add(filter);
    final jobs = filter.searchQuery.isEmpty
        ? [
            Job.fromJson({
              'id': 'j-${filter.city}',
              'title': 'Warehouse Helper',
              'company': 'Acme Logistics',
            }),
          ]
        : <Job>[];
    return JobsResponse(jobs: jobs, total: jobs.length, page: 1, limit: 10);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  test('Home jobs ignore the Jobs tab search (Popular Categories)', () async {
    final repo = _SearchJobs();
    final container = ProviderContainer(
      retry: appProviderRetry,
      overrides: [jobRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(homeJobsProvider, (_, _) {});
    addTearDown(sub.close);

    expect(await container.read(homeJobsProvider.future), hasLength(1));

    // Home > Popular Categories > "Delivery": the Jobs tab is searched...
    container.read(jobsProvider.notifier).setSearchQuery('Delivery');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(jobsProvider).filter.searchQuery, 'Delivery');

    // ...but Home keeps its list and never sends that search.
    expect(container.read(homeJobsProvider).value, hasLength(1));
    final homeRequests = repo.requests.where((f) => f.searchQuery.isEmpty);
    expect(homeRequests, isNotEmpty);
    expect(
      repo.requests.where((f) => f.searchQuery == 'Delivery'),
      everyElement(isA<JobFilter>().having((f) => f.page, 'page', 1)),
    );
  });

  test('Home jobs follow the selected city', () async {
    final repo = _SearchJobs();
    final container = ProviderContainer(
      retry: appProviderRetry,
      overrides: [jobRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(homeJobsProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(homeJobsProvider.future);

    container.read(jobsProvider.notifier).setCity('Pune');
    final jobs = await container.read(homeJobsProvider.future);
    expect(jobs.single.id, 'j-Pune');
    expect(
      repo.requests.last,
      isA<JobFilter>()
          .having((f) => f.city, 'city', 'Pune')
          .having((f) => f.searchQuery, 'searchQuery', ''),
    );
  });
}
