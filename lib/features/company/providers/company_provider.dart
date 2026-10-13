import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../jobs/models/job.dart';
import '../models/top_company.dart';
import '../repositories/company_repository.dart';

/// Home "Featured Companies Actively Hiring": up to 6 real employers.
final topCompaniesProvider = FutureProvider<List<TopCompany>>((ref) async {
  final companies = await ref
      .watch(companyRepositoryProvider)
      .getTopCompanies(limit: 10);
  return companies.take(6).toList();
});

/// Ids of employers the KaamMilega team has verified (GET /companies/top,
/// `verified: true`; the id is the recruiter's user id, as `recruiter_id` on
/// a job). Job cards show "KM Verified Employer" only for these.
///
/// The jobs API itself has no verified field, so an employer outside this
/// list gets no badge: the badge is never shown without the server saying
/// so. Loaded once per app session (public, works for guests); while it
/// loads or if it fails, no badge is shown.
final verifiedEmployerIdsProvider = FutureProvider<Set<String>>((ref) async {
  final companies = await ref
      .watch(companyRepositoryProvider)
      .getTopCompanies(limit: 50);
  return {
    for (final c in companies)
      if (c.verified) c.id,
  };
});

/// Open jobs of one employer for the company page; loaded fresh each time
/// the page opens.
final companyJobsProvider = FutureProvider.autoDispose
    .family<List<Job>, String>((ref, recruiterId) {
      return ref.watch(companyRepositoryProvider).getOpenJobs(recruiterId);
    });
