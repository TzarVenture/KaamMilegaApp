import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/job.dart';
import '../models/job_filter.dart';
import '../models/jobs_response.dart';

/// Repository for handling Job APIs from km-backend
class JobRepository {
  final ApiClient _client;

  JobRepository(this._client);

  /// Fetch jobs with filtering and pagination
  Future<JobsResponse> getJobs(JobFilter filter) async {
    final response = await _client.get(
      ApiConstants.jobs,
      queryParameters: filter.toQueryParams(),
    );

    if (response.data is Map<String, dynamic>) {
      return JobsResponse.fromJson(response.data as Map<String, dynamic>);
    }

    // If array is returned
    if (response.data is List) {
      final list = (response.data as List)
          .map((e) => Job.fromJson(e as Map<String, dynamic>))
          .toList();
      return JobsResponse(jobs: list, total: list.length, page: 1, limit: 10);
    }

    return const JobsResponse(jobs: [], total: 0, page: 1, limit: 10);
  }

  /// Toggle a job bookmark on the server (POST /user/bookmark/:jobId).
  /// Returns the full updated list of bookmarked job IDs.
  Future<Set<String>> toggleBookmark(String jobId) async {
    final response = await _client.post('${ApiConstants.userBookmark}$jobId');
    return _parseBookmarkIds(response.data);
  }

  /// Fetch bookmarked job IDs for the signed-in user.
  /// Read from GET /user/profile (field `bookmarked_jobs`), the same way the
  /// website does. GET /user/bookmarks currently returns HTTP 500 because the
  /// backend matches it as GET /user/:id (route order issue on the server).
  Future<Set<String>> getBookmarkedJobIds() async {
    final response = await _client.get(ApiConstants.userProfile);
    return _parseBookmarkIds(response.data);
  }

  Set<String> _parseBookmarkIds(dynamic data) {
    if (data is Map<String, dynamic> && data['bookmarked_jobs'] is List) {
      return (data['bookmarked_jobs'] as List).map((e) => e.toString()).toSet();
    }
    return <String>{};
  }

  /// Fetch single job by ID
  Future<Job> getJobById(String id) async {
    final response = await _client.get('${ApiConstants.jobDetail}$id');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['job'] is Map<String, dynamic>) {
        return Job.fromJson(data['job'] as Map<String, dynamic>);
      }
      return Job.fromJson(data);
    }
    throw Exception('Invalid job detail response from server');
  }
}

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepository(ref.watch(apiClientProvider));
});
