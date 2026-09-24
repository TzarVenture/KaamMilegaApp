import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../jobs/models/job.dart';
import '../../jobs/models/job_filter.dart';
import '../../jobs/repositories/job_repository.dart';

/// Jobs shown in Profile > "Jobs Based On Your Profile".
class ProfileJobs {
  final List<Job> jobs;

  /// City from the user's profile whose jobs are listed first, or null when
  /// none of the jobs are from that city.
  final String? city;

  const ProfileJobs({required this.jobs, this.city});
}

/// How many job cards the profile section shows at most.
const int _maxProfileJobs = 10;

/// Loads real jobs from GET /jobs (existing JobRepository) for the profile
/// section. Jobs in the city saved on the user's profile come first
/// (km-backend matches city names); the rest of the list is filled with the
/// latest jobs from all cities, without duplicates. Separate from the Jobs
/// tab list, so the Jobs tab filters are not affected.
final profileJobsProvider = FutureProvider.autoDispose
    .family<ProfileJobs, String>((ref, city) async {
      final repository = ref.watch(jobRepositoryProvider);
      final cityName = city.trim();

      var cityJobs = <Job>[];
      if (cityName.isNotEmpty && cityName.toLowerCase() != 'all') {
        final inCity = await repository.getJobs(
          JobFilter(city: cityName, limit: _maxProfileJobs),
        );
        cityJobs = inCity.jobs;
      }

      final jobs = [...cityJobs];
      if (jobs.length < _maxProfileJobs) {
        final latest = await repository.getJobs(
          const JobFilter(limit: _maxProfileJobs),
        );
        final seen = jobs.map((j) => j.id).toSet();
        for (final job in latest.jobs) {
          if (jobs.length >= _maxProfileJobs) break;
          if (seen.add(job.id)) jobs.add(job);
        }
      }

      return ProfileJobs(
        jobs: jobs,
        city: cityJobs.isNotEmpty ? cityName : null,
      );
    });
