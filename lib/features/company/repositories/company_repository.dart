import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/response_list.dart';
import '../../jobs/models/job.dart';
import '../models/top_company.dart';

/// Public employer data (no login needed).
class CompanyRepository {
  final ApiClient _client;

  CompanyRepository(this._client);

  /// Employers hiring on KaamMilega (GET /companies/top?limit=, response
  /// `{data: [...]}`). Entries without an id or name are skipped.
  Future<List<TopCompany>> getTopCompanies({int limit = 10}) async {
    final response = await _client.get(
      ApiConstants.companiesTop,
      queryParameters: {'limit': limit},
    );
    return readListResponse(response.data)
        .map(TopCompany.fromJson)
        .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
        .toList();
  }

  /// All jobs posted by one employer, newest first
  /// (GET /jobs?recruiter_id=, a plain list). Closed and on-hold jobs are
  /// left out: only jobs people can apply to are shown.
  Future<List<Job>> getOpenJobs(String recruiterId) async {
    final response = await _client.get(
      ApiConstants.jobs,
      queryParameters: {'recruiter_id': recruiterId},
    );
    return readListResponse(
      response.data,
      keys: const ['jobs', 'data'],
    ).map(Job.fromJson).where((j) => isOpen(j.status)).toList();
  }

  /// Employers set Open / Closed / On Hold; older jobs may have no status.
  static bool isOpen(String status) {
    final s = status.trim().toLowerCase();
    return s.isEmpty || s == 'open' || s == 'active';
  }
}

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository(ref.watch(apiClientProvider));
});
