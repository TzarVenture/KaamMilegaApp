import 'job.dart';

/// Paginated Jobs Response model matching km-backend GetJobs output
class JobsResponse {
  final List<Job> jobs;
  final int total;
  final int page;
  final int limit;

  const JobsResponse({
    required this.jobs,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory JobsResponse.fromJson(Map<String, dynamic> json) {
    final jobsRaw = json['jobs'] as List<dynamic>? ?? [];
    final jobsList = jobsRaw
        .map((e) => Job.fromJson(e as Map<String, dynamic>))
        .toList();

    return JobsResponse(
      jobs: jobsList,
      total: (json['total'] as num?)?.toInt() ?? jobsList.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 10,
    );
  }

  int get totalPages => (total / limit).ceil();
  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
}
