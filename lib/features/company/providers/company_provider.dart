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

/// Open jobs of one employer for the company page; loaded fresh each time
/// the page opens.
final companyJobsProvider = FutureProvider.autoDispose
    .family<List<Job>, String>((ref, recruiterId) {
      return ref.watch(companyRepositoryProvider).getOpenJobs(recruiterId);
    });
